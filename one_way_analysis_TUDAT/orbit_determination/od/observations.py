import numpy as np

from od.data_processing import *

from tudatpy.astro import time_representation
from tudatpy.estimation import observable_models_setup
from tudatpy.estimation.observable_models_setup import biases
from tudatpy.estimation import observations
from tudatpy.estimation.observations_setup import observations_simulation_settings
from tudatpy.estimation.observations_setup import observations_wrapper

# Mapping the stations and declaring the DTOA link for all stations except the reference
# and initiates a bias with initial value 0.0 that the estimator will solve for later
def setup_observations(active_stations):
    observation_settings_list = []
    link_definitions = {}

    initial_bias = biases.absolute_bias(np.array([0.0]))

    for stat_id in active_stations:
        if stat_id == REFERENCE:
            continue
        link_ends = dict()
        ## Tudat impose pour un DTOA un emeteur entendu par deux recepteur et vu que la distance est la
        ## meme on inverse pour dire l'emetteur est Telstar et les stations sont receptrices
        telstar_id = observable_models_setup.links.body_origin_link_end_id("Telstar11N")
        stat_link_id = observable_models_setup.links.body_reference_point_link_end_id("Earth", stat_id)
        reference_id = observable_models_setup.links.body_reference_point_link_end_id("Earth", REFERENCE)

        link_ends[observable_models_setup.links.transmitter] = telstar_id
        link_ends[observable_models_setup.links.receiver] = stat_link_id
        link_ends[observable_models_setup.links.receiver2] = reference_id

        link_def = observable_models_setup.links.LinkDefinition(link_ends)
        link_definitions[stat_id] = link_def

        obs_settings = observable_models_setup.model_settings.differenced_time_of_arrival(
            link_def,
            bias_settings=initial_bias
        )
        observation_settings_list.append(obs_settings)

    return observation_settings_list, link_definitions

# On construit les observations de Tudat avec nos données
# (en secondes, datées à l'heure de l'enregistrement)
def observations_from_data(df, link_definitions, observation_sigma_s):
    obs_type = observable_models_setup.model_settings.ObservableType.differenced_time_of_arrival_type

    observation_sets = []
    for stat_id, link_def in link_definitions.items():
        stat_df = df[df['tx_station'] == stat_id]
        if len(stat_df) == 0: continue

        observation_sets.append(observations.create_single_observation_set(
            obs_type, link_def.link_ends,
            [np.array([val]) for val in stat_df['minus_IT01_ns'].to_numpy() * 1e-9],
            [time_representation.Time(t) for t in stat_df['epoch_j2000_s'].to_numpy()],
            observable_models_setup.links.receiver))

    observation_collection = observations.ObservationCollection(observation_sets)
    observation_collection.set_constant_weight(1.0 / observation_sigma_s ** 2)
    return observation_collection