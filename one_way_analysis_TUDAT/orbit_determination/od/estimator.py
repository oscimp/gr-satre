import numpy as np
import pandas as pd

from od.propagator import *

from tudatpy.dynamics import parameters_setup

from tudatpy.estimation import estimation_analysis, observable_models_setup, observations
from tudatpy.dynamics import simulator
import tudatpy.estimation as estimation

# Definition des inconnus à estimer
# position et vitesse initiales du satellite et un biais par station
def setup_estimator(bodies, propagator_settings, observation_settings_list, link_definitions):
    parameter_settings = parameters_setup.initial_states(propagator_settings, bodies)

    obs_type = estimation.observable_models_setup.model_settings.ObservableType.differenced_time_of_arrival_type

    for stat_id, link_def in link_definitions.items():
        parameter_settings.append(
            parameters_setup.absolute_observation_bias(link_def, obs_type)
        )

    parameters_to_estimate = parameters_setup.create_parameter_set(parameter_settings, bodies)

    estimator = estimation_analysis.Estimator(
        bodies, parameters_to_estimate, observation_settings_list, propagator_settings
    )

    return estimator, parameters_to_estimate

# Determination d'orbite avec le solver de Tudat (10 iterations max) avec l'a priori sur le TLE
def run_orbit_determination(bodies, acceleration_models, observation_collection, observation_settings_list,
                            link_definitions, initial_parameters, apriori_sigma, start_epoch, end_epoch):
    SPEED_OF_LIGHT = 299792458.0
    propagator_settings = setup_propagator(bodies, acceleration_models, start_epoch, end_epoch, initial_parameters[:6])
    estimator, parameters = setup_estimator(bodies, propagator_settings, observation_settings_list, link_definitions)
    estimation_input = estimation_analysis.EstimationInput(observation_collection,
        inverse_apriori_covariance=np.diag(1.0 / np.array(apriori_sigma) ** 2),
        convergence_checker=estimation_analysis.estimation_convergence_checker(maximum_iterations=10))
    estimation_input.define_estimation_settings(print_output_to_terminal=False)
    estimation_output = estimator.perform_estimation(estimation_input)

    # Affichage de l'erreur et de la correction à chaque iteration
    history = np.array(estimation_output.parameter_history)
    rms_history = np.sqrt(np.mean(np.array(estimation_output.residual_history) ** 2, axis=0)) * SPEED_OF_LIGHT
    for iteration in range(history.shape[1] - 1):
        correction = history[:, iteration + 1] - history[:, iteration]
        print(f"iteration {iteration + 1} : RMS {rms_history[iteration]:10.3f} m, "
              f"correction {np.linalg.norm(correction[:3]):9.1f} m  {np.linalg.norm(correction[3:6]):.4f} m/s")

    # Application de l'orbite et des biais finaux dans bodies pour usage
    final_parameters = history[:, -1]
    parameters.parameter_vector = final_parameters
    final_propagator = setup_propagator(bodies, acceleration_models, start_epoch, end_epoch, final_parameters[:6])
    final_propagator.processing_settings.set_integrated_result = True
    simulator.create_dynamics_simulator(bodies, final_propagator)

    return estimator, final_parameters, history.shape[1] - 1


# Tudat calcule les residus de chaque observation avec l'orbite finale, et on les range dans un tableau station / heure
def residuals_per_recording(estimator, observation_collection, bodies):
    SPEED_OF_LIGHT = 299792458.0
    observations.compute_residuals_and_dependent_variables(observation_collection, estimator.observation_simulators, bodies)
    tables = []
    for obs_set in observation_collection.get_single_observation_sets():
        tables.append(pd.DataFrame({
            'station': obs_set.link_definition.link_end_id(observable_models_setup.links.receiver).reference_point,
            'epoch_j2000_s': [t.to_float() for t in obs_set.observation_times],
            'res_m': np.array(obs_set.concatenated_residuals) * SPEED_OF_LIGHT}))
    return pd.concat(tables, ignore_index=True)