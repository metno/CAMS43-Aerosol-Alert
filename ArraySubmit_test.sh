test.sh

#!/bin/bash
#$ -S /bin/bash
#$ -q ded-parallelx.q
#$ -t 1-40
#$ -wd /home/aerocom/lib/CAMS43-Aerosol-Alert/


##$ -l h_rt=120:00:00
##$ -M jang@met.no
##$ -m abe
#$ -l h_vmem=4G

echo "Got $NSLOTS slots for job $SGE_TASK_ID."
set -x
export CAMS43AlertHome="/home/aerocom/lib/CAMS43-Aerosol-Alert/"
export RUN_BY_CRON="TRUE"	
#${CAMS43AlertHome}/Download.sh
#${CAMS43AlertHome}/Parallel_CreateYearlyFileSingleVar.sh od550so4 suaod550
#od550dust=duaod550=alertdust
${CAMS43AlertHome}/Wrapper.sh ${CAMS43AlertHome}/ncwa.run $SGE_TASK_ID
#echo 

exit 0 
