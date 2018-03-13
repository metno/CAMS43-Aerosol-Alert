#!/bin/bash
#shell script to interpolate the data in the download directory to common grid
#Because the netcdf files provided by ECMWF are packed with individual
#packing parameters, every file has to be unpacked first. Otherwise nco would assume 
#the same packing parameters for all files taken from the first file
#
#Because unpacking and interpolation takes quite some time. these files are cache
#in the unpacked and interpolated directories
#
#to avoid simple errrors, the interpolation script looks through the data downloaded
#the last three days if they exist in the unpacked and interpolated directories
#
#There are flags in Constants.sh to force the unpacking and interpolation to be redone
#e.g. in case the output grid changes, but one has to adjust the search for the data 
#script since even looking at all the files takes too long if it is done all the time.

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


#for dir in `find ${InterpolateInDir} -mindepth 1 -type d | grep -v 12$ | grep -v 00$ | grep -v test | grep -v interpolated | sort`
#set -x
for dir in `find ${InterpolateInDir} -mindepth 1 -maxdepth 1 -type d -newermt '5 days ago'| sort`
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

