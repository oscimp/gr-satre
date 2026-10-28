from tudatpy.astro import time_representation
from tudatpy.dynamics import propagation_setup

# The Propagator is configured to use 4th order runge kutta with 30 seconds step size to
# calculate the forces acting on Telstar11N
def setup_propagator(bodies, acceleration_models, simulation_start_epoch, simulation_end_epoch, estimated_state=None):
    start_time = time_representation.Time(simulation_start_epoch)
    end_time = time_representation.Time(simulation_end_epoch)
    step_size = time_representation.Time(30.0)

    if estimated_state is not None:
        initial_cartesian_state = estimated_state
    else:
        initial_cartesian_state = bodies.get("Telstar11N").ephemeris.cartesian_state(simulation_start_epoch)

    integrator_settings = propagation_setup.integrator.runge_kutta_fixed_step(
        time_step = step_size,
        coefficient_set = propagation_setup.integrator.CoefficientSets.rk_4
    )
    
    termination_condition = propagation_setup.propagator.time_termination(end_time)

    return propagation_setup.propagator.translational(
        central_bodies=["Earth"], acceleration_models=acceleration_models, bodies_to_integrate=["Telstar11N"],
        initial_states=initial_cartesian_state, initial_time=start_time,
        integrator_settings=integrator_settings, termination_settings=termination_condition
    )