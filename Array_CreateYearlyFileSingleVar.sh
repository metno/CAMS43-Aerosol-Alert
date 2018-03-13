#!/bin/bash
#shell script to create text files with commands to run
#for the usage with gnu parallel
#
#as basis the files found in ${InterpolateOutDir} are used
#wich have been inperpolated to a common grid
#
#The output is the a yearly file for each variable

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

if [ $# -lt 2 ]
	then echo "usage: ${0} <AerocomVar> <MaccVar>"
	exit 1
fi

AerocomVar=${1}
MaccVar=${2}

####################################################################

function WaitForFile {
	#wait up to 10 seconds for a file to appear
	(( counter=0 ))
	WaitFile="${1}"
	while [ ! -f "${WaitFile}" ]
		do echo "waiting for ${WaitFile} to appear ${counter}"
		sleep 1
		(( counter+=1 ))
		if [ $counter -gt 10 ]
			then return 1
		fi
	done
	return 0
}

#####################################################################

function WaitForFileUndef {
	MaxWait=3600
	#wait up to 10 seconds for a file to appear
	(( counter=0 ))
	WaitFile="${1}"
	while [ ! -f "${WaitFile}" ]
		do echo "waiting for ${WaitFile} to appear ${counter}"
		sleep 1
		(( counter+=1 ))
		if [ $counter -gt ${MaxWait} ]
			then return 1
		fi
	done
	return 0
}

#####################################################################

#load constants
set -x
echo ${CAMS43AlertHome}
if [ -z ${CAMS43AlertHome} ]
	then . /home/aerocom/bin/Constants.sh
else
	. "${CAMS43AlertHome}/Constants.sh"
fi
#honour $NSLOTS from GridEngine
if [ ! -z ${NSLOTS} ]
	then
	SlotsToUse=${NSLOTS}
fi
set +x
set -x
UUID=`uuidgen`
echo "PPID: $PPID"
QsubFile="${TempDir}/qsub_${MaccVar}_${StartYear}_${UUID}_${Hostname}.sh"
NcwaFile="${TempDir}/ncwa_${MaccVar}_${StartYear}_${UUID}_${Hostname}.run"
#NcwaFile="${TempDir}/ncwa_${MaccVar}_${StartYear}_$BASHPID.run"
NcecatFile="${TempDir}/ncecat_${MaccVar}_${StartYear}_${UUID}_${Hostname}.run"
rmfile="${TempDir}/remove_${MaccVar}_${StartYear}_${UUID}_${Hostname}.run"
cdoFile="${TempDir}/cdo_${MaccVar}_${StartYear}_${UUID}_${Hostname}.run"
ncksFile="${TempDir}/ncks_${MaccVar}_${StartYear}_${UUID}_${Hostname}.run"
ncattedFile="${TempDir}/ncatted_${MaccVar}_${StartYear}_${UUID}_${Hostname}.run"
ncap2File="${TempDir}/ncap2_${MaccVar}_${StartYear}_${UUID}_${Hostname}.run"
ncwaLateFile="${TempDir}/ncwa_late_${MaccVar}_${StartYear}_${UUID}_${Hostname}.run"
set +x

NCWA=`which ncwa`
NCECAT=`which ncecat`
CDO=`which cdo`
NCKS_=`which ncks`
NCATTED=`which ncatted`
NCAP2=`which ncap2`

SortTempFile="${TempDir}/sort_${UUID}.tmp"

rm -f ${NcwaFile} ${NcecatFile} ${rmfile} ${cdoFile} ${ncksFile} ${ncattedFile} ${ncap2File} ${ncwaLateFile}

#Fill ncwa.run and ncecat.run

#different stages to divide script in parts for testing
Stage1Flag=0
Stage2Flag=1
Stage3Flag=0
RemoveFlag=0

if [ ${Stage1Flag} -gt 0 ]
	then
	declare -a NcwaList NcecatList cdoList
	#for DayDirs in `find ${InterpolateOutDir} -mindepth 1 -maxdepth 1 -type d | grep -e ${StartYear} | grep  -v 12$ | sort`
	for DayDirs in `find ${InterpolateOutDir} -mindepth 1 -maxdepth 1 -type d | grep -e "${StartYear}010" | grep  -v 12$ | sort`
	#for DayDirs in `find ../test -mindepth 1 -maxdepth 1 -type d | grep -e ${StartYear} | grep  -v 12$ | sort`
		do echo ${DayDirs}
		FileDayString=`echo ${DayDirs} | rev | cut -d/ -f1 | rev | cut -c1-8`
		#put the whole forecast period in one file so that we can use cdo for daily mean calculation
		HourlyFile="${TempDir}/${FileDayString}_${MaccVar}_hourly.nc"
		DailyFile="${TempDir}/${FileDayString}_${MaccVar}_daily.nc"
		echo ${HourlyFile} >> "${rmfile}"
		echo ${DailyFile} >> "${rmfile}"
		#test if  ${DailyFile} exists. If yes, don't recreate it to save time
		#ERRORPRONE!
		if [[ ! -f ${DailyFile} ]]
			then
			DayFileArr=`find ${DayDirs}/ -name z_cams_c_*_${StartYear}*_fc_*_${MaccVar}.nc -print | sort`
			if [[ ! -n ${DayFileArr} ]]
				then echo "no files in directory ${DayDirs} found!"
				continue
			fi
			#for DayFile in `find ${DayDirs}/ -name z_cams_c_ecmf_${StartYear}*_${MaccVar}.nc | sort`
			for DayFile in ${DayFileArr[*]}
				do #echo ${DayFile}
				FileHour=`basename ${DayFile} | cut -d_ -f9`
				FileDayString=`basename ${DayFile} | cut -d_ -f5 | cut -c1-8`
				newfile="${TempDir}/${FileDayString}_${MaccVar}_${FileHour}.nc"
				echo ${newfile} >> "${rmfile}"
				#get rid of the time dimension and put the file in tempdir
				#echo "ncwa -7 -a time -O -o ${newfile} ${DayFile}" >> "${NcwaFile}"
				echo "$NCWA -7 -a time -O -o ${newfile} ${DayFile}" >> "${NcwaFile}"
				NcwaList+=("ncwa -7 -a time -O -o ${newfile} ${DayFile}")
			done
			#put the whole forecast period in one file so that we can use cdo for daily mean calculation
			#HourlyFile="${TempDir}/${FileDayString}_hourly.nc"
			#DailyFile="${TempDir}/${FileDayString}_daily.nc"
			#ncecat -O -u time -n 121,3,1 ${TempDir}/${FileDayString}_*.nc ${HourlyFile}
			#THERE MIGHT NOT ALWAYS BE 121 TIME STEPS TO WORK ON
			#MAYBE CONSIDER THAT?
			echo "ncecat -7 -O -u time -n 121,3,1 ${TempDir}/${FileDayString}_${MaccVar}_???.nc ${HourlyFile}" >> "${NcecatFile}"
			NcecatList+=("ncecat -7 -O -u time -n 121,3,1 ${TempDir}/${FileDayString}_${MaccVar}_???.nc ${HourlyFile}")
			#set +x
			#calculate daily mean using cdo
			echo "cdo -f nc4c -O daymean ${HourlyFile} ${DailyFile}" >> "${cdoFile}"
			cdoList+=("cdo -f nc4c -O daymean ${HourlyFile} ${DailyFile}")
		fi
	done
	#determine the number of lines of the job lists
	NcwaFileLineNo=`cat ${NcwaFile} | wc -l`
	NcecatFileLineNo=`cat ${NcecatFile} | wc -l`
	cdoFileLineNo=`cat ${cdoFile} | wc -l`
	#create script for a grid engine array job1
	#For some reason the following qsub file needs still needs to be started 
	#via qsub using some options

	#create the qsub file for the ncwa commands
	JOB_NAME_ncwa="ncwa.${UUID}"
cat <<EOF > "${QsubFile}"
${AerocomVar}.sh

#!/bin/bash
#$ -S /bin/bash
#$ -q ded-parallelx.q
##$ -t 1-${NcwaFileLineNo}
##$ -l h_rt=120:00:00
#$ -M jang@met.no
#$ -m e
##$ -l h_vmem=1G
#$ -wd ${CAMS43AlertHome}
#$ -N $JOB_NAME_ncwa
#$ -e ${CAMS43AlertHome}/ERR_ncwa_$JOB_NAME.$HOSTNAME.$SGE_TASK_ID.log

echo "Got \$NSLOTS slots for job \$SGE_TASK_ID."
export CAMS43AlertHome="/home/aerocom/lib/CAMS43-Aerosol-Alert/"
export RUN_BY_CRON="TRUE"
${CAMS43AlertHome}/Wrapper.sh ${NcwaFile} \$SGE_TASK_ID
EOF
	WaitForFile "${QsubFile}"
	chmod u+x "${QsubFile}"
	echo Starting qsub array job for ncwa...
	set -x
	qsub -S /bin/bash -cwd -q ded-parallelx.q -l h_vmem=2G -t 1-${NcwaFileLineNo} "${QsubFile}"
	set +x


	JOB_NAME_ncecat="ncecat.${UUID}"
	#create the qsub file for the ncecat commands
cat <<EOF > "${QsubFile}"
${AerocomVar}.sh

#!/bin/bash
#$ -S /bin/bash
#$ -q ded-parallelx.q
##$ -t 1-${NcecatFileLineNo}
##$ -l h_rt=120:00:00
##$ -M jang@met.no
##$ -m e
#$ -wd ${CAMS43AlertHome}
#$ -N $JOB_NAME_ncecat
#$ -e ${CAMS43AlertHome}/ERR_ncecat_$JOB_NAME.$HOSTNAME.$SGE_TASK_ID.txt

echo "Got \$NSLOTS slots for job \$SGE_TASK_ID."
export CAMS43AlertHome="/home/aerocom/lib/CAMS43-Aerosol-Alert/"
export RUN_BY_CRON="TRUE"
${CAMS43AlertHome}/Wrapper.sh ${NcecatFile} \$SGE_TASK_ID
EOF
	WaitForFile "${QsubFile}"
	chmod u+x "${QsubFile}"
	echo Starting qsub array job for ncecat...
	set -x
	qsub -S /bin/bash -hold_jid $JOB_NAME_ncwa -cwd -q ded-parallelx.q -l h_vmem=4G -t 1-${NcecatFileLineNo} "${QsubFile}"
	set +x


	WaitForFile "${cdoFile}"
	echo Starting qsub array job for cdo...
	JOB_NAME_cdo="cdo.${UUID}"
	#create the qsub file for the ncecat commands
cat <<EOF > "${QsubFile}"
${AerocomVar}.sh

#!/bin/bash
#$ -S /bin/bash
#$ -q ded-parallelx.q
##$ -t 1-${NcecatFileLineNo}
##$ -l h_rt=120:00:00
#$ -M jang@met.no
#$ -m e
#$ -wd ${CAMS43AlertHome}
#$ -N $JOB_NAME_cdo
#$ -e ${CAMS43AlertHome}/ERR_cdo_$JOB_NAME.$HOSTNAME.$SGE_TASK_ID.txt

echo "Got \$NSLOTS slots for job \$SGE_TASK_ID."
export CAMS43AlertHome="/home/aerocom/lib/CAMS43-Aerosol-Alert/"
export RUN_BY_CRON="TRUE"
${CAMS43AlertHome}/Wrapper.sh ${cdoFile} \$SGE_TASK_ID
EOF
	WaitForFile "${QsubFile}"
	chmod u+x "${QsubFile}"
	echo Starting qsub array job for cdo...
	set -x
	qsub -S /bin/bash -hold_jid $JOB_NAME_ncecat -cwd -q ded-parallelx.q -l h_vmem=2G -t 1-${cdoFileLineNo} "${QsubFile}"
	set +x

	unset NcwaList NcecatList cdoList
	
	#this has to go in a job that depends on the last cdo job!
	rm -f ${TempDir}/${StartYear}*_${MaccVar}_???.nc
	rm -f ${TempDir}/${StartYear}*_${MaccVar}_hourly.nc
fi

######################################################################

if [ ${Stage2Flag} -gt 0 ]
	then
	#at this point there's a 5 day forecast in each file named *_daily.nc
	#now create a yearly file
	#past days use the analysis for the first hour and 23 hours forecast data

	declare -a ncksList ncattedList ncap2List ncwaLateList
	for DayDirs in `find ${InterpolateOutDir} -mindepth 1 -maxdepth 1 -type d | grep -e ${StartYear} | grep  -v 12$ | sort`
	#for DayDirs in `find ${InterpolateOutDir} -mindepth 1 -maxdepth 1 -type d | grep -e "${StartYear}01" | grep  -v 12$ | sort`
	#for DayDirs in `find ../test -mindepth 1 -maxdepth 1 -type d | grep -e ${StartYear} | grep  -v 12$ | sort`
		do echo ${DayDirs}
		FileDayString=`echo ${DayDirs} | rev | cut -d/ -f1 | rev | cut -c1-8`
		#put the whole forecast period in one file so that we can use cdo for daily mean calculation
		DailyFile="${TempDir}/${FileDayString}_${MaccVar}_daily.nc"
		#now rip the DailyFile apart to make a yearly time series
		(( StartTimeStep=1 ))
		(( EndTimeStep=${StartTimeStep}+1 ))

		#FileTSNo=`ncks -m ${DailyFile} -v time | grep "time dimension 0" | cut -d, -f 2 | cut -d= -f2 | cut '-d ' -f2`
		FileTSNo=`${NCKS[*]} -m ${DailyFile} -v time | grep "time dimension 0" | cut -d, -f 2 | cut -d= -f2 | cut '-d ' -f2`
		#get the actual times from the netcdf file to avoid errors
		TimeString=`ncdump -v time -i -l 4096 ${DailyFile} | grep 'time = "'| sed -e 's/^ time = //g' -e 's/ ;$//g' -e 's/\", \"/,/g' -e 's/\"//g'`
		#echo ${TimeString}
		#the time string looks e.g. like this now: 
		#"2016-01-01T23,2016-01-02T23,2016-01-03T23,2016-01-04T23,2016-01-05T23,2016-01-06"
		#Please note that this has to be done each time since the logic of doing that only for the time steps needed
		#is not that easy to program (there's 6 days in each forecast)
		OldIFS=${IFS}
		IFS=","
		for c_Temp in ${TimeString}
			do echo ${c_Temp}
			datestring=`echo ${c_Temp} | cut -dT -f1`
			DOY=`date -d ${datestring} '+%j'`
			DayFile="${TempDir}/Day_${MaccVar}_${DOY}.nc"
			#ncks -4 -L 5 -F -O -d time,${StartTimeStep},${StartTimeStep} ${DailyFile} ${DayFile}
			echo "ncks -7 -F -O -d time,${StartTimeStep} ${DailyFile} ${DayFile}" >> "${ncksFile}"
			ncksList+=("ncks -7 -F -O -d time,${StartTimeStep} ${DailyFile} ${DayFile}")

			temp="units,time,o,c,days since ${StartYear}-1-1 0:0:0"
			echo "ncatted -O -a '${temp}' ${DayFile}" >> "${ncattedFile}"
			ncattedList+=("ncatted -O -a '${temp}' ${DayFile}")

			temp="time(:)=${DOY}-1"
			echo "ncap2 -7 -o ${DayFile} -O -s '${temp}' ${DayFile} " >> "${ncap2File}"
			ncap2List+=("ncap2 -7 -o ${DayFile} -O -s '${temp}' ${DayFile} ")

			#remove the time dimension created by cdo
			echo "ncwa -7 -a time -O -o ${DayFile} ${DayFile}" >> "${ncwaLateFile}"
			ncwaLateList+=("ncwa -7 -a time -O -o ${DayFile} ${DayFile}")

			(( StartTimeStep = ${StartTimeStep} + 1 ))
		done
		IFS=${OldIFS}
	done
	#sort the commands so to avoid working on the same file at the same time
	echo Submitting qsub array job for ncks...
	WaitForFile "${ncksFile}"
	sort "${ncksFile}" > "${SortTempFile}"
	WaitForFile "${SortTempFile}"
	mv "${SortTempFile}" "${ncksFile}"

	NcksFileLineNo=`cat ${ncksFile} | wc -l`
	JOB_NAME_ncks="ncks.${UUID}"
	#create the qsub file for the ncwa commands
cat <<EOF > "${QsubFile}"
${AerocomVar}.sh

#!/bin/bash
#$ -S /bin/bash
#$ -q ded-parallelx.q
##$ -t 1-${NcksFileLineNo}
##$ -l h_rt=120:00:00
##$ -M jang@met.no
##$ -m e
##$ -l h_vmem=1G
#$ -wd ${CAMS43AlertHome}
#$ -N $JOB_NAME_ncks
#$ -e ${CAMS43AlertHome}/ERR_ncks_$JOB_NAME.$HOSTNAME.$SGE_TASK_ID.log

echo "Got \$NSLOTS slots for job \$SGE_TASK_ID."
export CAMS43AlertHome="/home/aerocom/lib/CAMS43-Aerosol-Alert/"
export RUN_BY_CRON="TRUE"
${CAMS43AlertHome}/Wrapper.sh ${ncksFile} \$SGE_TASK_ID
EOF
	WaitForFile "${QsubFile}"
	chmod u+x "${QsubFile}"
	echo Starting qsub array job for ncks...
	set -x
	qsub -S /bin/bash -cwd -q ded-parallelx.q -l h_vmem=2G -t 1-${NcksFileLineNo} "${QsubFile}"
	set +x
	#/usr/bin/parallel -vk -j ${SlotsToUse} -a "${ncksFile}"
##################################################################################

	#remove duplicates in the command list to save time
	echo submitting array job for ncatted...
	WaitForFile "${ncattedFile}"
	sort -u "${ncattedFile}" > "${SortTempFile}"
	WaitForFile "${SortTempFile}"
	mv "${SortTempFile}" "${ncattedFile}"
	NcattedFileLineNo=`cat ${ncattedFile} | wc -l`
	JOB_NAME_ncatted="ncatted.${UUID}"

	#create the qsub file for the ncatted commands
cat <<EOF > "${QsubFile}"
${AerocomVar}.sh

#!/bin/bash
#$ -S /bin/bash
#$ -q ded-parallelx.q
##$ -t 1-${NcattedFileLineNo}
##$ -l h_rt=120:00:00
##$ -M jang@met.no
##$ -m e
##$ -l h_vmem=1G
#$ -wd ${CAMS43AlertHome}
#$ -N $JOB_NAME_ncatted
#$ -e ${CAMS43AlertHome}/ERR_ncatted_$JOB_NAME.$HOSTNAME.$SGE_TASK_ID.log

echo "Got \$NSLOTS slots for job \$SGE_TASK_ID."
export CAMS43AlertHome="/home/aerocom/lib/CAMS43-Aerosol-Alert/"
export RUN_BY_CRON="TRUE"
${CAMS43AlertHome}/Wrapper.sh ${ncattedFile} \$SGE_TASK_ID
EOF
	WaitForFile "${QsubFile}"
	chmod u+x "${QsubFile}"
	echo Starting qsub array job for ncatted...
	set -x
	qsub -S /bin/bash -hold_jid $JOB_NAME_ncks -cwd -q ded-parallelx.q -l h_vmem=2G -t 1-${NcattedFileLineNo} "${QsubFile}"
	set +x

##################################################################################

	echo Starting qsub array job for ncap2...
	WaitForFile "${ncap2File}"
	sort -u "${ncap2File}" > "${SortTempFile}"
	WaitForFile "${SortTempFile}"
	mv "${SortTempFile}" "${ncap2File}"
	ncap2FileLineNo=`cat ${ncap2File} | wc -l`
	JOB_NAME_ncap2="ncap2.${UUID}"
	#create the qsub file for the ncatted commands
cat <<EOF > "${QsubFile}"
${AerocomVar}.sh

#!/bin/bash
#$ -S /bin/bash
#$ -q ded-parallelx.q
##$ -t 1-${ncap2FileLineNo}
##$ -l h_rt=120:00:00
##$ -M jang@met.no
##$ -m e
##$ -l h_vmem=1G
#$ -wd ${CAMS43AlertHome}
#$ -N $JOB_NAME_ncap2
#$ -e ${CAMS43AlertHome}/ERR_ncap2_$JOB_NAME.$HOSTNAME.$SGE_TASK_ID.log

echo "Got \$NSLOTS slots for job \$SGE_TASK_ID."
export CAMS43AlertHome="/home/aerocom/lib/CAMS43-Aerosol-Alert/"
export RUN_BY_CRON="TRUE"
${CAMS43AlertHome}/Wrapper.sh ${ncap2File} \$SGE_TASK_ID
EOF
	WaitForFile "${QsubFile}"
	chmod u+x "${QsubFile}"
	echo Starting qsub array job for ncap2...
	set -x
	qsub -S /bin/bash -hold_jid $JOB_NAME_ncatted -cwd -q ded-parallelx.q -l h_vmem=2G -t 1-${ncap2FileLineNo} "${QsubFile}"
	set +x
##################################################################################


	echo Starting qsub array job for ncwa late...
	WaitForFile "${ncwaLateFile}"
	sort -u "${ncwaLateFile}" > "${SortTempFile}"
	WaitForFile "${SortTempFile}"
	mv "${SortTempFile}" "${ncwaLateFile}"
	NcwaLateFileLineNo=`cat ${ncwaLateFile} | wc -l`
	JOB_NAME_ncwaLate="ncwaLate.${UUID}"
	#create the qsub file for the ncatted commands
cat <<EOF > "${QsubFile}"
${AerocomVar}.sh

#!/bin/bash
#$ -S /bin/bash
#$ -q ded-parallelx.q
##$ -t 1-${NcwaLateFileLineNo}
##$ -l h_rt=120:00:00
##$ -M jang@met.no
##$ -m e
##$ -l h_vmem=1G
#$ -wd ${CAMS43AlertHome}
#$ -N $JOB_NAME_ncwaLate
#$ -e ${CAMS43AlertHome}/ERR_ncwaLate_$JOB_NAME.$HOSTNAME.$SGE_TASK_ID.log

echo "Got \$NSLOTS slots for job \$SGE_TASK_ID."
export CAMS43AlertHome="/home/aerocom/lib/CAMS43-Aerosol-Alert/"
export RUN_BY_CRON="TRUE"
${CAMS43AlertHome}/Wrapper.sh ${ncwaLateFile} \$SGE_TASK_ID
EOF
	WaitForFile "${QsubFile}"
	chmod u+x "${QsubFile}"
	echo Starting qsub array job for ncwa late...
	set -x
	qsub -S /bin/bash -hold_jid $JOB_NAME_ncap2 -cwd -q ded-parallelx.q -l h_vmem=2G -t 1-${NcwaLateFileLineNo} "${QsubFile}"
	set +x

	unset  ncksList ncattedList ncap2List ncwaLateList
fi

if [ ${Stage3Flag} -gt 0 ] 
	then	

	#Now fill the gaps with a prototype containing only NaNs
	#Create prototype
	echo "Preparing prototype to be used for non existing days..."
	#OrigDir=`pwd`
	cd "${TempDir}"
	prototype="prototype_${MaccVar}.nc"
	DayFile=`find -type f -name "Day_${MaccVar}*.nc" | head -n1`
	
	cp ${DayFile} ${prototype}
	#determine Fillvalue
	#FillValue=`ncks -m -v ${MaccVar} ${prototype} | grep ${MaccVar} | grep _FillValue | cut '-d ' -f 11`
	FillValue=`${NCKS[*]} -m -v ${MaccVar} ${prototype} | grep ${MaccVar} | grep _FillValue | cut '-d ' -f 11`
	#temp="${MaccVar}(:,:)=${FillValue}"
	#temp="${MaccVar}(:,:)=0./0."
	temp="${MaccVar}(:,:)=nan"
	set -x
	ncap2 -7 -o ${prototype} -O -s "${temp}" ${prototype}
	if [ $? -ne 0 ]
		then exit 1
	fi
	set +x

	#fill the gaps with the Prototype and the right time value
	for ((i=1; i <=i_DayNo; i += 1))
		do	c_OutFileNo=`printf "%05d" ${i}`
		c_InFileNo=`printf "%03d" ${i}`
		InFile="Day_${MaccVar}_${c_InFileNo}.nc"
		OutFile="TS_${MaccVar}_${c_OutFileNo}.nc"
		if [ ! -f "${InFile}" ]
			then 
			#cp ${prototype} ${OutFile}
			temp="time=${i}-1"
			set -x
			ncap2 -7 -o ${OutFile} -O -s "${temp}" ${prototype}
			if [ $? -ne 0 ]
				then exit 1
			fi
			set +x
		else 
			set -x
			ln -sf ${InFile} ${OutFile}
			set +x
		fi
	done
	cd "${RenamedDir}"

	#concatenate to yearly file
	set -x
	OutFile="${TempDir}/${Start}.${Model}.daily.${AerocomVar}.${StartYear}.nc"
	StartFile="${TempDir}/TS_${MaccVar}_00001.nc"
	ncecat -7 -x -v time_bnds -O -u time -n ${i_DayNo},5,1 ${StartFile} ${OutFile}
	if [ $? -ne 0 ]
		then exit 1
	fi
	#until netcdf version 4.3.3.1 (March, 2015) the following will strip the attributes from the coordinate vars due to a netcdf library bug
	#the workaround is to convert to netcdf3 rename and then convert back

	#ncrename -O -v ${MaccVar},${AerocomVar} -v latitude,lat -v longitude,lon -d latitude,lat -d longitude,lon ${OutFile}
	ncrename -O -v ${MaccVar},${AerocomVar} ${OutFile}

	#ncks -7 -L 5 -O ${OutFile} ${OutFile}
	#ncks -O --exclude -v time_bnds ${OutFile} ${OutFile}
	#if [ $? -ne 0 ]
		#then exit 1
	#fi
	#set +x
	mv "${OutFile}" "${RenamedDir}"

fi

#################################################################################################

if [ ${RemoveFlag} -gt 0 ]
	then
	rm -f ${TempDir}/TS_${MaccVar}*.nc 
	rm -f ${TempDir}/Day_${MaccVar}*.nc 
	rm -f ${TempDir}/${prototype} 
	rm -f ${TempDir}/${StartYear}*_${MaccVar}_???.nc
	rm -f ${TempDir}/${StartYear}*_${MaccVar}_daily.nc
	rm -f ${NcwaFile} ${NcecatFile} ${rmfile} ${cdoFile} ${ncksFile} ${ncattedFile} ${ncap2File} ${ncwaLateFile} ${SortTempFile}
fi	

date=`date`
echo "$*" finished at ${date}

IFS=$SAVEIFS
exit 0
