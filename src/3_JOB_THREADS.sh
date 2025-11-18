#!/bin/bash

# JOB DEFINITION PARAMETERS (Name, Stdout, Stderr)
#SBATCH --job-name=JOB_THREADS
#SBATCH --output=/gpfs/projects/idib57/Stepping_Stone/bin/out/JOB_THREADS_%A.out
#SBATCH --error=/gpfs/projects/idib57/Stepping_Stone/bin/err/JOB_THREADS_%A.err

# GROUP CREDENTIALS AND BSC QUEUE
#SBATCH --account=idib57
#SBATCH --qos=cli

# RESOURCE ALLOCATION (tasks, cpus, nodes, time, array)
#SBATCH --nodes=1
#SBATCH --time=00:05:00
#SBATCH --tasks=4
#SBATCH --cpus-per-task=1

# NODE RESERVATION
#SBATCH --reservation=curso

# Create per-task log files

module load java fastqc

path_to_files="/gpfs/projects/idib57/Stepping_Stone/data/*.fastq.gz"
output_directory="/gpfs/projects/idib57/Stepping_Stone/output"

#Start time
start=$(date +%s)

#Execute simple process
fastqc $path_to_files -o $output_directory --threads 4

#End time
end=$(date +%s)

#Print elapsed time for the whole process (can also be checked from the terminal while the process is active)
elapsed=$(( end - start ))
printf "Elapsed time: %02d:%02d:%02d\n" \
       $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60))