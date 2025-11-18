#!/bin/bash

# JOB DEFINITION PARAMETERS (Name, Stdout, Stderr)
#SBATCH --job-name=JOB_ARRAY
#SBATCH --output=/gpfs/projects/idib57/Stepping_Stone/bin/out/JOB_ARRAY_%A_%a.out
#SBATCH --error=/gpfs/projects/idib57/Stepping_Stone/bin/err/JOB_ARRAY_%A_%a.err

# GROUP CREDENTIALS AND BSC QUEUE
#SBATCH --account=idib57
#SBATCH --qos=cli

# RESOURCE ALLOCATION (tasks, cpus, nodes, time, array)
#SBATCH --nodes=1
#SBATCH --time=00:05:00
#SBATCH --cpus-per-task=1
#SBATCH --array=1-4

# NODE RESERVATION
#SBATCH --reservation=curso
​
module load java fastqc

path_to_files="/gpfs/projects/idib57/Stepping_Stone/data/"
output_directory="/gpfs/projects/idib57/Stepping_Stone/output"

#Start time
start=$(date +%s)

#Execute simple process
fastqc $path_to_files/00$SLURM_ARRAY_TASK_ID.fastq.gz -o $output_directory

#End time
end=$(date +%s)

#Print elapsed time for the whole process (can also be checked from the terminal while the process is active)
elapsed=$(( end - start ))
printf "Elapsed time: %02d:%02d:%02d\n" \
       $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60))