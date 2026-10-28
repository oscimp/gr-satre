import numpy as np

# Affichage des resultats
# erreur du fit et de la prediction, etat estimé, biais par station et erreur par heure
def generate_estimation_report(num_train_data, num_test_data, iterations, 
                               final_residuals_m, predict_residuals_m,
                               estimated_state, tle_state, 
                               active_stations, estimated_biases_m, 
                               t_fit_hours, t_predict_hours, SPEED_OF_LIGHT):
    
    final_residuals_s = final_residuals_m / SPEED_OF_LIGHT

    print("\n------------ resultats fitting ------------")
    print(f"# of train data : {num_train_data}")
    print(f"training iterations : {iterations}")
    print(f"RMS Residual  : {np.sqrt(np.mean(final_residuals_s**2)):.9e} s")
    print(f"RMS Residual  : {np.sqrt(np.mean(final_residuals_m**2)):.3f} m")

    print("\n--- Estimation initial J2000 position ---")
    print(estimated_state[:6])
    print(f"changement vs TLE : {np.linalg.norm(estimated_state[:3] - tle_state[:3]) / 1000:.3f} km, "
          f"{np.linalg.norm(estimated_state[3:6] - tle_state[3:6]):.3f} m/s")

    print("\n--- Estimation de biais par station (electriques et atmospheriques) ---")
    for stat_id in active_stations:
        bias_m = estimated_biases_m.get(stat_id, 0.0)
        bias_us = (bias_m / SPEED_OF_LIGHT) * 1e6
        print(f"{stat_id:6s}: {bias_m:9.3f} meters  ({bias_us:7.3f} microseconds)")

    print("\n------------ Resultats tests ------------")
    print(f"# of test data : {num_test_data}")
    if num_test_data > 0:
        print(f"RMS Residual: {np.sqrt(np.mean((predict_residuals_m / SPEED_OF_LIGHT)**2)):.9e} s")
        print(f"RMS Residual: {np.sqrt(np.mean(predict_residuals_m**2)):.3f} m")
    else:
        print("Aucune donnee de test disponible dans la fenetre temporelle.")

    print("\n-------- erreur RMS par Heure --------")
    def print_hourly_rms(t_hours, residuals, label):
        if len(residuals) == 0: return
        print(f"{label}")
        hourly_bins = {}
        for t, res in zip(t_hours, residuals):
            hourly_bins.setdefault(int(t), []).append(res)

        for hour in sorted(hourly_bins.keys()):
            res_array = np.array(hourly_bins[hour])
            rms = np.sqrt(np.mean(res_array**2))
            print(f"{hour:2d} h : {rms:10.3f} m  {rms / SPEED_OF_LIGHT * 1e9:7.2f} ns  ({len(res_array)} obs)")

    print_hourly_rms(t_fit_hours, final_residuals_m, "Training data")
    print()
    print_hourly_rms(t_predict_hours, predict_residuals_m, "Testing data")