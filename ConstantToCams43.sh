#!/bin/bash

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")


InFile="Constants.sh"
BackupFile="Constants.sh.backup"


cp ${InFile} ${BackupFile}
#cat ${BackupFile} | sed -e 's/\/home\/aerocom\/lib/\/home\/cams43/g' -e 's/\/home\/aerocom\/bin/\/home\/cams43\/CAMS43-Aerosol-Alert/g' -e 's/FCModelPath="\$\{BasePath\}aerocom1\/\$\{Model\}/FCModelPath="\$\{BasePath\}\/\$\{Model\}/g' > ${InFile}
cat ${BackupFile} | sed -e 's/\/home\/aerocom\/lib/\/home\/cams43/g' -e 's/\/home\/aerocom\/bin/\/home\/cams43\/CAMS43-Aerosol-Alert/g' -e 's/aerocom1//g'  -e 's/\/lustre\/storeA\/project\/aerocom/\/lustre\/storeA\/project\/fou\/kl\/CAMS43/g' -e 's/\/aerocom-users-database\/ECMWF//g' > ${InFile}

echo 'StartAerocomToolsFlag=0' >> ${InFile}
IFS=$SAVEIFS

