#!/bin/bash -l
# author: ge199066
#SBATCH -J qiime_inst
#SBATCH -o qiime_inst.out
#SBATCH -e qiime_inst.err
#SBATCH -p normal
#SBATCH --cpus-per-task=8
#SBATCH -t 7-0:00:00
#SBATCH --mem-per-cpu=16000

conda env create -n qiime2-amplicon-2024.10 --file https://data.qiime2.org/distro/amplicon/qiime2-amplicon-2024.10-py310-linux-conda.yml

# TEST ACTIVATION
# set -x # debugging mode
# conda info --envs
# conda activate qiime2-amplicon-2024.10
# conda info --envs
# conda deactivate
# conda info --envs