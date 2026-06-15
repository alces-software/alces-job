#!/bin/bash
#SBATCH --job-name=the
#SBATCH --cpus-per-task=5
#SBATCH --mem=1024
#SBATCH --time=00-01:00:00
#SBATCH --partition=gpu-l40s

cd /home/calum

module load R
module load python

echo "Running job 'the'"

python script.py
