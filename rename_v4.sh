#!/bin/bash
#shell script create the data files needed for the CAMS83
#aerosol alert system
#
#as basis the files found in ${InterpolateOutDir} are used
#wich have been inperpolated to a common grid
#
#The output is the a yearly file for each variable

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

source /home/aerocom/bin/ForecastConstants.sh

#set -x

for ModelVar in ${varlist[*]}
	do AerocomVar=`echo ${ModelVar} | cut -d= -f1`
	MaccVar=`echo ${ModelVar} | cut -d= -f2`

	if true ; then
	#find dates
	for DayDirs in `find ${InterpolateOutDir} -mindepth 1 -maxdepth 1 -type d | grep -e ${StartYear} | grep  -v 12$ | sort`
	#for DayDirs in `find ${InterpolateOutDir} -mindepth 1 -maxdepth 1 -type d | grep -e "${StartYear}0826" | grep  -v 12$ | sort`
	#for DayDirs in `find ../test -mindepth 1 -maxdepth 1 -type d | grep -e ${StartYear} | grep  -v 12$ | sort`
		do echo ${DayDirs}
		FileDayString=`echo ${DayDirs} | rev | cut -d/ -f1 | rev | cut -c1-8`
		#put the whole forecast period in one file so that we can use cdo for daily mean calculation
		HourlyFile="${TempDir}/${FileDayString}_${MaccVar}_hourly.nc"
		DailyFile="${TempDir}/${FileDayString}_${MaccVar}_daily.nc"
		#test if  ${DailyFile} exists. If yes, don't recreate it to save time
		#ERRORPRONE!
		if [[ ! -f ${DailyFile} ]]
			then
			DayFileArr=`find ${DayDirs}/ -name z_cams_c_ecmf_${StartYear}*_${MaccVar}.nc -print | sort`
			if [[ ! -n ${DayFileArr} ]]
				then echo "no files in directory ${DayDirs} found!"
				continue
			fi
			#for DayFile in `find ${DayDirs}/ -name z_cams_c_ecmf_${StartYear}*_${MaccVar}.nc | sort`
			for DayFile in ${DayFileArr[*]}
				do echo ${DayFile}
				FileHour=`basename ${DayFile} | cut -d_ -f9`
				FileDayString=`basename ${DayFile} | cut -d_ -f5 | cut -c1-8`
				newfile="${TempDir}/${FileDayString}_${MaccVar}_${FileHour}.nc"
				#get rid of the time dimension and put the file in tempdir
				ncwa -7 -a time -O -o ${newfile} ${DayFile} &
			done
			#put the whole forecast period in one file so that we can use cdo for daily mean calculation
			#HourlyFile="${TempDir}/${FileDayString}_hourly.nc"
			#DailyFile="${TempDir}/${FileDayString}_daily.nc"
			#wait for all subprocesses to finish
			wait 
			#ncecat -O -u time -n 121,3,1 ${TempDir}/${FileDayString}_*.nc ${HourlyFile}
			#THERE MIGHT NOT ALWAYS BE 121 TIME STEPS TO WORK ON
			#MAYBE CONSIDER THAT?
			ncecat -h -7 -O -u time -n 121,3,1 ${TempDir}/${FileDayString}_${MaccVar}_???.nc ${HourlyFile}
			if [ $? -ne 0 ]
				then exit 1
			fi
			#set +x
			#get rid of the temp files
			rm -f ${TempDir}/${FileDayString}_${MaccVar}_???.nc
			#calculate daily mean using cdo
			cdo -f nc4c -O daymean ${HourlyFile} ${DailyFile}
			if [ $? -ne 0 ]
				then exit 1
			fi
			rm -f ${HourlyFile}
		fi
		#now rip the file apart to make a yearly time series
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
		#is not thatt easy to program (there's 6 days in each forecast)
		OldIFS=${IFS}
		IFS=","
		for c_Temp in ${TimeString}
			do echo ${c_Temp}
			datestring=`echo ${c_Temp} | cut -dT -f1`
			DOY=`date -d ${datestring} '+%j'`
			DayFile="${TempDir}/Day_${MaccVar}_${DOY}.nc"
			#ncks -4 -L 5 -F -O -d time,${StartTimeStep},${StartTimeStep} ${DailyFile} ${DayFile}
			ncks -7 -F -O -d time,${StartTimeStep} ${DailyFile} ${DayFile}
			if [ $? -ne 0 ]
				then exit 1
			fi
			temp="units,time,o,c,days since ${StartYear}-1-1 0:0:0"
			ncatted -O -a "${temp}" ${DayFile}
			if [ $? -ne 0 ]
				then exit 1
			fi
			temp="time(:)=${DOY}-1"
			ncap2 -7 -o ${DayFile} -O -s "${temp}" ${DayFile} 
			if [ $? -ne 0 ]
				then exit 1
			fi
			#remove the time dimension created by cdo
			ncwa -7 -a time -O -o ${DayFile} ${DayFile} &
			if [ $? -ne 0 ]
				then exit 1
			fi
			(( StartTimeStep = ${StartTimeStep} + 1 ))
		done
		IFS=${OldIFS}
	done
	wait
	fi

	if true ; then	#block switched off for debugging

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
	temp="${MaccVar}(:,:)=0./0."
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
	#ncecat -4 -L 5 -O -u time -n ${i_DayNo},5,1 ${StartFile} ${OutFile}
	ncecat -7 -O -u time -n ${i_DayNo},5,1 ${StartFile} ${OutFile}
	if [ $? -ne 0 ]
		then exit 1
	fi
	#until netcdf version 4.3.3.1 (March, 2015) the following will strip the attributes from the coordinate vars due to a netcdf library bug
	#the workaround is to convert to netcdf3 rename and then convert back

	#ncrename -O -v ${MaccVar},${AerocomVar} -v latitude,lat -v longitude,lon -d latitude,lat -d longitude,lon ${OutFile}
	ncrename -O -v ${MaccVar},${AerocomVar} ${OutFile}

	ncks -7 -L 5 -O ${OutFile} ${OutFile}
	if [ $? -ne 0 ]
		then exit 1
	fi
	set +x
	#rm -f TS_*.nc Day_*.nc ${prototype} ${TempDir}/*.nc
	rm -f "${TempDir}/TS_${MaccVar}*.nc" "${TempDir}/Day_${MaccVar}*.nc" "${prototype}" 
	
	fi	#block switched off for debugging
done	#variable loop

set -x
cd "${TempDir}"
#now recalculate od550aer as the sum of Dust+SO4+POM+BC
#Put the vars in one file...
vars=(
'od550dust'
'od550so4'
'od550oa'
'od550bc'
)
AerocomVar='od550aer'
for NewVar in ${vars[*]}
	do InFile="${Start}.${Model}.daily.${NewVar}.${StartYear}.nc"
	OutFile="${Start}.${Model}.daily.${AerocomVar}.${StartYear}.nc"
	set -x
	ncks -7 -o ${OutFile} -A -v ${NewVar} ${InFile}
	if [ $? -ne 0 ]
		then exit 1
	fi
done
temp="${AerocomVar}(:,:,:)=od550dust+od550so4+od550oa+od550bc"
ncap2 -7 -L 5 -o ${OutFile} -O -s "${temp}" ${OutFile}
if [ $? -ne 0 ]
	then exit 1
fi
set +x

#exit

#and od550pollution as SO4+POM+BC

#now calculate od550pollution as the sum of SO4+POM+BC
#Put the vars in one file...
vars=(
'od550so4'
'od550oa'
'od550bc'
)
AerocomVar='od550pollution'
NewVar=${vars[0]}
OutFile="${Start}.${Model}.daily.${AerocomVar}.${StartYear}.nc"
set -x
rm -f ${OutFile}
InFile="${Start}.${Model}.daily.${NewVar}.${StartYear}.nc"
ncks -7 -L 5 -o ${OutFile} -A -v ${NewVar} ${InFile}
if [ $? -ne 0 ]
	then exit 1
fi
ncrename -O -v ${NewVar},${AerocomVar} ${OutFile}
for NewVar in ${vars[*]}
	do InFile="${Start}.${Model}.daily.${NewVar}.${StartYear}.nc"
	OutFile="${Start}.${Model}.daily.${AerocomVar}.${StartYear}.nc"
	ncks -o ${OutFile} -A -v ${NewVar} ${InFile}
done
temp="${AerocomVar}(:,:,:)=od550so4+od550oa+od550bc"
ncap2 -7 -L 5 -o ${OutFile} -O -s "${AerocomVar}(:,:,:)=od550so4+od550oa+od550bc" ${OutFile}
if [ $? -ne 0 ]
	then exit 1
fi
set +x
mv ${Start}.*.nc "${RenamedDir}"
cd "${RenamedDir}"


IFS=$SAVEIFS

