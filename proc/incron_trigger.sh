#!/usr/bin/env bash
set -u

# This for is to avoid triggerings from hidden ('.*') files
for arg in "$@"
do
    [[ "$arg" != .?* ]] || exit 1
done

# The arguments are comming from incron; they go as:
# Triggering event: $1
# File name: $2
# Calling directory: $3

# 'env.rc' defines REPOS and DATA variables, then call their own 'env.rc'.
# Eventually -- of interest here -- REPO_VERITAS_PROC will be defined.
#TODO: Consider the use of Environment Modules for setting up variables.
source ~/env.rc
: ${REPO_VERITASLC_PROC:?'VERITAS repo enviroment not loaded.'}

EV="$1"
FC=$(echo `basename "$2"` | tr -d "[:space:]")
LOGDIR="${REPO_VERITASLC_PROC}/log"
LOGFILE="${LOGDIR}/incron_veritas_${EV}_${FC}.log"
[ -d "$LOGDIR" ] || mkdir $LOGDIR
unset FC
unset EV

# To avoid concurrence (specially when commit/fetching git)
# we'll place a short random sleep before proceeding
WAIT=$(echo "scale=2 ; 3*$RANDOM/32768" | bc -l)
WAIT=$(echo "scale=2 ; ${WAIT}*${WAIT}" | bc -l)
sleep "$WAIT"s
unset WAIT

date                                                          > $LOGFILE
echo '-----------------------------------------------------' >> $LOGFILE
#TODO: Use a non-hardcoded Anaconda load (e.g, Environment Modules)
export PATH="/opt/anaconda/bin:$PATH"
bash -x -l $REPO_VERITASLC_PROC/archive_update.sh "$@"        &>> $LOGFILE
echo '-----------------------------------------------------' >> $LOGFILE
