#!/bin/bash
#wrapper script for OpenGridEngine array jobs

echo "Wrapper: Got $NSLOTS slots for job $SGE_TASK_ID."

if [ $# -lt 2 ]
   then echo "usage: ${0} <Infile> <line no>"
   exit 1
fi
InFile=${1}
LineNo=${2}

CommandToRun=`tail "-n+${LineNo}" ${InFile} | head -n1`
echo ${CommandToRun}
#CommandToRun=`sed "${LineNo}q;d" ${InFile}`
#echo ${CommandToRun}
eval "${CommandToRun}"
