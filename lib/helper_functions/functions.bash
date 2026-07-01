#!/usr/bin/env bash

alces_start_job() {
    ALCES_CURRENT_STAGE=0
    mkdir -p $ALCES_HOMEPATH
    echo "jobId:$SLURM_JOB_ID" > "$ALCES_HOMEPATH/$SLURM_JOB_ID"
    echo "totalSteps:$ALCES_TOTAL_STAGES" >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
    echo "outputFile:$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/StdOut=/{print $2}')" >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
    echo "errorFile:$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/StdErr=/{print $2}')" >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
    echo "startTime:$(date -u +%s)" >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
}

alces_end_stage() {
    ALCES_CURRENT_STAGE=$((ALCES_CURRENT_STAGE + 1))
    echo "stage$ALCES_CURRENT_STAGE:$(date -u +%s)" >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
}

alces_end_job() {
    echo "endTime:$(date -u +%s)" >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
}