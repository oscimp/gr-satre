# Geostationary satellite modelling using GMAT

If using Telstar11N relayed TWSTFT for one-way communication to a passive
user, the satellite motion around its equilibrium location by +/-75 us will
significantly degrade the receiver clock synchronization performance.

Unless a station keeping burst to bring the satellite back to its position
occurs, the satellite mechanics is predicted by celestial mechanics as implemented
in e.g. https://www.orekit.org/, https://nyxspace.com/ and https://github.com/nyx-space/anise or here https://software.nasa.gov/software/GSC-17177-1 (GMAT: General Mission Analysis Tool). We are using release 2022 found
on the Sourceforge, pre-build image for Ubuntu LTS running on a VirtualBox. The only
modification made to the GMAT archive content is updating the ``gmat_startup_file.txt`` in the
``bin/`` directory by modifying ``PLUGIN=../plugins/libPythonInterface_py310`` so that
the default Python3.10 can be used and commeting out ``# PLUGIN=../plugins/libMatlabInterface``
to remove Matlab support.

We follow tutorial 14 found in the ``help.html`` file at 
``docs/help/help.html#Orbit_Estimation_using_DSN_Range_and_Doppler_Data``.
This tutorial considers a deep space mission with velocity and position of the spacecraft
observed by the Deep Space Network (DSN) and is found in ``samples/Tut_Orbit_Estimation_using_DSN_Range_and_Doppler_Data.script`` which is the starting point of our 
analysis. We must adapt this script file to our problem using the following steps:

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
we go to fine orbit determination using the two-way time transfer observations.

## Orbit determination

After downloading the BIPM TWSTFT archive using
```
wget --recursive --no-parent https://webtai.bipm.org/ftp/pub/tai/data/2023/time_transfer/twstft
```
we produce the GMD file including date in MJD-30000, station name, observable (Range) and
observable type (9002 for two-way spacecraft-ground measurement in km), and measurement by 
multiplying the time of flight with the speed of light in km/s as found in the GNU Octave 
<a href="go.m">go.m</a> script. This is also the file where an index is arbitrarily assigned 
to each observatory, matching the definition in the script file: we have selected
OP=0, PTB=1, NPL=2, ROA=3, SP=4, IT=5. The fields including the date as MJD-30000, nature
of the observation (Range) and Observation type index number (9002), station index,
satellite index (99 arbitrarily to match the script definition) and measurement as the
two-way time of flight measurement multiplied by the speed of light in km/s. The resulting
file <a href="satre.gmd">satre.gmd</a> starts with
```
29947.006238 Range 9002 0 99 78717.485944
29947.006238 Range 9002 1 99 80017.802697
29947.006238 Range 9002 2 99 78827.757033
29947.006238 Range 9002 3 99 76188.405110
29947.006238 Range 9002 4 99 80939.476934
...
```
after sorting (``cat satre.gmd | sort > satresorted.gmd``) the output (<a href="satresorted.gmd">satresorted.gmd</a>).

The result of the analysis executed in the GUI or in the CLI from the ``bin/`` directory with 
```
./GmatConsole-R2022a satre.script
``` 
is as follows during the first iteration

<img src="analysis/IT.png">
<img src="analysis/NPL.png">
<img src="analysis/OP.png">
<img src="analysis/PTB.png">
<img src="analysis/ROA.png">
<img src="analysis/SP.png">
<img src="analysis/VSL.png">

but then fails with
```
********************************************
***  GMAT Console Application
********************************************

General Mission Analysis Tool
Console Based Version
Build Date: Jan 10 2023  15:04:14

Moderator is updating data files...
Moderator is creating core engine...
Skipping "../plugins/libOpenFramesInterface": GUI plugins are skipped in console mode
Successfully set Planetary Source to use: DE405
Successfully set Planetary Source to use: DE405
Successfully set Planetary Source to use: DE405
Setting nutation file to ../data/planetary_coeff/NUTATION.DAT
Setting leap seconds file to ../data/time/tai-utc.dat
2023-12-08 08:23:33 GMAT Moderator successfully created core engine
*** Use of MATLAB is disabled from the gmat_startup_file
Enter a script file, q to quit, or an option:  
Interpreting scripts from the file.
***** file: satre.script
Successfully set Planetary Source to use: DE405
Successfully set Planetary Source to use: DE405
Successfully interpreted the script
.................... Print out the whole sequence ........................................
   Command::NoOp
   Command::BeginMissionSequence
   Command::RunEstimator
.................... End sequence ........................................................
Running mission...
Successfully set Planetary Source to use: DE405
Successfully set Planetary Source to use: DE405
Kernel ../data/planetary_ephem/spk/DE405AllPlanets.bsp has been loaded.
Kernel ../data/planetary_coeff/SPICEPlanetaryConstantsKernel.tpc has been loaded.
Kernel ../data/time/SPICELeapSecondKernel.tls has been loaded.
Kernel ../data/planetary_coeff/SPICEEarthPredictedKernel.bpc has been loaded.
Kernel ../data/planetary_coeff/SPICEEarthCurrentKernel.bpc has been loaded.
Kernel ../data/planetary_coeff/earth_latest_high_prec.bpc has been loaded.
Kernel ../data/planetary_coeff/SPICELunaCurrentKernel.bpc has been loaded.
Kernel ../data/planetary_coeff/SPICELunaFrameKernel.tf has been loaded.
Number of thrown records due to:
     .Invalid measurement value : 0
     .Record duplication or time order : 0
Data file '../samples/satresortedshort.gmd' has 1753 of 1753 records used for estimation.
Total number of load records : 1753

List of tracking configurations (present in participant ID) for load records from data file '../samples/satresortedshort.gmd':
   Config 0: {{0,99,0},Range}
   Config 1: {{3,99,3},Range}
   Config 2: {{1,99,1},Range}
   Config 3: {{2,99,2},Range}
   Config 4: {{4,99,4},Range}
   Config 5: {{5,99,5},Range}

****   No tracking configuration was generated because the tracking configuration is defined in the script.

Initializing new mat data writer
WARNING: Initial Epoch is 59 days away from the first estimation epoch, propagation may take longer than expected.
********************************************************
    Performing Estimation (using "bat")
    
********************************************************

a priori state:
   Estimation Epoch:
   30284.3294216363622684646221 A.1 modified Julian
   30284.3294212384259258720299 TAI modified Julian
   05 Dec 2023 19:53:44.995 UTCG
   Sat.EarthMJ2000Eq.SMA = 42164.9994041
   Sat.EarthMJ2000Eq.ECC = 0.0002515
   Sat.EarthMJ2000Eq.INC = 0.0174999999933
   Sat.EarthMJ2000Eq.RAAN = 349.7528
   Sat.EarthMJ2000Eq.AOP = 254.4157
   Sat.EarthMJ2000Eq.TA = 91.1324142549

Warning: The orbit state transition matrix does not currently contain SRP contributions from shadow partial derivatives when using Spherical SRP.
Warning: measurement epoch 30226.004155397935 A1Mjd is outside EOP time range [7665.500021762034 A1Mjd, 30058.500428638676 A1Mjd]
Warning: The orbit state transition matrix does not currently contain SRP contributions from shadow partial derivatives when using Spherical SRP.
Warning: The orbit state transition matrix does not currently contain SRP contributions from shadow partial derivatives when using Spherical SRP.
Warning: The orbit state transition matrix does not currently contain SRP contributions from shadow partial derivatives when using Spherical SRP.
Warning: The orbit state transition matrix does not currently contain SRP contributions from shadow partial derivatives when using Spherical SRP.
Warning: The orbit state transition matrix does not currently contain SRP contributions from shadow partial derivatives when using Spherical SRP.
Warning: The orbit state transition matrix does not currently contain SRP contributions from shadow partial derivatives when using Spherical SRP.
Number of Records Removed Due To:
   . No Computed Value Configuration Available : 0
   . Out of Ramp Table Range   : 0
   . Signal Blocked : 0
   . Initial RMS Sigma Filter  : 0
   . Outer-Loop Sigma Editor : 0
Number of records used for estimation: 1753

   WeightedRMS residuals for this iteration : 0.515641681187
   BestRMS residuals                        : 0.515641681187
   PredictedRMS residuals for next iteration: 0.021646002011

------------------------------------------------------
Iteration 1

Current estimated state:
   Estimation Epoch:
   30284.3294216363622684646221 A.1 modified Julian
   30284.3294212384259258720299 TAI modified Julian
   05 Dec 2023 19:53:44.995 UTCG
   Sat.EarthMJ2000Eq.SMA = 42186.3671332
   Sat.EarthMJ2000Eq.ECC = 0.000641556499636
   Sat.EarthMJ2000Eq.INC = 0.283449221474
   Sat.EarthMJ2000Eq.RAAN = 83.7829182117
   Sat.EarthMJ2000Eq.AOP = 261.734554873
   Sat.EarthMJ2000Eq.TA = 348.860381327

Number of Records Removed Due To:
   . No Computed Value Configuration Available : 0
   . Out of Ramp Table Range   : 0
   . Signal Blocked : 0
   . Initial RMS Sigma Filter  : 0
   . Outer-Loop Sigma Editor : 1753
Number of records used for estimation: 0
Estimator Exception: Error: For Batch estimator bat, there are 6 solve-for parameters, and only 0 valid observable records remaining after editing. Please modify data editing criteria or provide a better a-priori estimate.

 *** Mission run failed.
===> Total Run Time: 215.402 seconds

========================================
EXITing GmatConsole with exit code 1
Console Application Execution Failed: Moderator::RunMission failed
```

After
* making sure that the measurement files were timestamped as TAI and not UTC as provided by BIPM
(TAI=UTC+37 seconds)
* reducing the duration of the analysis
* reducing the standard deviation sigma
* adding the ``bat.OLEUseRMSP=false``
* updating the database files by running in ``utilities/python`` the script ``python3 ./GMATDataFileManager.py``
the solution did converge as seen on the follownig residual plots:

<img src="analysis/ITconverged.png">
<img src="analysis/NPLconverged.png">
<img src="analysis/OPconverged.png">
<img src="analysis/PTBconverged.png">
<img src="analysis/ROAconverged.png">
<img src="analysis/SPconverged.png">
<img src="analysis/VSLconverged.png">

In this demonstration leading to the final result <a href="satre_orbit.report">satre_orbit.report</a> the convergence criterion was set to
``GMAT bat.RelativeTol = 1e-9;`` to force a 5th iteration but that seems not to improve over the 4th result (at least watching
the residual).

The final result seems disappointing as
```
Iter RecNum  UTCGregorian-Epoch     Obs-Type Parti.   Observed (O)  Computed (C)  Residual  Elev.
 4 831      05 Dec 2023 04:59:22.021  Range  4,99,4   80907.989978  80907.983326  0.006652  11.15
 4 832      05 Dec 2023 04:59:22.021  Range  6,99,6   79321.389443  79323.446412 -2.056969  18.81
 4 833      05 Dec 2023 06:02:22.021  Range  6,99,6   79325.752827  79326.606840 -0.854013  18.82
 4 834      05 Dec 2023 06:05:21.992  Range  0,99,0   78690.264496  78689.311680  0.952816  22.05
```
shows 6 m residual for SP-T11N-SP but -2 km and -854 m for VSL-T11N-VSL or 6.7 microseconds.

Interestingly enough, after convergence the solution is completely different from the original parameters deduced from the TLE analysis and conversion to Keplers:
```
                               Iteration5   Iteration4   Iteration3   Iteration2   Iteration1   A priori(TLE)
1 Sat.EarthMJ2000Eq.SMA  km     42164.312    42164.312    42164.343    42163.087   42189.0186     42165.000   
2 Sat.EarthMJ2000Eq.ECC        0.00029307   0.00029308   0.00029316   0.00029003   0.00062021    0.00025150       
3 Sat.EarthMJ2000Eq.INC  deg   0.17985757   0.17986262   0.17973784   0.17279207   0.18113320    0.01750000
4 Sat.EarthMJ2000Eq.RAAN deg  92.54306668  92.54388568  92.53551540  98.16849809  93.16270124  349.75280000  
5 Sat.EarthMJ2000Eq.AOP  deg 306.74494739 306.74335603 306.67835974 307.08439919 267.04987210  254.41570000
6 Sat.EarthMJ2000Eq.MA   deg 295.06551791 295.06628983 295.13973249 289.13468142 334.13289717   91.10359574   
```

# TODO

* check convergence quality? improve to reach sub-10 m residual ?

*Tested with 7-day long simulation, offset by 0 to 6 days: no improvement on the standard
deviation. When using historical TLE from <a href="tle2gmat_historical.py">tle2gmat_historical.py</a>,
convergence fails even though the orbital parameters are within the investigated time frame. Why?*

* at the moment only ranging information is used while it is desirable to use all 
communication combinations between all grond stations (X,99,Y). Does not seem to be implemented
in GMAT for Range analysis.
* add ionosphere behaviour at 14 GHz uplink/11 GHz downlink and check impact of satellite 
transponder delay:

*From ITU-R P.531-11 "Ionospheric propagation data and prediction methods requires for the
design of satellite services and systems", iono delay is (Eq. 4) 1.345e-7xN_t/f^2 and
will account for at most 6 ns at N_t=1e19 el/m^2 and f=14 GHz so negligible at the moment. 
Still would be interesting to know why the updated ig_rz.dat fails to load. When using
the original ig_rz.dat, GMAT complains it cannot work at a frequency other than 7.2 GHz.*

* add solar radiation pressure since the area of solar panels is not described at the moment

*SRPArea and DragArea properly documented from the Telstar11N manual + 10 ns transponder 
delay as documented from the group delay in the T11N manual. No improvement on the result.
What is TurnAroundRatio ?!*

* output satellite position in space to compensate for one-way time transfer
* extend analysis duration until a manoeuvre becomes visible (14 days at most)
