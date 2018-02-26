#!/bin/bash
#shell script to convert the monthly climatology into a daily one

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

#load constants
set -x
echo ${CAMS43AlertHome}
if [ -z ${CAMS43AlertHome} ]
	then . /home/aerocom/bin/ForecastConstants.sh
else
	. "${CAMS43AlertHome}/ForecastConstants.sh"
fi
set +x

for ModelVar in ${varlist[*]}
	do AerocomVar=`echo ${ModelVar} | cut -d= -f1`
	MaccVar=`echo ${ModelVar} | cut -d= -f2`
	#ClimFile="/metno/aerocom/work/aerocom1/ECMWF_FBOV/renamed/ECMWF_FBOV.monthly.${AerocomVar}.9999.nc"
	ClimFile="${ClimModel}.monthly.${AerocomVar}.${ClimYear}.nc"
	InFile="${ClimRenamedDir}${ClimFile}"
	ClimFile="${TempDir}${ClimFile}"
	set -x
	#cdo -f nc4 -O -z zip remapdis,${GridFile} ${InFile} ${ClimFile}
	cdo -f nc4c -O remapdis,${GridFile} ${InFile} ${ClimFile}
	if [ $? -ne 0 ]
		then exit 1
	fi
	set +x
	#determine # of time steps in climatology file
	MaxTsNo=`${NCKS[*]} -m -v ${AerocomVar} ${ClimFile} | grep ${AerocomVar}| grep dimension | grep time | cut -d, -f2 | cut '-d ' -f4`
	if [ ${MaxTsNo} -gt 12 ]
		then echo "ERROR: so far this script can only cope with monthly climatologies. Exiting now..."
		exit
	else
		#rip the file apart
		i_DayNo=1
		for (( i_MNo=1; i_MNo <= ${MaxTsNo}; i_MNo += 1 ))
			do	
			c_MNo=`printf "%02d" ${i_MNo}`
			tempfile="${TempDir}ClimTemp_${c_MNo}.nc"
			ncks -7 -F -O -d time,${i_MNo} ${ClimFile} ${tempfile}
			if [ $? -ne 0 ]
				then exit 1
			fi
			#get rid of the time dimension
			ncwa -a time -O -o ${tempfile} ${tempfile} & 
			#make links to create a daily file 
			for (( i_DoMNo=1; i_DoMNo <= ${MonthLengths[${i_MNo}-1]} ; i_DoMNo += 1 ))
				do
				#echo ${i_DoMNo}
				c_DNo=`printf "%03d" ${i_DayNo}`
				OutFile="${TempDir}ClimDaily_${c_DNo}.nc"
				ln -sf ${tempfile} ${OutFile}
				(( i_DayNo += 1 ))
			done
		done
	fi

	#now build the yearly file of daily 
	StartFile="${TempDir}ClimDaily_001.nc"
	#OutFile="${Start}.${Model}.daily.${AerocomVar}.${ClimYear}.nc"
	#OutFile=`basename ${ClimFile} | sed -e 's/monthly/daily/g'`
	OutFile=`echo ${ClimFile} | sed -e 's/monthly/daily/g'`
	wait
	#ncecat -3 -O -u time -n ${i_MaxDayNo},3,1 ${StartFile} ${OutFile}
	#echo ncecat -7 -O -u time -n ${i_MaxDayNo},3,1 ${StartFile} ${OutFile}
	set -x
	ncecat -7 -O -u time -n ${i_MaxDayNo},3,1 ${StartFile} ${OutFile}
	if [ $? -ne 0 ]
		then exit 1
	fi
	set +x

	rm -f ${TempDir}ClimTemp_??.nc
	rm -f ${TempDir}ClimDaily_???.nc
	rm -f ${ClimFile}
	mv "${OutFile}" "${RenamedDir}"

done	# variable loop

#Now create a climatology for od550pollution consisting of the sum of SO4, OA and BC
#now calculate od550pollution as the sum of Dust+SO4+POM+BC
#Put the vars in one file...
vars=(
'od550so4'
'od550oa'
'od550bc'
)
set -x
NewVar=${AerocomVar}
AerocomVar='od550pollution'
InFile=${OutFile}
#OutFile="${Start}.${ClimModel}.daily.${AerocomVar}.${ClimYear}.nc"
OutFile="${TempDir}${ClimModel}.daily.${AerocomVar}.${ClimYear}.nc"
rm -f ${OutFile}
for NewVar in ${vars[*]}
	#do InFile="${Start}.${ClimModel}.daily.${NewVar}.${ClimYear}.nc"
	do InFile="${RenamedDir}${ClimModel}.daily.${NewVar}.${ClimYear}.nc"
	#OutFile="${TempDir}${ClimModel}.daily.${AerocomVar}.${ClimYear}.nc"
	#ncks -3 -o ${OutFile} -A -v ${NewVar} ${InFile} 
	ncks -7 -o ${OutFile} -A -v ${NewVar} ${InFile} 
	if [ $? -ne 0 ]
		then exit 1
	fi
done
ncap2 -7 -o ${OutFile} -O -s "${AerocomVar}=od550so4+od550oa+od550bc" ${OutFile}
if [ $? -ne 0 ]
	then exit 1
fi
mv "${OutFile}" "${RenamedDir}"

#now substract od550ss from od550aer to get rid of sea salt

vars=(
'od550ss'
)
NewVar=${vars[0]} #od550aer
AerocomVar='od550aer'
InFile="${RenamedDir}${ClimModel}.daily.${AerocomVar}.${ClimYear}.nc"
#OutFile="${Start}.${ClimModel}.daily.${AerocomVar}.${ClimYear}.nc"
OutFile="${TempDir}${ClimModel}.daily.${AerocomVar}.${ClimYear}.nc"

cp ${InFile} ${OutFile}
for NewVar in ${vars[*]}
	do InFile="${RenamedDir}${ClimModel}.daily.${NewVar}.${ClimYear}.nc"
	#OutFile="${TempDir}${ClimModel}.daily.${AerocomVar}.${ClimYear}.nc"
	ncks -7 -o ${OutFile} -A -v ${NewVar} ${InFile}
done
ncap2 -7 -o ${OutFile} -O -s "${AerocomVar}=od550aer-od550ss" ${OutFile}
mv "${OutFile}" "${RenamedDir}"

set +x
IFS=$SAVEIFS

