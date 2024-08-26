import pandas as pd
import numpy as np
import MetaTrader5 as mt5
import pytz
from datetime import datetime
import matplotlib.pyplot as plt
import json

# Variables config
ticker = 'GC_V'
# create 'datetime' objects in UTC time to avoid the implementation of a local time zone offset
# set time zone to UTC
timezone = pytz.timezone("Etc/UTC")
utc_from = datetime(2024, 6, 10, tzinfo=timezone)
utc_to = datetime(2024, 6, 11, tzinfo=timezone)

# FUNCTIONS
def create_market_profile(data):
    profile = data.groupby('close')['tick_volume'].sum().reset_index()
    total_volume = profile['tick_volume'].sum()
    profile['volume_cumsum'] = profile['tick_volume'].cumsum()

    value_area_cutoff = total_volume * 0.70
    value_area_df = profile[profile['volume_cumsum'] <= value_area_cutoff]
    POC = profile.loc[profile['tick_volume'].idxmax(), 'close']

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

def get_zone_by_day(df):
    out = []

    for index1, day in df.groupby(df.index.date):

        profile, value_area_df, POC = create_market_profile(day)
        mean = profile['tick_volume'].mean()
        stddev = profile['tick_volume'].std()
        threshold = mean + stddev * 0.5

        no_fair_value_zone = get_no_fair_range_zone(profile, threshold)
        
        output = {
            "date": index1.strftime('%Y-%m-%d'),
            "zone": no_fair_value_zone,
        }
        out.append(output)

    return out

# SCRIPT

# connect to MetaTrader 5
if not mt5.initialize():
    print("initialize() failed")
    mt5.shutdown()
# request connection status and parameters
print(mt5.terminal_info())
# get data on MetaTrader 5 version
print(mt5.version())
# request mt5 data from datetime range
ohlcv = mt5.copy_rates_range(ticker, mt5.TIMEFRAME_M1, utc_from, utc_to)
daily_ohlcv = mt5.copy_rates_range(ticker, mt5.TIMEFRAME_D1, utc_from, utc_to)
mt5.shutdown()

# convert time in seconds into the datetime format
df = pd.DataFrame(ohlcv)
df['time']=pd.to_datetime(df['time'], unit='s')

# adaptamos el dataframe D1 para luego hacer los analisis de las sesiones
daily_df = pd.DataFrame(daily_ohlcv)
daily_df['time']=pd.to_datetime(df['time'], unit='s')

df = df.set_index('time')
del df['real_volume']
del df['spread']

daily_df = daily_df.set_index('time')
del daily_df['real_volume']
del daily_df['spread']

# iteramos cada dia, y cada zona
zones_by_day = get_zone_by_day(df)

# ANALISIS

