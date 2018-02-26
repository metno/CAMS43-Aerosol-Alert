#!/bin/bash
#shell script to calculate the aod anomaly and the laert level 
#This is AOD_an = AOD_day / AOD_clim,month

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

NCOCalcFile="${TempDir}calc_alert_aer.nco"

#put the prototype for the nco script into a bash variable
read -r -d '' NCOProt <<'EOF'
*od550aer_anomaly=od550aer/od550aerclim;
*aodalert2=od550aer(:,:,:);
*aodalert1=od550aer(:,:,:);
*alertaer=od550aer(:,:,:);
aodalert2(:,:,:)=0;
aodalert1(:,:,:)=0;
alertaer(:,:,:)=0;
where(od550aer_anomaly(:,:,:)>2.){
aodalert1(:,:,:)=1.;
}
where(od550aer_anomaly(:,:,:)>3.){
aodalert1(:,:,:)=2.;
}
where(od550aer_anomaly(:,:,:)>5.){
aodalert1(:,:,:)=3.;
}
where(od550aer(:,:,:)>0.50){
aodalert2(:,:,:)=1.;
}
alertaer=aodalert1*aodalert2;
alertaer.ram_write();
od550aer_anomaly.ram_write();

EOF

set -x
for ModelVar in ${varlist[*]}
	do AerocomVar=`echo ${ModelVar} | cut -d= -f1`
	MaccVar=`echo ${ModelVar} | cut -d= -f2`
	OutVar=`echo ${ModelVar} | cut -d= -f3`
	if [ ${OutVar} == 'NotNeeded' ]
		then continue
	fi

	ClimFile="${RenamedDir}${ClimModel}.daily.${AerocomVar}.${ClimYear}.nc"
	InFile="${RenamedDir}aerocom.${Model}.daily.${AerocomVar}.${StartYear}.nc"
	OutFile="${TempDir}${Start}.${Model}.daily.${OutVar}.${StartYear}.nc"
	Tempfile="${TempDir}calc_alert_temp.nc"
	#1st bring the climatology into the OutFile

	NewVar="${AerocomVar}clim"
	set -x
	ncrename -O -v ${AerocomVar},${NewVar} -o ${Tempfile} ${ClimFile}
	ncks -7 -o ${OutFile} -O ${InFile}
	if [ $? -ne 0 ]
		then exit 1
	fi
	ncks -7 -o ${OutFile} -A -v ${NewVar} ${Tempfile}
	if [ $? -ne 0 ]
		then exit 1
	fi
	set +x
	case "${OutVar}" in
		#No alerr variable needed 
		#NotNeeded)	echo "no out variable to write..."
		#;;

		#no need to change the script for outvar alertaer
		alertaer)	c_AertVar=${OutVar}
			c_ReplaceStr=${AerocomVar}
			echo "${NCOProt}" > "${NCOCalcFile}"
			set -x
			ncap2 -7 -o "${OutFile}" -O -S "${NCOCalcFile}" "${OutFile}"
			if [ $? -ne 0 ]
				then exit 1
			fi
			set +x
			;;

		#else statement: Default
		*)	c_AertVar='alertaer'
			c_ReplaceStr='od550aer'
			echo "${NCOProt}" | sed -e s/${c_ReplaceStr}/${AerocomVar}/g -e s/${c_AertVar}/${OutVar}/g > "${NCOCalcFile}"
			set -x
			ncap2 -7 -o "${OutFile}" -O -S "${NCOCalcFile}" "${OutFile}"
			if [ $? -ne 0 ]
				then exit 1
			fi
			set +x
			;;
		
	esac
	ncatted -O -a "units,${OutVar},m,c,1" "${OutFile}"
	mv "${OutFile}" "${RenamedDir}"
	rm -f "${Tempfile}"
	rm -f ${NCOCalcFile}

done


IFS=$SAVEIFS

