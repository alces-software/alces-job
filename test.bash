#!/bin/bash
#SBATCH --job-name=the
#SBATCH --cpus-per-task=5
#SBATCH --mem=1024
#SBATCH --time=00-01:00:00
#SBATCH --partition=gpu-l40s

cd /home/calum

module load r
module load t
module load y
module load u
module load i
module load o

echo "Running job 'the'"

echo 'cluster'
