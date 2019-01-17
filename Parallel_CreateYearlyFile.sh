#!/bin/bash
#shell script create the data files needed for the CAMS83
#aerosol alert system
#It uses CreateYearlyFileSingleVar.sh to create all single variable files
#in parallel and creates the multivariable files then afterwards
#
#The output is the a yearly file for each variable

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

#load constants
#set -x
if [ -z ${CAMS43AlertHome} ]
	then . /home/aerocom/lib/CAMS43-Aerosol-Alert/Constants.sh
else
	. "${CAMS43AlertHome}/Constants.sh"
fi
set +x

LogFileName=`basename "${0}" .sh`

for ModelVar in ${varlist[*]}
	do AerocomVar=`echo ${ModelVar} | cut -d= -f1`
	#od550aer is caclulated from dust, so4 oa and bc later on, so omit that to save time
	if [[ $AerocomVar =~ "od550aer" ]]
		then continue
	fi
	MaccVar=`echo ${ModelVar} | cut -d= -f2`
	logdate=`date +%Y%m%d%H%M%S`
	logfile="${LogDir}${LogFileName}.${AerocomVar}_${logdate}"
	
	echo "${logdate}: starting yearly file creation for var ${AerocomVar}..."
	echo "${CAMS43AlertHome}/CreateYearlyFileSingleVar.sh" "${AerocomVar}" "${MaccVar}"
	echo "${logdate}: starting yearly file creation for var ${AerocomVar}..." >> ${logfile}
	echo "${CAMS43AlertHome}/CreateYearlyFileSingleVar.sh" "${AerocomVar}" "${MaccVar}" >> ${logfile}

	#${CAMS43AlertHome}/Parallel_CreateYearlyFileSingleVar.sh "${AerocomVar}" "${MaccVar}" >> ${logfile} 
	${CAMS43AlertHome}/Parallel_CreateYearlyFileSingleVar.sh "${AerocomVar}" "${MaccVar}" 
done	#variable loop
logdate=`date +%Y%m%d%H%M%S`
echo "${logdate}: waiting for all running CreateYearlyFileSingleVar.sh to finish."
wait

set -x
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
	do InFile="${RenamedDir}/${Start}.${Model}.daily.${NewVar}.${StartYear}.nc"
	OutFile="${TempDir}/${Start}.${Model}.daily.${AerocomVar}.${StartYear}.nc"
	ncks -3 -O -o ${OutFile} ${OutFile}
	set -x
	#ncks -7 -o ${OutFile} -A -v ${NewVar} ${InFile}
	ncks -3 -o ${OutFile} -A -v ${NewVar} ${InFile}
	if [ $? -ne 0 ]
		then exit 1
	fi
done
temp="${AerocomVar}=od550dust+od550so4+od550oa+od550bc"
ncap2 -7 -o ${OutFile} -O -s "${temp}" ${OutFile}
#ncap2 -3 -o ${OutFile} -O -s "${temp}" ${OutFile}
if [ $? -ne 0 ]
	then exit 1
fi
set +x
mv ${OutFile} "${RenamedDir}/"

#now calculate od550pollution as the sum of SO4+POM+BC
#Put the vars in one file...
vars=(
'od550so4'
'od550oa'
'od550bc'
)
AerocomVar='od550pollution'
NewVar=${vars[0]}
OutFile="${TempDir}/${Start}.${Model}.daily.${AerocomVar}.${StartYear}.nc"
set -x
rm -f ${OutFile}
for NewVar in ${vars[*]}
	do InFile="${RenamedDir}/${Start}.${Model}.daily.${NewVar}.${StartYear}.nc"
	OutFile="${TempDir}/${Start}.${Model}.daily.${AerocomVar}.${StartYear}.nc"
	#ncks -7 -o ${OutFile} -A -v ${NewVar} ${InFile}
	ncks -3 -O -o ${OutFile} -A -v ${NewVar} ${InFile}
	if [ $? -ne 0 ]
		then exit 1
	fi
done
temp="${AerocomVar}=od550so4+od550oa+od550bc"
ncap2 -7 -o ${OutFile} -O -s "${temp}" ${OutFile}
#ncap2 -3 -o ${OutFile} -O -s "${temp}" ${OutFile}
if [ $? -ne 0 ]
	then exit 1
fi
mv ${OutFile} "${RenamedDir}/"

set +x

IFS=$SAVEIFS

