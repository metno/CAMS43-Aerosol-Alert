#!/bin/bash

#check if the script is run by cron
#you need to set the RUN_BY_CRON environment variable
if [ -n ${RUN_BY_CRON} ]
	then
	PATH="/home/jang/anaconda3/bin/:${PATH}:/home/jang/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
fi

#of jobs to run in parallel at max
#e.g. for ncwa loops
MaxParallelStarts=10

CredentialFile='FtpCredentials.sh'
if [ -f ${CredentialFile} ]
	then . "${CredentialFile}"
else
	echo "Warning: Credential file ${CredentialFile} not found. You might not be able to download ftp data."
fi
Model='ECMWF_OSUITE_NRT'
#for testing
Model='ECMWF_OSUITE_NRT_test'
ClimModel='ECMWF_FBOV'
#used for testing

#This is a list where each element is a variable to be worked on
# the notation is
# <aerocom variable name>=<ECMWF variable name>=<alert variable name> or 'NotNeeded'
# THE FIRST VARIABLE HAS TO BE od550aer!
varlist=(
'od550aer=aod550=alertaer'
'od550dust=duaod550=alertdust'
'od550ss=ssaod550=NotNeeded'
'od550oa=omaod550=NotNeeded'
'od550bc=bcaod550=NotNeeded'
'od550so4=suaod550=NotNeeded'
)

#Some directories
#base dir that denotes the model name and where the data preparation scripts are
#BasePath="/lustre/storeB/project/aerocom/"
BasePath="/lustre/storeA/project/aerocom/"
#ClimPath="${BasePath}/htap/ECMWF/${ClimModel}/"

#Path of the climatology model
ClimPath="${BasePath}/aerocom-users-database/ECMWF/${ClimModel}/"
ClimRenamedDir="${ClimPath}/renamed/"
#path of the forecast model
FCModelPath="${BasePath}aerocom1/${Model}/"

#Data directory
#By convention the model data resides in a directory named 'renamed'
RenamedDir="${FCModelPath}renamed/"

#for backward compatibility
aerocom1="${FCModelPath}"

#directory to download the files from ECMWF to
DownloadDir="${FCModelPath}download/"

#for compatibility
InterpolateInDir="${DownloadDir}"

#downloaded files are first unpacked (since the packing is different from 
#file to file and since nco would take the parameters from the first file), 
#then interpolated to common grid
#since the grid might change within a year
InterpolateOutDir="${FCModelPath}interpolated/"
UnpackOutDir="${FCModelPath}unpacked/"
#cdo grid file for the interpolation
GridFile='/home/aerocom/bin/griddef_CAMS84.txt'

#forecast operations are logged so that we can look in case of errors
LogDir="${FCModelPath}log/"

#directory for temporary files; will become >50GB data
TempDir="${FCModelPath}/renamed/tmp_test/"

#filename for file check errors
#will log downloaded netcdf files that have 0 length or that are not 
#working netcdf files
logdate=`date +%Y%m%d%H%M%S`
CheckDataErrorLogFile="${LogDir}CheckDataErrorLog_${logdate}.log"
CheckDataErrorDirs=(\
"${DownloadDir}" \
"${InterpolateOutDir}" \
)

Start='aerocom'
ClimYear=9999

#This is the year to work on
StartYear=`find ${DownloadDir} -mindepth 1 -maxdepth 1 -type d | grep -e '/20' | sort | tail -n1 | rev | cut '-d/' -f1 | rev | cut -c1-4`

#If you want to select the year manually, just use this:
StartYear='2017'


#This finction returns 1 if a given year is a leap year
#and 0 in case the given year is not a leap year
function isyearleapyear {
year=$1
if [ `expr ${year} % 400` -eq  0 ]
        then echo '1'
elif [ `expr ${year} % 100` -eq 0 ]
        then echo '0'
elif [ `expr ${year} % 4` -eq 0 ]
        then echo '1'
else
        echo '0'
fi }

#set this to 1 in case you want the unpacking to be done again. 
RedoUnpackFlag=0
#RedoUnpackFlag=1

#set this to 1 in case you need to redo the interpolation e.g. due to a newer grid
#RedoInterpolationFlag=1
RedoInterpolationFlag=0

#ncks since version 4.7 altered the output of the -m switch
#if you are still using an older version, please use this line
#NCKS='ncks'
NCKS=('ncks' '--trd')

#set some parameters depending on if we are working on a leap year
#or not
LeapYearFlag=`isyearleapyear ${StartYear}`
if [ ${LeapYearFlag} -eq 0 ] 
	then MonthLengths=(31 28 31 30 31 30 31 31 30 31 30 31)
	i_StartDay=(1 32 60 91 121 152 182 213 244 274 305 335)
	i_EndDay=(31 60 90 120 151 181 212 243 273 304 334 365)
	(( i_DayNo=365 ))
	(( i_MaxDayNo=365 ))
else MonthLengths=(31 29 31 30 31 30 31 31 30 31 30 31)
	i_StartDay=(1 32 61 92 122 153 183 214 245 275 306 336)
	i_EndDay=(31 60 91 121 152 182 213 244 274 305 335 366)
	(( i_DayNo=366 ))
	(( i_MaxDayNo=366 ))
fi

#The following flags are used to make swithing off of some parts
#possible for testing
StartDownloadFlag=0
StartDownloadFlag=1
#echo "PATH: ${PATH}"

