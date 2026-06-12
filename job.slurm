#!/bin/bash
#SBATCH --job-name=myjob
#SBATCH --cpus-per-task=7
#SBATCH --mem=105M
#SBATCH --time=00-01:00:00
#SBATCH --partition=gpu-l40s


echo "Running job 'myjob'"

python script.py
