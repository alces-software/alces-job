#!/usr/bin/env bash

alces_start_job() {
    mkdir -p $ALCES_HOMEPATH
    echo "jobId:$SLURM_JOB_ID" > "$ALCES_HOMEPATH/$SLURM_JOB_ID"
    echo "outputFile:$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/StdOut=/{print $2}')" >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
    echo "startTime:$(date -u +%s)" >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
}

alces_end_job() {
    echo "endTime:$(date -u +%s)" >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
}