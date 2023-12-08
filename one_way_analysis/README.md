# Geostationary satellite modelling using GMAT

If using Telstar11N relayed TWSTFT for one-way communication to a passive
user, the satellite motion around its equilibrium location by +/-75 us will
significantly degrade the receiver clock synchronization performance.

Unless a station keeping burst to bring the satellite back to its position
occurs, the satellite mechanics is predicted by celestial mechanics as implemented
in e.g. https://www.orekit.org/, https://nyxspace.com/ or here https://software.nasa.gov/software/GSC-17177-1 (GMAT: General Mission Analysis Tool). We are using release 2022 found
on the Sourceforge, pre-build image for Ubuntu LTS running on a VirtualBox. The only
modification made to the GMAT archive content is updating the ``gmat_startup_file.txt`` in the
``bin/`` directory by modifying ``PLUGIN=../plugins/libPythonInterface_py310`` so that
the default Python3.10 can be used and commeting out ``# PLUGIN=../plugins/libMatlabInterface``
to remove the Matlab support.

We follow tutorial 14 found in the help.html file at 
docs/help/help.html#Orbit_Estimation_using_DSN_Range_and_Doppler_Data
This tutorial considers a deep space mission with velocity and position of the spacecraft
observed by the Deep Space Network (DSN) and is found in samples/Tut_Orbit_Estimation_using_DSN_Range_and_Doppler_Data.script which is the starting point of our analysis. We must
adapt this script file to our problem using the following steps:

## Ground station location and satellite orbital parameters

With respect to ther original script addressing a deep space network probe, we must 
* replace
the Sun centered framework with an Earth centered framework and replace the Cartesian
coordinate representation of the orbital parameters with a Kepler representation which sounds
more natural for a geostationary satellite. The conversion from NORAD's Two Line Elements
as found at https://www.n2yo.com/satellite/?s=34111 to Kepler parameters is achieved using
https://gist.github.com/kieranshanley/00f80997e4d07501187461d9fc702e7a
to produce
```
GMAT Sat.DateFormat = UTCGregorian;
GMAT Sat.Epoch = '05 Dec 2023 19:53:44.995';
GMAT Sat.CoordinateSystem = EarthMJ2000Eq;
GMAT Sat.DisplayStateType = Keplerian;
GMAT Sat.SMA = 42164.99940414229;
GMAT Sat.ECC = 0.0002514999999993337;
GMAT Sat.INC = 0.01749999999332662;
GMAT Sat.RAAN = 349.7528;
GMAT Sat.AOP = 254.4157000001674;
GMAT Sat.TA = 91.1324142548325;
```
* position the ground station at the appropriate location based on the GPS coordinates found
in each BIPM file header, e.g. https://webtai.bipm.org/ftp/pub/tai/data/2023/time_transfer/twstft/op/twop59.947 stating that
```
* ES   OP01 LA: N  48 50 09.236      LO: E  02 20 05.873   HT:    78.00 m
```
so we define for each ground station a set of fields such as
```
Create GroundStation OP;   
GMAT OP.CentralBody = Earth;
GMAT OP.StateType = Spherical;
GMAT OP.HorizonReference = Ellipsoid;
GMAT OP.Location2 = 2.33496472;
GMAT OP.Location1 = 48.83589880000001;
GMAT OP.Location3 = 0.078;
GMAT OP.Id = '0';
GMAT OP.AddHardware = {DSNTransmitter, DSNAntenna, DSNReceiver};
%OP.IonosphereModel       = 'IRI2007';
GMAT OP.TroposphereModel = 'HopfieldSaastamoinen';
GMAT OP.MinimumElevationAngle = 7;
GMAT OP.ErrorModels = {DSNrange};
```

*Warning: https://documentation.help/GMAT/GroundStation.html is erroneous in stating that
Location1 refers to the Longitude. This is incorrect and the help file in the GMAT archive
found at docs/help/help.html#GroundStation correctly states that Location1 is latitude.* 

* finally the ground station and satellite locations are added to the ground plot with
```
Create GroundTrackPlot DefaultGroundTrackPlot;
GMAT DefaultGroundTrackPlot.Add = {Sat, OP, IT, VSL, PTB, NPL, SP, ROA};
```
* a simulation propagating the satellite position during one day as
```
Propagate DefaultProp(Sat) {Sat.ElapsedSecs = 86400};
```

When executing in the GUI GMAT interface launched by executing in the ``bin/``
directory the executable ``GMAT-R2022a``, loading the ``satre_location.script`` and
executing (right arrow), the resulting charts should look like

<img src="2023-12-07-145316_1014x669_scrot.png">

<img src="2023-12-08-072511_1014x669_scrot.png">

Playing the simulation will show that the satellite rotates around the Earth and gets
back to its original location after one day.

Now that we are convinced that satellite parameters are correct (the satellite remains at the
same place with respect to Earth after 1-day) and the ground station locations are accurate,
be go to fine orbit determination using the two-way time transfer observations.

## Orbit determination

After downloading the BIPM TWSTFT archive using
```
wget --recursive --no-parent https://webtai.bipm.org/ftp/pub/tai/data/2023/time_transfer/twstft
```
we produce the GMD file including name in MJD-30000, station name, observable (Range) and
observable type, and measurement by multiplying the time of flight with the speed of light
in km/s as found in go.m. This is also the file where an index is arbitrarily assigned to
each observatory, matching the definition in the script file: we have selected
OP=0, PTB=1, NPL=2, ROA=3, SP=4, IT=5. The fields including the date as MJD-30000, nature
of the observation (Range) and Observation type index number (9002), station index,
satellite index (99 arbitrarily to match the script definition) and measurement as the
two-way time of flight measurement multiplied by the speed of light in km/s. The resulting
file satre.gmd starts with
```
29947.006238 Range 9002 0 99 78717.485944
29947.006238 Range 9002 1 99 80017.802697
29947.006238 Range 9002 2 99 78827.757033
29947.006238 Range 9002 3 99 76188.405110
29947.006238 Range 9002 4 99 80939.476934
...
```
after sorting (``cat satre.gmd | sort > satresorted.gmd``) the output (satresorted.gmd).
