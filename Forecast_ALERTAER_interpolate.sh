#!/bin/bash
#shell script to create from the daily downloaded files in ../download
#a yearly file

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

#load constants
set -x
if [ -z ${CAMS43AlertHome} ]
        then . /home/aerocom/bin/ForecastConstants.sh
else
        . "${CAMS43AlertHome}/ForecastConstants.sh"
fi
set +x


#for dir in `find ${InterpolateInDir} -mindepth 1 -type d | grep -v 12$ | grep -v 00$ | grep -v test | grep -v interpolated | sort`
#set -x
for dir in `find ${InterpolateInDir} -mindepth 1 -maxdepth 1 -type d -newermt '3 days ago'| sort`
#for dir in `find ${InterpolateInDir} -mindepth 1 -maxdepth 1 -type d | grep 201709 | sort`
	do echo ${dir}
	#OutDirLastPart=`echo ${dir} | cut -d/ -f 9`
	OutDirLastPart=`echo ${dir} | rev | cut -d/ -f1 | rev`
	ncoutdir="${InterpolateOutDir}${OutDirLastPart}"
	#only use the midnight forecast for now
	if [[ ${#OutDirLastPart} -le 8 ]]
		then ncoutdir="${ncoutdir}00"
	elif [ ${ncoutdir:(-2)} != "00" ]
		then echo "no midnight dir. continuing..."
		continue
	fi
	mkdir -p ${ncoutdir}
	UncompressedDir=`echo ${ncoutdir} | sed -e s/interpolated/unpacked/g`
	mkdir -p ${UncompressedDir}
	for ncinfile in `find ${dir} -type f -name '*.nc' | sort`
	#for ncinfile in `find ${dir} -type f -name '*duaod550.nc' | sort`
		do echo ${ncinfile}
		basefile=`basename ${ncinfile}`
		ncoutfile="${ncoutdir}/${basefile}"
		UncompressedFile="${UncompressedDir}/${basefile}"
		#set -x
		if [[ ! -f ${UncompressedFile} ]] || [ ${RedoUnpackFlag} -eq 1 ]
			then
			ncpdq -7 -O -U ${ncinfile} ${UncompressedFile}
		fi
		#set +x
		if [[ ! -f ${ncoutfile} ]] || [ ${RedoInterpolationFlag} -eq 1 ]
			then
			#set -x
			CdoNo=`ps -U ${LOGNAME} -u ${LOGNAME} | grep cdo | wc -l`
			echo "#of cdo running ${CdoNo}"
			if [[ ${CdoNo} -gt 20 ]] # the ncpdq call limits this to at most ~ 8 at a time 
				then
				#this makes the yearly file creation script using 6 times the time
				#cdo -f nc4c -O -z zip_5 remapnn,${GridFile} ${UncompressedFile} ${ncoutfile}
				cdo -f nc4c -O remapnn,${GridFile} ${UncompressedFile} ${ncoutfile}
			else 
				#cdo -s -f nc4c -z zip_5 -O remapnn,${GridFile} ${UncompressedFile} ${ncoutfile} &
				cdo -s -f nc4c -O remapnn,${GridFile} ${UncompressedFile} ${ncoutfile} &
			fi
			#set +x
			#echo ${UncompressedFile}
		fi
	done
done

IFS=${SAVEIFS}

