cd /tmp
export UHD_IMAGES_DIR=/usr/share/uhd/images
d=`date +%s`
python3 ./SATRE_TV_cli.py && octave -q ./search_peak.m && mv all.mat $d.mat
