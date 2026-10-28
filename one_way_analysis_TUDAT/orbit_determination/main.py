import os
import pandas as pd
import numpy as np

from od.data_processing import *
from od.estimator import *
from od.observations import *
from od.physics_model import *
from od.prediction import *
from od.propagator import *
from od.reporting import *
from od.validation import *

from tudatpy.astro import time_representation

def main():
    SPEED_OF_LIGHT = 299792458.0
    test_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'differences.csv')

    df = parse_differences(test_file)
    df = add_j2000_epochs(df)
    df = df.sort_values(by='epoch_j2000_s').reset_index(drop=True)

    ## ------ begin time controls ------ ##
    fit_start = pd.Timestamp('2026-10-16 00:00:00').timestamp()
    fit_duration_hours = 24.0
    predict_duration_hours = 24.0
    ## ------- end time controls ------- ##

    apriori_position_m = 3000.0
    apriori_velocity_ms = 0.22
    observation_sigma_m = 2.0
    observation_sigma_s = observation_sigma_m / SPEED_OF_LIGHT

    fit_end = fit_start + fit_duration_hours * 3600.0
    predict_end = fit_end + predict_duration_hours * 3600.0

    df = df[(df['unix'] >= fit_start) & (df['unix'] < predict_end)]
    df = df[df.groupby('unix')['station'].transform('count') >= 3].reset_index(drop=True)
    active_stations = [s for s in STATIONS_COORDS if s in set(df['tx_station'])]
    print(f"Stations utilisées: {active_stations}")

    converter = time_representation.default_time_scale_converter()

    predict_end_j2000 = converter.convert_time(
        time_representation.utc_scale, 
        time_representation.tdb_scale, 
        predict_end - 946728000.0
    )

    sim_start_epoch = df['epoch_j2000_s'].min() - 1800.0
    sim_end_epoch = max(df['epoch_j2000_s'].max(), predict_end_j2000) + 1800.0

    try:
        # Setup
        bodies = setup_environment(sim_start_epoch, sim_end_epoch, STATIONS_COORDS)
        acceleration_models = setup_accelerations(bodies)
        obs_settings_list, link_defs = setup_observations(active_stations)
        tle_state = bodies.get("Telstar11N").ephemeris.cartesian_state(sim_start_epoch)

        # Definition de l'a priori, point de depart TLE + biais nuls (IT01 est la reference et donc n'a pas de biais)
        initial_parameters = np.concatenate([tle_state, np.zeros(len(link_defs))])
        apriori_sigma = [apriori_position_m] * 3 + [apriori_velocity_ms] * 3 + [1.0e-3] * len(link_defs)
        df_fit = df[df['unix'] < fit_end]
        no_reference = df[df['tx_station'] != REFERENCE]

        # Nos differences de temps de vol mises au format de Tudat
        fit_collection = observations_from_data(no_reference[no_reference['unix'] < fit_end], link_defs, observation_sigma_s)
        all_collection = observations_from_data(no_reference, link_defs, observation_sigma_s)

        # Temps de vol station_1 -> sat -> station_2 avec l'orbite estimee
        # La fonction predict(..) est un wrapper de la fonction od.prediction.base_predict()
        # qui sert a faire des predictions sans passer les parametres de base à chaque appel
        def predict(station_1, station_2, time):
            travel_time_s = base_predict(station_1, station_2, time, bodies, df, sim_start_epoch, sim_end_epoch)
            print(f"{station_1} -> sat -> {station_2} à {time} : {travel_time_s :.12f} s")

            return travel_time_s

        # Execution
        print("\n------------ OD started ------------")
        estimator, estimated_parameters, iterations = run_orbit_determination(
            bodies, acceleration_models, fit_collection, obs_settings_list, link_defs,
            initial_parameters, apriori_sigma, sim_start_epoch, sim_end_epoch)
        
        estimated_state = estimated_parameters[:6]
        estimated_biases_m = {s: estimated_parameters[6 + i] * SPEED_OF_LIGHT for i, s in enumerate(link_defs)}

        residuals = residuals_per_recording(estimator, all_collection, bodies)
        reference_rows = pd.DataFrame({'station': REFERENCE, 'res_m': 0.0,
                                       'epoch_j2000_s': df.loc[df['tx_station'] == REFERENCE, 'epoch_j2000_s']})
        residuals = pd.concat([residuals, reference_rows], ignore_index=True).sort_values('epoch_j2000_s')
        
        recording = residuals['epoch_j2000_s'].round(3)
        residuals['res_m'] -= residuals.groupby(recording)['res_m'].transform('mean')
        
        is_fit = (residuals['epoch_j2000_s'] < df.loc[df['unix'] >= fit_end, 'epoch_j2000_s'].min() - 1.0).to_numpy()
        final_residuals_m = residuals.loc[is_fit, 'res_m'].to_numpy()
        predict_residuals_m = residuals.loc[~is_fit, 'res_m'].to_numpy()

        t0 = df['epoch_j2000_s'].min()
        t_fit_hours = (residuals.loc[is_fit, 'epoch_j2000_s'].values - t0) / 3600.0
        t_predict_hours = (residuals.loc[~is_fit, 'epoch_j2000_s'].values - t0) / 3600.0

        # Rapport d'execution
        generate_estimation_report(
            num_train_data=len(df_fit),
            num_test_data=(~is_fit).sum(),
            iterations=iterations,
            final_residuals_m=final_residuals_m,
            predict_residuals_m=predict_residuals_m,
            estimated_state=estimated_state,
            tle_state=tle_state,
            active_stations=active_stations,
            estimated_biases_m=estimated_biases_m,
            t_fit_hours=t_fit_hours,
            t_predict_hours=t_predict_hours,
            SPEED_OF_LIGHT=SPEED_OF_LIGHT
        )

        print()

        # Tests indépendants
        predict("LTFB01", "LTFB01", "17-10-2026-00-07-00")

        validate("./test_data/ltfb01_17_oct.txt", bodies, df, sim_start_epoch, sim_end_epoch)

    except Exception as e:
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()