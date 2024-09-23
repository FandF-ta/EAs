
import pandas as pd
import numpy as np
import MetaTrader5 as mt5
import pytz
from datetime import datetime
import matplotlib.pyplot as plt
import json
import plotly.express as px
import plotly.graph_objects as go
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
from sklearn.preprocessing import MinMaxScaler
from datetime import timedelta

#PARAMETERS
STD_MULTIPLIER = 1
ticker = "ES_U"
start_dt = "2021-05-25"
end_dt = "2024-06-28"
minute_data = "ES_U_M1_200912160000_202408012359.csv"
daily_data = "ES_U_Daily_200912160000_202408010000.csv"

def data_from_csv():
    df = pd.read_csv('C:/Users/iamfr/AlgoTrading/DATA/'+minute_data, sep='\t')
    df['<DATE>'] = pd.to_datetime(df['<DATE>'] + ' ' + df['<TIME>'])
    del df['<TIME>']
    del df['<VOL>']
    del df['<SPREAD>']
    df.columns = ['time', 'open','high', 'low', 'close', 'tick_volume']
    df = df.set_index('time')

    daily_df = pd.read_csv('C:/Users/iamfr/AlgoTrading/DATA/'+daily_data, sep='\t')
    #df['<DATE>'] = pd.to_datetime(df['<DATE>'] + ' ' + df['<TIME>'])
    #del df['<TIME>']
    del daily_df['<VOL>']
    del daily_df['<SPREAD>']
    daily_df.columns = ['time', 'open','high', 'low', 'close', 'tick_volume']
    daily_df = daily_df.set_index('time')
    #daily_df = df.resample('1B').agg({'open': 'first', 'high': 'max', 'low': 'min', 'close': 'last', 'tick_volume': 'sum'})

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

def get_no_fair_zone_by_day(df):
    out = []

    for index1, day in df.groupby(df.index.date):

        profile, value_area_df, MIN = create_market_profile(day, False)
        mean = profile['tick_volume'].mean()
        stddev = profile['tick_volume'].std()
        threshold = mean + stddev * STD_MULTIPLIER

        no_fair_value_zone = get_no_fair_range_zone(profile, threshold)

        if no_fair_value_zone == False:
            output = {
                "time": index1,
                "min_zone_high": np.nan,
                "min_zone_low": np.nan,
                "MIN": np.nan,
            }
            out.append(output)
        else:
            output = {
                "time": index1,
                "min_zone_high": no_fair_value_zone[1],
                "min_zone_low": no_fair_value_zone[0],
                "MIN": MIN,
            }
            out.append(output)

    return out

def get_max_vol_zone_by_day(df):
    out = []

    for index1, day in df.groupby(df.index.date):

        profile, value_area_df, POC = create_market_profile(day)
        mean = profile['tick_volume'].mean()
        stddev = profile['tick_volume'].std()
        threshold = mean + stddev * STD_MULTIPLIER

        max_value_zone = get_max_vol_zone(profile, threshold)

        if max_value_zone == False:
            output = {
                "time": index1,
                "max_zone_high": np.nan,
                "max_zone_low": np.nan,
                "POC": np.nan,
            }
            out.append(output)
        else:
            output = {
                "time": index1,
                "max_zone_high": max_value_zone[1],
                "max_zone_low": max_value_zone[0],
                "POC": POC,
            }
            out.append(output)

    return out

def calculate_PHF(main_df):
    # connect to MetaTrader 5
    if not mt5.initialize():
        print("initialize() failed")
        mt5.shutdown()

    main_df = main_df.loc[start_dt:]
    main_df['PHF'] = np.NaN # Create new column to allocate data
    # iterate main_df for adding zone to data
    for index, row in main_df.iterrows():
        dt1 = datetime.strptime(index.replace('.', '-'), "%Y-%m-%d")
        dt2 = dt1 + timedelta(hours=23, minutes=59, seconds=59) 
        
        ticks = mt5.copy_ticks_range(ticker, dt1, dt2, mt5.COPY_TICKS_ALL)

        # create DataFrame out of the obtained data
        df = pd.DataFrame(ticks)
        # convert time in seconds into the datetime format
        df['time']=pd.to_datetime(df['time'], unit='s')

        df = df.set_index('time')
        del df['last']
        del df['flags']
        del df['volume']
        del df['time_msc']
        del df['volume_real']

        flag_full_session = True #Flag for analising full day, not only the opening
        zone_output = 0 # Output from K-Means algorithm
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
            zone_output = cluster_centers

        # Add output to main_df
        main_df.loc[index, 'PHF'] = zone_output

    mt5.shutdown()
    main_df = main_df.drop(main_df[main_df.PHF <= 0.00].index)

    return main_df

def num1_next_session_close_zone(df):
    results = []

    for i in range(len(df.index)-1):
        if i == 0: pass
        high = df.iloc[i+1]['high']
        low = df.iloc[i+1]['low']
        zone_high = df.iloc[i]['max_zone_high']
        zone_low = df.iloc[i]['max_zone_low']

        # Comprobar si se cumple la condición
        if zone_high <= high and zone_high >= low and zone_low >= low and zone_low <= high:
            results.append(True)  # Cumple la condición
        else:
            results.append(False)  # No cumple la condición

    # Agregar un 0 adicional al final para igualar el tamaño de la columna con el dataframe original
    results.append(False)

    # Crear una nueva columna en el dataframe con los resultados
    df['SETUP_1'] = results

    return df['SETUP_1'].value_counts(normalize=True).mul(100).astype(str)+'%'

def num2_next_session_close_half_zone(df):
    results = []

    for i in range(len(df.index) - 1):
        if i == 0: pass
        apertura = df.iloc[i+1]['open']
        high = df.iloc[i+1]['high']
        low = df.iloc[i+1]['low']
        zone_high = df.iloc[i]['max_zone_high']
        zone_low = df.iloc[i]['max_zone_low']
        zone_mid = ((zone_high - zone_low) / 2) + zone_low

        if apertura >= zone_high:
            # Mitad superior
            if zone_high <= high and zone_high >= low and zone_mid >= low and zone_mid <= high:
                results.append(True)
            else:
                results.append(False)
        elif apertura <= zone_low:
            # Mitad inferior
            if zone_mid <= high and zone_mid >= low and zone_low >= low and zone_low <= high:
                results.append(True)
            else:
                results.append(False)
        else:
            results.append(False)
    # Agregar un 0 adicional al final para igualar el tamaño de la columna con el dataframe original
    results.append(False)

    # Crear una nueva columna en el dataframe con los resultados
    df['SETUP_2'] = results

    return df['SETUP_2'].value_counts(normalize=True).mul(100).astype(str)+'%'

def num3_from_open_to_range_max_volume(df):
    results = []

    for i in range(len(df.index) - 1):
        apertura = df.iloc[i+1]['open']
        high = df.iloc[i+1]['high']
        low = df.iloc[i+1]['low']
        zone_high = df.iloc[i]['max_zone_high']
        zone_low = df.iloc[i]['max_zone_low']

        if apertura >= zone_high:
            # Bajista
            if zone_low <= high and zone_low >= low:
                results.append(True)
            else:
                results.append(False)
        elif apertura <= zone_low:
            # Alcista
            if zone_high <= high and zone_high >= low:
                results.append(True)
            else:
                results.append(False)
        else: 
            results.append(False)

    # Agregar un 0 adicional al final para igualar el tamaño de la columna con el dataframe original
    results.append(False)

    # Crear una nueva columna en el dataframe con los resultados
    df['SETUP_3'] = results

    return df['SETUP_3'].value_counts(normalize=True).mul(100).astype(str)+'%'

def num4_POC_test(df):
    results = []

    for i in range(len(df.index) - 1):
        apertura = df.iloc[i+1]['open']
        high = df.iloc[i+1]['high']
        low = df.iloc[i+1]['low']
        poc = df.iloc[i]['POC']

        if apertura >= poc:
            # Bajista
            if poc <= high and poc >= low:
                results.append(True)
            else:
                results.append(False)

        elif apertura <= poc:
            # Alcista
            if poc <= high and poc >= low:
                results.append(True)
            else:
                results.append(False)
        else: 
            results.append(False)

    # Agregar un 0 adicional al final para igualar el tamaño de la columna con el dataframe original
    results.append(False)

    # Crear una nueva columna en el dataframe con los resultados
    df['SETUP_4'] = results

    return df['SETUP_4'].value_counts(normalize=True).mul(100).astype(str)+'%'

def cummulative_not_setup4_true(df):
    results = []
    tmp = 0

    for index, row in df.iterrows():
        if row['SETUP_4'] == False:
            tmp = tmp + 1
        else:
            results.append(tmp)
            tmp = 0

    nparr = np.array(results)

    return nparr.max()

def setup4_range_stddev(df):
    df['SETUP_4_range'] = abs(df['POC'] - df['open'])

    true_df = df.query('SETUP_4 == True')
    tmean = true_df['SETUP_4_range'].mean()
    tstddev = true_df['SETUP_4_range'].std()

    false_df = df.query('SETUP_4 == False')
    fmean = false_df['SETUP_4_range'].mean()
    fstddev = false_df['SETUP_4_range'].std()

    return tmean, fmean, tstddev, fstddev

def num5_PHF_test(df):
    results = []

    for i in range(len(df.index) - 1):
        apertura = df.iloc[i+1]['open']
        high = df.iloc[i+1]['high']
        low = df.iloc[i+1]['low']
        phf = df.iloc[i]['PHF']

        if apertura >= phf:
            # Bajista
            if phf <= high and phf >= low:
                results.append(True)
            else:
                results.append(False)

        elif apertura <= phf:
            # Alcista
            if phf <= high and phf >= low:
                results.append(True)
            else:
                results.append(False)
        else: 
            results.append(False)

    # Agregar un 0 adicional al final para igualar el tamaño de la columna con el dataframe original
    results.append(False)

    # Crear una nueva columna en el dataframe con los resultados
    df['SETUP_5'] = results

    return df['SETUP_5'].value_counts(normalize=True).mul(100).astype(str)+'%'

def cummulative_not_setup5_true(df):
    results = []
    tmp = 0

    for index, row in df.iterrows():
        if row['SETUP_4'] == False:
            tmp = tmp + 1
        else:
            results.append(tmp)
            tmp = 0

    nparr = np.array(results)

    return nparr.max()

#Calculate crossed probability of SETUP 4 || 5
def cross_prob_setup4_OR_5(df):
    results = []
    tmp = 0

    for index, row in df.iterrows():
        if row['SETUP_4'] == True or row['SETUP_5'] == True:
            tmp = tmp + 1
    
    return (tmp/len(df))*100

#Calculate crossed probability of SETUP 4 && 5
def cross_prob_setup4_AND_5(df):
    results = []
    tmp = 0

    for index, row in df.iterrows():
        if row['SETUP_4'] == True and row['SETUP_5'] == True:
            tmp = tmp + 1
    
    return (tmp/len(df))*100

# MAIN FUNCTION
def createDataframe():
    df, daily_df = data_from_csv()

    max_zones = get_max_vol_zone_by_day(df)
    df_max_zones = pd.DataFrame(max_zones)
    #df_zones['time'].astype('datetime64[ns]')
    df_max_zones = df_max_zones.set_index('time')
    df_max_zones.index.astype('datetime64[ns]')

    #zones = get_no_fair_zone_by_day(df)
    min_zones = get_no_fair_zone_by_day(df)
    df_min_zones = pd.DataFrame(min_zones)
    #df_zones['time'].astype('datetime64[ns]')
    df_min_zones = df_min_zones.set_index('time')
    df_min_zones.index.astype('datetime64[ns]')

    main_df_2 = pd.merge(df_max_zones, df_min_zones, on=daily_df.index)
    main_df_2 = main_df_2.set_index('key_0')
    main_df = pd.merge(daily_df, main_df_2, on=daily_df.index)
    #daily_df.join(df_zones, on=daily_df.index , how='inner')
    main_df = main_df.set_index('key_0')
    main_df.dropna()
    
    return main_df

if __name__=="__main__":
    df = createDataframe()

    print("SETUP 1: ", num1_next_session_close_zone(df))
    print("SETUP 2: ", num2_next_session_close_half_zone(df))
    print("SETUP 3: ", num3_from_open_to_range_max_volume(df))
    print("SETUP 4: ", num4_POC_test(df))
    print("SETUP 4 Cummulative negative incursion: ", cummulative_not_setup4_true(df))
    print("SETUP 5: ", num5_PHF_test(df))
    print("SETUP 5 Cummulative negative incursion: ", cummulative_not_setup5_true(df))
    print("Probability of SETUP 4 or SETUP 5: ", cross_prob_setup4_OR_5(df))
    print("Probability of SETUP 4 and SETUP 5: ", cross_prob_setup4_AND_5(df))