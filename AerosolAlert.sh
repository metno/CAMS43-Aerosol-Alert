#!/bin/bash
#main shell script to produce the data needed for the aerosol alert 
#calculations of the CAMS43 project
#
#IMPORTANT NOTICE
#BECAUSE WE NEED BASH'S INTEGER ARITHMETICS THE CRON STANDARD SHELL DASH IS NOT ABLE
#TO RUN THIS SCRIPT. 
#The crontab entry has to look like thise therefore:
#0 3 * * *  /bin/bash /home/jang/bin/Forecast_ALERTAER.sh
#
#This script is the main script and will call several other scripts
#for the different tasks it is performing. These scripts can also be 
#called separately e.g. for testing
#- data download from ECMWF (Download.sh)
#- unpapcking and interpolatikn to common grid (Interpolate.sh)
#- create a daily climatology (from the common monthly one; MakeDailyClimatology.sh)
#- create the yearly data files needed by the aerocom-tools (CreateYearlyFile.sh;
#  calls CreateYearlyFileSingleVar.sh to create the needed variables in parallel)
#- calculate the actual alert level (CalculateAlert.sh)

#####################################################
#Created 20180220 by Jan Griesfeller mor met.no
#
#last changed:	20180227	JG	initial working version
#####################################################


#make sure the bash is not bothered by space in file names
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

#load constants
set -x
echo ${CAMS43AlertHome}
if [ -z ${CAMS43AlertHome} ]
	then . /home/aerocom/bin/Constants.sh
	CAMS43AlertHome="/home/aerocom/bin/"
else
	. "${CAMS43AlertHome}/Constants.sh"
fi
set +x

if [ ${StartDownloadFlag} -gt 0 ]
	then
	echo "Downloading new files from ECMWF..."
	date=`date +%Y%m%d%H%M%S`
	logfile="${FCModelPath}log/Download_${date}"
	echo "${CAMS43AlertHome}/Download.sh started at ${date}" 
	echo "logfile at ${logfile}" 
	echo "started at ${date}" > "${logfile}"
	${CAMS43AlertHome}/Download.sh &>>${logfile}
	date=`date +%Y%m%d%H%M%S`
	echo "ended at ${date}" >> "${logfile}"
fi

#interpolate to common grid
if [ ${StartInterpolationFlag} -gt 0 ]
	then
	date=`date +%Y%m%d%H%M%S`
	logfile="${FCModelPath}log/Interpolation_log_${date}"
	echo "${CAMS43AlertHome}/Interpolate.sh started at ${date}" 
	echo "logfile at ${logfile}" 
	echo "started at ${date}" > "${logfile}"
	${CAMS43AlertHome}/Interpolate.sh &>>${logfile}
	date=`date +%Y%m%d%H%M%S`
	echo "ended at ${date}" >> "${logfile}"
fi

#create a daily climatology from the monthly one
if [ ${StartDailyClimatologyFlag} -gt 0 ]
	then
	date=`date +%Y%m%d%H%M%S`
	logfile="${FCModelPath}log/MakeDailyClimatology_log_${date}"
	echo "${CAMS43AlertHome}/MakeDailyClimatology.sh started at ${date}"
	echo "logfile at ${logfile}" 
	echo "started at ${date}" > "${logfile}"
	${CAMS43AlertHome}/MakeDailyClimatology.sh &>>${logfile}
	date=`date +%Y%m%d%H%M%S`
	echo "ended at ${date}" >> "${logfile}"
fi

#data file creation
if [ ${StartCreateYearlyFileFlag} -gt 0 ]
	then
	echo "building daily data files..."
	date=`date +%Y%m%d%H%M%S`
	logfile="${FCModelPath}log/CreateYearlyFile_log_${date}"
	echo "${CAMS43AlertHome}/CreateYearlyFile.sh started at ${date}"
	echo "logfile at ${logfile}" 
	echo "started at ${date}" > "${logfile}"
	${CAMS43AlertHome}/Parallel_CreateYearlyFile.sh &>>${logfile}
	#${CAMS43AlertHome}/CreateYearlyFile.sh &>>${logfile}
	date=`date +%Y%m%d%H%M%S`
	echo "ended at ${date}" >> "${logfile}"
fi

#calculate the variable alert_aer
if [ ${StartCalculateAlertFlag} -gt 0 ]
	then
	date=`date +%Y%m%d%H%M%S`
	logfile="${FCModelPath}log/CalculateAlert_log_${date}"
	echo "${CAMS43AlertHome}/CalculateAlert.sh started at ${date}"
	echo "logfile at ${logfile}" 
	echo "started at ${date}" > "${logfile}"
	${CAMS43AlertHome}/CalculateAlert.sh &>>${logfile}
	date=`date +%Y%m%d%H%M%S`
	echo "ended at ${date}" >> "${logfile}"
fi

wait

#start the aerocom-tools for plotting
if [ ${StartAerocomToolsFlag} -gt 0 ]
	then
	#use the automation tools to start plotting
	module add aerocom-IDL/8.5.1
	module add aerocom/anaconda3-stable
	/home/jang/bin/aerocom-tool-automation.py --modelyear ${StartYear} -v --forecast -v ${Model}
fi

IFS=$SAVEIFS
