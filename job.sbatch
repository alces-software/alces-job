#!/bin/bash
#SBATCH --job-name=Job01
#SBATCH --nodes=2
#SBATCH --ntasks=32
#SBATCH --cpus-per-task=1
#SBATCH --time=02:00:00

module load openmpi
echo "Running MPI job on $SLURM_NTASKS tasks across $SLURM_NNODES nodes"

srun 