# Socket server for mt5 EA H_22082024.
import socket
import pandas as pd
import numpy as np
import MetaTrader5 as mt5
import pytz
from datetime import datetime
import json

STD_MULTIPLIER = 1

def data_from_mt5(symbol, date_param):
    # set time zone to UTC
    timezone = pytz.timezone("Etc/UTC")
    # create 'datetime' objects in UTC time zone to avoid the implementation of a local time zone offset
    utc_from = datetime.strptime(date_param, '%Y.%m.%d %H:%M:%S')
    utc_to = datetime.strptime(date_param, '%Y.%m.%d %H:%M:%S')

    # request M1 data
    ohlcv = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M1, utc_from, utc_to)
    daily_ohlcv = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_D1, utc_from, utc_to)

    df = pd.DataFrame(ohlcv)
    df['time']=pd.to_datetime(df['time'], unit='s')

    # adaptamos el dataframe D1 para luego hacer los analisis de las sesiones
    daily_df = pd.DataFrame(daily_ohlcv)
    daily_df['time']=pd.to_datetime(daily_df['time'], unit='s')

    df = df.set_index('time')
    del df['real_volume']
    del df['spread']

    daily_df = daily_df.set_index('time')
    del daily_df['real_volume']
    del daily_df['spread']

    return df, daily_df

def create_market_profile(data, getPOC=True):
    profile = data.groupby('close')['tick_volume'].sum().reset_index()
    total_volume = profile['tick_volume'].sum()
    profile['volume_cumsum'] = profile['tick_volume'].cumsum()

    value_area_cutoff = total_volume * 0.70
    value_area_df = profile[profile['volume_cumsum'] <= value_area_cutoff]
    POC = 0
    if getPOC:
        POC = profile.loc[profile['tick_volume'].idxmax(), 'close']
    else:
        POC = profile.loc[profile['tick_volume'].idxmin(), 'close']

    return profile, value_area_df, POC

def get_no_fair_range_zone(df, threshold):
    # Crear una máscara booleana para identificar dónde 'tick_volume' es inferior al umbral
    df.sort_values(by=['close'])
    mask = df['tick_volume'] < threshold

    # Encontrar los índices donde empieza y termina cada zona
    rangos = []
    inicio = None
    rsize = 0
    rango_max = []

    for i in range(len(df)):
        if mask[i]:
            if inicio is None:  # Se inicia una nueva zona
                inicio = i
        else:
            if inicio is not None:  # Se cierra la zona actual
                rangos.append([inicio, i - 1])
                inicio = None

    # Si la última zona no se cierra explícitamente en el bucle
    if inicio is not None:
        rangos.append([inicio, len(df) - 1])
                 
    for rango in rangos:
        if rsize <= (rango[1] - rango[0]):  
              rsize = rango[1] - rango[0]
              rango_max = rango

    if len(rangos) < 1:
        return False
    return [df.loc[rango_max[0], 'close'], df.loc[rango_max[1], 'close']]

def get_max_vol_zone(df, threshold):
    # Crear una máscara booleana para identificar dónde 'tick_volume' es inferior al umbral
    df.sort_values(by=['close'])
    mask = df['tick_volume'] > threshold

    # Encontrar los índices donde empieza y termina cada zona
    rangos = []
    inicio = None
    rsize = 0
    rango_max = []

    for i in range(len(df)):
        if mask[i]:
            if inicio is None:  # Se inicia una nueva zona
                inicio = i
        else:
            if inicio is not None:  # Se cierra la zona actual
                rangos.append([inicio, i - 1])
                inicio = None

    # Si la última zona no se cierra explícitamente en el bucle
    if inicio is not None:
        rangos.append([inicio, len(df) - 1])
                 
    for rango in rangos:
        if rsize <= (rango[1] - rango[0]):  
              rsize = rango[1] - rango[0]
              rango_max = rango

    if len(rangos) < 1:
        return False
    return [df.loc[rango_max[0], 'close'], df.loc[rango_max[1], 'close']]

def get_no_fair_zone_calculate(df):

    profile, value_area_df, MIN = create_market_profile(df, False)
    mean = profile['tick_volume'].mean()
    stddev = profile['tick_volume'].std()
    threshold = mean + stddev * STD_MULTIPLIER

    no_fair_value_zone = get_no_fair_range_zone(profile, threshold)

    if no_fair_value_zone == False:
        output = {
            "time": df.index,
            "min_zone_high": np.nan,
            "min_zone_low": np.nan,
            "MIN": np.nan,
        }
        return output
    else:
        output = {
            "time": df.index,
            "min_zone_high": no_fair_value_zone[1],
            "min_zone_low": no_fair_value_zone[0],
            "MIN": MIN,
        }
        return output

def get_max_vol_zone_calculate(df):
    
    profile, value_area_df, POC = create_market_profile(df)
    mean = profile['tick_volume'].mean()
    stddev = profile['tick_volume'].std()
    threshold = mean + stddev * STD_MULTIPLIER

    max_value_zone = get_max_vol_zone(profile, threshold)

    if max_value_zone == False:
        output = {
            "time": df.index,
            "max_zone_high": np.nan,
            "max_zone_low": np.nan,
            "POC": np.nan,
        }
        return output
    else:
        output = {
            "time": df.index,
            "max_zone_high": max_value_zone[1],
            "max_zone_low": max_value_zone[0],
            "POC": POC,
        }
        return output
        
def serve_data(socket_data):
    req = socket_data.split('$')
    symbol = req[0]
    date_param = req[1]
    # Returns POC of the given date.
    df, daily_df = data_from_mt5(symbol, date_param)
    profile, value_area_df, POC = create_market_profile(df)
    return POC

class socketserver:
    def __init__(self, address = '', port = 9090):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.address = address
        self.port = port
        self.sock.bind((self.address, self.port))
        self.cummdata = ''
        
    def recvmsg(self):
        self.sock.listen(1)
        self.conn, self.addr = self.sock.accept()
        print('connected to', self.addr)
        self.cummdata = ''

        while True:
            data = self.conn.recv(10000)
            self.cummdata+=data.decode("utf-8")
            if not data:
                break    
            self.conn.send(bytes(serve_data(self.cummdata), "utf-8"))
            return self.cummdata
            
    def __del__(self):
        self.sock.close()

# Start the program
serv = socketserver('127.0.0.1', 9090)
# connect to MetaTrader 5
if not mt5.initialize():
    print("initialize() failed")
    mt5.shutdown()

while True:  
   msg = serv.recvmsg()

mt5.shutdown()