import os
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime

from od.prediction import *

# Lecture du fichier de test
def parse_file(filepath):    
    with open(filepath, 'r') as file:
        date = ''
        data = []
        for line in file:
            if not line.strip():
                continue

            if line.startswith("#"):
                if line.startswith("##"):
                    date = line.split()[2]
            else:
                parts = line.split()
                datetime = date + '-' + parts[2][0:2] + "-" + parts[2][2:4] + "-" + parts[2][4:6]
                data.append({
                        "tx"    : parts[0],
                        "rx"    : parts[1],
                        "time"  : datetime,
                        "meas"  : float(parts[3])
                    })

        return data

# On compare chaque mesure au temps de vol predit par l'orbite estimee (mesure - prediction) et on trace l'ecart
def validate(filepath, bodies, df, sim_start_epoch, sim_end_epoch):
    data = parse_file(filepath)
    file_name = os.path.split(filepath)[-1]

    residuals_s = []
    plt_data = {}
    plt_time = {}

    for i in data:
        result = base_predict(i['tx'], i['rx'], i['time'],
            bodies, df, sim_start_epoch, sim_end_epoch)
        meas = np.float64(i['meas'])
        residuals_s.append(meas - result)
        print(i['tx'], i['rx'], i['time'], f"{(meas - result)*1e9}" )

        current_time = datetime.strptime(i['time'], "%d-%m-%Y-%H-%M-%S")
        key = f"{i['tx']}, {i['rx']}"

        if key in plt_data:
            plt_data[key].append(meas - result)
            plt_time[key].append(current_time)
        else:
            plt_data[key] = [meas - result]
            plt_time[key] = [current_time]

    print(f'--------- Validation sur {file_name} ---------')
    residuals_s = np.array(residuals_s)
    print(f'rms error {np.sqrt(np.mean(residuals_s**2)):.12f} s')
    
    keys = []
    for k in plt_data:
        keys.append(k)
        plt.plot(plt_time[k], plt_data[k], label="k")

    plt.gcf().autofmt_xdate()
    
    plt.legend(keys)
    plt.show()