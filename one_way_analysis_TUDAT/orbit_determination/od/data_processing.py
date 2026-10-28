import os
import pandas as pd
import numpy as np

STATIONS_COORDS = {
    #         lat         ,  lon (deg)  , alt (m)
    'OP01':   (48.83589889,   2.33496472,  78.00),
    'ROA01':  (36.46431389,  -6.20620361,  74.67),
    'SP01':   (57.71527778,  12.89083333, 225.00),
    'SP02':   (57.71527778,  12.89083333, 225.00),
    'IT01':   (45.01499639,   7.63907944, 306.64),
    'IT02':   (45.01499639,   7.63907944, 306.64),
    'VSL01':  (51.98550556,   4.38804167,  76.80),
    'CH01':   (46.92371833,   7.46416722, 612.82),
    'NPL02':  (51.42577778,  -0.34352778,  68.00),
    'PTB04':  (52.29716306,  10.46054611, 143.41),
    'PTB05':  (52.29716306,  10.46054611, 143.41),
    'UME01':  (40.78430556,  29.44695556, 229.17),
    'TIM01':  (48.73785333,   9.11252944, 529.00),
    'TIM02':  (48.73785333,   9.11252944, 529.00),
    'AOS01':  (52.27539500,  17.07577300, 120.00),
    'OCA01':  (43.75000000,   6.92300000, 1270.0),
    'LTFB01': (47.25129200,   5.99345000, 358.79),
}
RECEIVER = 'ENSMM'
RECEIVER_COORDS = (47.251292, 5.993450, 358.793)  # LTFB01
REFERENCE = 'IT01'
EXCLUDE = []


# Lecture du csv
def parse_differences(filepath):
    df = pd.read_csv(filepath)
    df = df[df['station'].isin(STATIONS_COORDS) & ~df['station'].isin(EXCLUDE)].copy()
    df['rx_station'] = RECEIVER
    df['tx_station'] = df['station']
    return df


# Conversion de l'heure UNIX de chaque enregistrement en J2000 (TDB) exigé par Tudat
def add_j2000_epochs(df):
    from tudatpy.astro import time_representation
    converter = time_representation.default_time_scale_converter()

    def compute_j2000_seconds(row):
        utc_j2000 = row['unix'] + 3.5 - 946728000.0
        return converter.convert_time(time_representation.utc_scale, time_representation.tdb_scale, utc_j2000)

    df['epoch_j2000_s'] = df.apply(compute_j2000_seconds, axis=1)
    return df