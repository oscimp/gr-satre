import pandas as pd
from tudatpy.astro import time_representation
from tudatpy.estimation import observable_models_setup
from tudatpy.estimation.observations_setup import observations_simulation_settings
from tudatpy.estimation.observations_setup import observations_wrapper

# This functon allows for the simulation of the theoretical time between two stations : 
# station1 -> sat -> station2 with accepted time in format: "jj-mm-aaaa-hh-mm-ss" (UTC)
def base_predict(station_1, station_2, time, bodies, df, sim_start_epoch, sim_end_epoch):
    SPEED_OF_LIGHT = 299792458.0
    
    unix = pd.to_datetime(time, format="%d-%m-%Y-%H-%M-%S").timestamp()
    
    # Conversion de l'heure UNIX en J2000
    converter = time_representation.default_time_scale_converter()
    epoch = converter.convert_time(
        time_representation.utc_scale, 
        time_representation.tdb_scale, 
        unix - 946728000.0
    )
    
    # Vérification que la date demandée est comprise dans l'orbit simulée
    if not sim_start_epoch + 1.0 < epoch < sim_end_epoch:
        print(f"{time} : en dehors de l'orbite calculee (du {pd.Timestamp(df['unix'].min() - 1800, unit='s')} "
              f"au {pd.Timestamp(df['unix'].max() + 1800, unit='s')})")
        return None

    # Configuration de la géométrie du lien station1 -> sat -> station2
    links = observable_models_setup.links
    link = links.LinkDefinition({
        links.transmitter: links.body_reference_point_link_end_id("Earth", station_1),
        links.reflector1: links.body_origin_link_end_id("Telstar11N"),
        links.receiver: links.body_reference_point_link_end_id("Earth", station_2)
    })
    
    # Configuration de la simulation
    settings = [observable_models_setup.model_settings.n_way_range(link)]    
    simulators = observations_simulation_settings.create_observation_simulators(settings, bodies)
    simulation = observations_simulation_settings.tabulated_simulation_settings(
        observable_models_setup.model_settings.ObservableType.n_way_range_type, 
        link, 
        [time_representation.Time(epoch)]
    )
    
    result = observations_wrapper.simulate_observations([simulation], simulators, bodies)

    # Tudat retourne une distance et donc on divise la distance de vol par la vitesse de lumiere
    travel_time_s = result.get_single_observation_sets()[0].concatenated_observations[0] / SPEED_OF_LIGHT
    
    return travel_time_s