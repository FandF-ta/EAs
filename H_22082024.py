
import pandas as pd
import numpy as np
import MetaTrader5 as mt5
import pytz
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
from sklearn.preprocessing import MinMaxScaler
# windows_service.py
import win32serviceutil
import win32service
import win32event
import servicemanager
import os
import sys
import time
import logging


#PARAMETERS
STD_MULTIPLIER = 1
ticker = "ES_U"

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

def calculate_PHF(mt5, date, flag_full_session = True):

    # Get time delta for analising the session
    dt1 = datetime.strptime(date, "%Y-%m-%d")
    dt2 = dt1 + timedelta(hours=23, minutes=59, seconds=59)
    # create DataFrame out of the obtained data
    df = pd.DataFrame(mt5.copy_ticks_range(ticker, dt1, dt2, mt5.COPY_TICKS_ALL))
    # convert time in seconds into the datetime format
    df['time']=pd.to_datetime(df['time'], unit='s')

    df = df.set_index('time')
    del df['last']
    del df['flags']
    del df['volume']
    del df['time_msc']
    del df['volume_real']

    for index1, day in df.groupby(df.index.date):
        # Iterating each session
        start_session = pd.to_datetime(index1.strftime('%Y-%m-%d') + ' ' + '15:30:00')
        end_session = pd.to_datetime(index1.strftime('%Y-%m-%d') + ' ' + '16:00:00')

        # DF contains the session to analise.
        if flag_full_session:
            refdf = day
        else:
            refdf = day.loc[start_session:end_session]
        
        # create a MinMaxScaler object
        scaler = MinMaxScaler()

        # fit and transform the data
        normalized_data = scaler.fit_transform(refdf)

        # create a new DataFrame with the normalized data
        ndf = pd.DataFrame(normalized_data, columns=refdf.columns)

        ndf['ask'] = ndf['ask'].fillna(ndf['bid'])
        ndf['bid'] = ndf['bid'].fillna(ndf['ask'])

        ndf_to_matrix = ndf.values
        # Preparing data for clustering: Normalize time and price to have similar scales
        X_time = np.linspace(0, 1, len(ndf_to_matrix)).reshape(-1, 1)
        X_price = (ndf['ask'].values - np.min(ndf['ask'])) / (np.max(ndf['ask']) - np.min(ndf['ask']))
        X_cluster = np.column_stack((X_time, X_price))

        # Applying KMeans clustering
        num_clusters = 1
        kmeans = KMeans(n_clusters=num_clusters)
        kmeans.fit(ndf_to_matrix)

        # Extract cluster centers and rescale back to original price range
        cluster_centers = kmeans.cluster_centers_[:, 1] * (np.max(refdf['ask']) - np.min(refdf['ask'])) + np.min(refdf['ask'])
        
        zones = cluster_centers.tolist()
        #output = {
        #    "date": index1.strftime('%Y-%m-%d'),
        #    "zones": zones,
        #}
        phf = cluster_centers

    return phf 

class MyService(win32serviceutil.ServiceFramework):
    _svc_name_ = "PHF & POC Serve Sript"
    _svc_display_name_ = "F&F PHF and POC server"
    _svc_description_ = "Advanced analysis tool for intraday trading."

    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)
        self.running = True

    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.hWaitStop)
        self.running = False

    def SvcDoRun(self):
        servicemanager.LogMsg(servicemanager.EVENTLOG_INFORMATION_TYPE, servicemanager.PYS_SERVICE_STARTED,
                              (self._svc_name_, ""))
        self.main()

    def main(self): #MAIN SCRIPT

        logging.basicConfig(filename='phf_poc_fnf_service.log', level=logging.INFO)
                
        # Main loop to check time every minute
        while self.running:
            current_time = datetime.now()
            
            # Calculate time to the next midnight
            next_midnight = (current_time + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
            time_to_midnight = (next_midnight - current_time).total_seconds()
            
            # Wait until midnight (or stop if the service is interrupted)
            logging.info(f"Waiting until midnight: {next_midnight}")
            result = win32event.WaitForSingleObject(self.hWaitStop, int(time_to_midnight * 1000))  # Convert seconds to milliseconds

            if result == win32event.WAIT_OBJECT_0:
                break  # Service is stopping
      
            # connect to MetaTrader 5
            if not mt5.initialize():
                print("initialize() failed")
                mt5.shutdown()

            # MAIN PROGRAM
            phf = calculate_PHF(mt5)
            mt5.shutdown()

if __name__ == '__main__':
    if len(sys.argv) == 1:
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(MyService)
        servicemanager.StartServiceCtrlDispatcher()
        win32serviceutil.HandleCommandLine(MyService)
    else:
        win32serviceutil.HandleCommandLine(MyService)
