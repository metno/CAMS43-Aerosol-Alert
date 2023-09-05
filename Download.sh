#!/bin/bash
#shell script to create from the daily downloaded files in ../download
#a yearly file

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

#load constants
set -x
if [ -z ${CAMS43AlertHome} ]
	then . /home/aerocom/bin/Constants.sh
else
	. "${CAMS43AlertHome}/Constants.sh"
fi
set +x

#URL to the ECMWF files
#DownloadURL='ftp://ftp.ecmwf.int/pub/macc/nrt/aod/netcdf/'
#DownloadURL='ftp://dissemination.ecmwf.int/DATA/CAMS_NREALTIME/'
DownloadURL='ftp://aux.ecmwf.int/DATA/CAMS_NREALTIME/'

echo "Downloading new files from ECMWF..."
cd "${DownloadDir}"
set -x
logdate=`date +%Y%m%d%H%M%S`
logfile="${FCModelPath}log/Download_${logdate}"

date=`date +%Y%m%d%H%M%S`
echo "started at ${date}" >> "${logfile}"
wget --ftp-user=${ftpuser} --ftp-password=${ftppass} --append-output="${logfile}.aod550" -N -r -l 8 --no-remove-listing -nH --cut-dirs=2 -A _aod550.nc ${DownloadURL} &
wget --ftp-user=${ftpuser} --ftp-password=${ftppass} --append-output="${logfile}.ssaod550" -N -r -l 8 --no-remove-listing -nH --cut-dirs=2 -A _ssaod550.nc ${DownloadURL} &
wget --ftp-user=${ftpuser} --ftp-password=${ftppass} --append-output="${logfile}.omaod550" -N -r -l 8 --no-remove-listing -nH --cut-dirs=2 -A _omaod550.nc ${DownloadURL} &
wget --ftp-user=${ftpuser} --ftp-password=${ftppass} --append-output="${logfile}.bcaod550" -N -r -l 8 --no-remove-listing -nH --cut-dirs=2 -A _bcaod550.nc ${DownloadURL} &
wget --ftp-user=${ftpuser} --ftp-password=${ftppass} --append-output="${logfile}.suaod550" -N -r -l 8 --no-remove-listing -nH --cut-dirs=2 -A _suaod550.nc ${DownloadURL} &
wget --ftp-user=${ftpuser} --ftp-password=${ftppass} --append-output="${logfile}.duaod550" -N -r -l 8 --no-remove-listing -nH --cut-dirs=2 -A _duaod550.nc ${DownloadURL} &
wget --ftp-user=${ftpuser} --ftp-password=${ftppass} --append-output="${logfile}.pm10" -N -r -l 8 --no-remove-listing -nH --cut-dirs=2 -A _pm10.nc ${DownloadURL} &
wget --ftp-user=${ftpuser} --ftp-password=${ftppass} --append-output="${logfile}.pm2p5" -N -r -l 8 --no-remove-listing -nH --cut-dirs=2 -A _pm2p5.nc ${DownloadURL} &
wait
date=`date +%Y%m%d%H%M%S`
echo "ended at ${date}" >> "${logfile}"

#ncftpget -u ${ftpuser} -p ${ftppass} -F -R -T ${DownloadURL}


IFS=$SAVEIFS
