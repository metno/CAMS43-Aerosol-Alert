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
Stage1Flag=1
Stage2Flag=1
Stage3Flag=1
RemoveFlag=1

if [ ${Stage1Flag} -gt 0 ]
	then
	declare -a NcwaList NcecatList cdoList
	for DayDirs in `find ${InterpolateOutDir} -mindepth 1 -maxdepth 1 -type d | grep -e ${StartYear} | grep  -v 12$ | sort`
	#for DayDirs in `find ${InterpolateOutDir} -mindepth 1 -maxdepth 1 -type d | grep -e "${StartYear}010[1-2]" | grep  -v 12$ | sort`
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
				echo "ncwa -7 -a time -O -o ${newfile} ${DayFile}" >> "${NcwaFile}"
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

	set -x
	WaitForFile "${NcwaFile}"
	echo Starting parallel for ncwa...
	/usr/bin/parallel --version
	#printf "%s\n" "${NcwaList[@]}" | /usr/bin/parallel --verbose -j ${SlotsToUse}
	/usr/bin/parallel -vk -j ${SlotsToUse} -a "${NcwaFile}"
	set +x
	wait

	WaitForFile "${NcecatFile}"
	echo Starting parallel for ncecat...
	#printf "%s\n" "${NcecatList[@]}" | parallel -j ${SlotsToUse} -v
	/usr/bin/parallel -vk -j ${SlotsToUse} -a "${NcecatFile}"
	wait

	WaitForFile "${cdoFile}"
	echo Starting parallel for cdo...
	#printf "%s\n" "${cdoList[@]}" | parallel -j ${SlotsToUse} -v
	#/usr/bin/parallel --verbose -j ${SlotsToUse} < "${cdoFile}"
	/usr/bin/parallel -vk -j ${SlotsToUse} -a "${cdoFile}"
	wait

	unset NcwaList NcecatList cdoList

	rm -f ${TempDir}/${StartYear}*_${MaccVar}_???.nc
	rm -f ${TempDir}/${StartYear}*_${MaccVar}_hourly.nc
fi

######################################################################

if [ ${Stage2Flag} -gt 0 ]
	then
	declare -a ncksList ncattedList ncap2List ncwaLateList
	for DayDirs in `find ${InterpolateOutDir} -mindepth 1 -maxdepth 1 -type d | grep -e ${StartYear} | grep  -v 12$ | sort`
	#for DayDirs in `find ${InterpolateOutDir} -mindepth 1 -maxdepth 1 -type d | grep -e "${StartYear}0101" | grep  -v 12$ | sort`
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
	echo Starting parallel for ncks...
	WaitForFile "${ncksFile}"
	sort "${ncksFile}" > "${SortTempFile}"
	WaitForFile "${SortTempFile}"
	/usr/bin/parallel -vk -j ${SlotsToUse} -a "${SortTempFile}"
	#SAVEIFS=$IFS
	#IFS=$'\n' ncksList=($(sort <<<"${ncksList[*]}"))
	#IFS=$SAVEIFS
	#( printf "%s\n" "${ncksList[@]}" | parallel -j ${SlotsToUse} -v ; wait )
	wait

	#remove duplicates in the command list to save time
	echo Starting parallel for ncatted...
	WaitForFile "${ncattedFile}"
	sort -u "${ncattedFile}" > "${SortTempFile}"
	WaitForFile "${SortTempFile}"
	/usr/bin/parallel -vk -j ${SlotsToUse} -a "${SortTempFile}"
	#SAVEIFS=$IFS
	#IFS=$'\n' ncattedList=($(sort -u <<<"${ncattedList[*]}"))
	#IFS=$SAVEIFS
	#( printf "%s\n" "${ncattedList[@]}" | parallel -j ${SlotsToUse} -v ; wait )
	wait

	echo Starting parallel for ncap2...
	WaitForFile "${ncap2File}"
	sort -u "${ncap2File}" > "${SortTempFile}"
	WaitForFile "${SortTempFile}"
	/usr/bin/parallel -vk -j ${SlotsToUse} -a "${SortTempFile}"
	#SAVEIFS=$IFS
	#IFS=$'\n' ncap2List=($(sort -u <<<"${ncap2List[*]}"))
	#IFS=$SAVEIFS
	#( printf "%s\n" "${ncap2List[@]}" | parallel -j ${SlotsToUse} -v ; wait )
	wait

	echo Starting parallel for ncwa...
	WaitForFile "${ncwaLateFile}"
	sort -u "${ncwaLateFile}" > "${SortTempFile}"
	WaitForFile "${SortTempFile}"
	/usr/bin/parallel -vk -j ${SlotsToUse} -a "${SortTempFile}"
	#SAVEIFS=$IFS
	#IFS=$'\n' ncwaLateList=($(sort -u <<<"${ncwaLateList[*]}"))
	#IFS=$SAVEIFS
	#( printf "%s\n" "${ncwaLateList[@]}" | parallel -j ${SlotsToUse} -v ; wait )
	wait
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
