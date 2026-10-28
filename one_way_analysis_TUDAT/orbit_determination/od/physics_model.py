import numpy as np
import pandas as pd

from od.data_processing import *

from tudatpy.interface import spice
from tudatpy.dynamics import environment_setup, propagation_setup
from tudatpy.astro import element_conversion, time_representation
from sgp4.api import Satrec, jday
from sgp4.propagation import gstime

spice.load_standard_kernels()


# Configuration de la Terre avec le modele de rotation IAU_2006
def default_body_settings(bodies_to_create):
    body_settings = environment_setup.get_default_body_settings(bodies_to_create, "Earth", "J2000")
    body_settings.get("Earth").rotation_model_settings = environment_setup.rotation_model.gcrs_to_itrs(
        environment_setup.rotation_model.iau_2006, "J2000")
    body_settings.get("Earth").gravity_field_settings.associated_reference_frame = "ITRS"  # requis par Tudat
    return body_settings


EARTH_ROTATION = environment_setup.create_system_of_bodies(default_body_settings(["Earth"])).get("Earth").rotation_model


# On utilise SGP4 pour lire le TLE et predire l'etat initial du satellite
# Puis on convertit vers J2000 exigé par Tudat
def tle_states(tle1, tle2, start_epoch, end_epoch):
    converter = time_representation.default_time_scale_converter()
    sat = Satrec.twoline2rv(tle1, tle2)

    def position(epoch):
        utc = converter.convert_time(time_representation.tdb_scale, time_representation.utc_scale, epoch)
        t = pd.Timestamp(utc + 946728000.0, unit='s')
        jd, fr = jday(t.year, t.month, t.day, t.hour, t.minute, t.second + t.microsecond * 1e-6 + t.nanosecond * 1e-9)
        _, r, _ = sat.sgp4(jd, fr)
        g = gstime(jd + fr)
        x, y, z = np.array(r) * 1000.0
        ecef = np.array([x * np.cos(g) + y * np.sin(g), -x * np.sin(g) + y * np.cos(g), z])
        return EARTH_ROTATION.body_fixed_to_inertial_rotation(epoch) @ ecef

    return {t: np.concatenate([position(t), (position(t + 1.0) - position(t - 1.0)) / 2.0])
            for t in np.arange(start_epoch, end_epoch, 60.0)}


# On convertit les coordonnees LA, LO et Alt en coordonnees cartesiennes
def wgs84(lat, lon, alt):
    a, e2 = 6378137.0, 6.69437999014e-3
    lat, lon = np.radians(lat), np.radians(lon)
    n = a / np.sqrt(1 - e2 * np.sin(lat) ** 2)
    return np.array([(n + alt) * np.cos(lat) * np.cos(lon), (n + alt) * np.cos(lat) * np.sin(lon),
                     (n * (1 - e2) + alt) * np.sin(lat)])


# Déclaration de l'environment physique de Tudat, Terre, soleil, sat, stations etc ..
def setup_environment(start_epoch, end_epoch, stations_coords):
    bodies_to_create = ["Earth", "Sun", "Moon"]
    body_settings = default_body_settings(bodies_to_create)

    body_settings.add_empty_settings("Telstar11N")
    body_settings.get("Telstar11N").constant_mass = 4000.0

    # 15 Octobre 2026 22:18
    tle1 = "1 34111U 09009A   26288.92948087 -.00000249  00000-0  00000-0 0  9997"
    tle2 = "2 34111   0.0337  83.5888 0002616 122.8963 115.0644  1.00272063 47453"
    body_settings.get("Telstar11N").ephemeris_settings = environment_setup.ephemeris.tabulated(
        tle_states(tle1, tle2, start_epoch - 3600.0, end_epoch + 3600.0), "Earth", "J2000")

    rad_press_settings = environment_setup.radiation_pressure.cannonball_radiation_target(
        40.0, 1.2 * 3.5, {"Sun": ["Earth"]}
    )
    body_settings.get("Telstar11N").radiation_pressure_target_settings = rad_press_settings
    bodies = environment_setup.create_system_of_bodies(body_settings)

    for stat_id, coords in list(stations_coords.items()) + [(RECEIVER, RECEIVER_COORDS)]:
        lat, lon, alt = coords
        station_settings = environment_setup.ground_station.basic_station(
            stat_id, wgs84(lat, lon, alt), element_conversion.cartesian_position_type)
        environment_setup.add_ground_station(bodies.get("Earth"), station_settings)

    return bodies

# Definition des accelerations : Gravité de la terre, de la lune et du soleil
# ainsi que la radiation solaire
def setup_accelerations(bodies):
    accelerations_settings_telstar = dict(
        Earth=[propagation_setup.acceleration.spherical_harmonic_gravity(6, 6)],
        Sun=[propagation_setup.acceleration.point_mass_gravity(), propagation_setup.acceleration.radiation_pressure()],
        Moon=[propagation_setup.acceleration.point_mass_gravity()]
    )
    return propagation_setup.create_acceleration_models(
        bodies, {"Telstar11N": accelerations_settings_telstar}, ["Telstar11N"], ["Earth"]
    )