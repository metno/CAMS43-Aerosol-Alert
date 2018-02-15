# CAMS-Aerosol-Alert
Code needed for the CAMS aerosol alert calculations

## POST RETRIEVAL of missing dates from MARS:

    EXP="0001"
    REPRES='LLG'
    CLASS='MC'
    STEPS='00/to/120/by/01'
    HR='00'
    TYPER='FC AN'
    LTYPE=SFC
    GRID=0.4                        
    EXPVER=\"${EXP}\"
    case $VAR in
           aod550)  VARNO='207.210'
           ssaod550)   VARNO='208.210';;
           duaod550) VARNO='209.210';;
           omaod550)   VARNO='210.210';
           bcaod550)   VARNO='211.210';;
           suaod550)  VARNO='212.210';;
    esac
    cat << EOF > marsrequest
    RETRIEVE,
       DATE=$Date,TYPE=$RTYPE,STEP=$STEPS,TIME=$HH,
       PARAM=${VARNO},CLASS=$CLASS,EXPVER=$EXPVER,
       GRID=${GRID}/${GRID},LEVTYPE=$LTYPE,REPRES=$REPRES,
       target="gribtemp"
     EOF
     mars marsrequest
