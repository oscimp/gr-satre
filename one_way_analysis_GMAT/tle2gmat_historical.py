#!/usr/bin/python3

# based on https://gist.github.com/kieranshanley/00f80997e4d07501187461d9fc702e7a
from tletools import TLE

# https://www.n2yo.com/satellite/?s=34111
tle_string = """
T11N
1 34111U 09009A   23308.88262088 -.00000248  00000-0  00000-0 0  9991
2 34111   0.0173 261.9733 0002458 311.4621 110.6497  1.00270341 36657
"""

tle_lines = tle_string.strip().splitlines()

tle = TLE.from_lines(*tle_lines)

orbit = tle.to_orbit()
print(f"TLE = {tle_string}")
print()
print("SMA = ", orbit.a)
print("ECC", orbit.ecc)
print("INC", orbit.inc)
print("RAAN", orbit.raan)
print("AOP", orbit.argp)
print("TA = ", orbit.nu)
print("Epoch = "+format(orbit.epoch)+"\n")
