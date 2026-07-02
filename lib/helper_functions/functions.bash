#!/usr/bin/env bash

alces_start_job() {
    ALCES_CURRENT_STAGE=0

    mkdir -p "$ALCES_HOMEPATH"

    {
        echo "jobId:$SLURM_JOB_ID"
        echo "totalSteps:$ALCES_TOTAL_STAGES"
        echo "outputFile:$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/StdOut=/{print $2}')"
        echo "errorFile:$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/StdErr=/{print $2}')"
        echo "startTime:$(date -u +%s)"
        echo "status:running"
    } > "$ALCES_HOMEPATH/$SLURM_JOB_ID"

    trap alces_end_job EXIT
}

alces_start_stage() {
    ALCES_CURRENT_STAGE=$((ALCES_CURRENT_STAGE + 1))

    {
        echo "stageStart$ALCES_CURRENT_STAGE:$(date -u +%s)"
        echo "stageStatus$ALCES_CURRENT_STAGE:running"
    } >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
}

alces_end_stage() {
    
    echo "stageEnd$ALCES_CURRENT_STAGE:$(date -u +%s)" >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"
    sed -i "s/^stageStatus$ALCES_CURRENT_STAGE:.*/stageStatus$ALCES_CURRENT_STAGE:completed/" "$ALCES_HOMEPATH/$SLURM_JOB_ID"
}

alces_end_job() {
    local rc=$?

    {
        echo "endTime:$(date -u +%s)"
        echo "exitCode:$rc"

    } >> "$ALCES_HOMEPATH/$SLURM_JOB_ID"

    if (( rc == 0 )); then
        sed -i "s/^status:.*/status:completed/" "$ALCES_HOMEPATH/$SLURM_JOB_ID"
    else
        sed -i "s/^status:.*/status:failed/" "$ALCES_HOMEPATH/$SLURM_JOB_ID"
    fi
}