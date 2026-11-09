from od.execution import run_model
from od.validation import validate
from od.prediction import base_predict, predict_actual_flight

def main():
    SPEED_OF_LIGHT = 299792458.0

    # 15 Octobre 2026 22:18
    tle1 = "1 34111U 09009A   26288.92948087 -.00000249  00000-0  00000-0 0  9997"
    tle2 = "2 34111   0.0337  83.5888 0002616 122.8963 115.0644  1.00272063 47453"

    ## ------ begin time controls ------ ##
    fit_start = '2026-10-16 00:00:00'
    fit_duration_hours = 24.0
    predict_duration_hours = 24.0
    ## ------- end time controls ------- ##

    try:
        bodies, df, sim_start, sim_end, estimated_biases = run_model(
            tle1, tle2, fit_start, fit_duration_hours, predict_duration_hours
        )

        # Wrapper de la fonction base_predict pour eviter de passer les arguments à chaque fois
        def predict_geometric_flight(station_1, station_2, time):
            travel_time_s = base_predict(station_1, station_2, time, bodies, df, sim_start, sim_end)
            print(f"{station_1} -> sat -> {station_2} à {time} : {travel_time_s :.12f} s")

            return travel_time_s
        
        # Tests indépendants
        predict_geometric_flight("LTFB01", "LTFB01", "16-10-2026-00-07-00")
        
        # Validation sur fichier externe
        validate("./test_data/ltfb01_17_oct.txt", bodies, df, sim_start, sim_end, estimated_biases, SPEED_OF_LIGHT)

    except Exception as e:
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()