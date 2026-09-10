#!/bin/bash
# author: ge199066
#SBATCH -J install
#SBATCH -o %A_install.out
#SBATCH -e %A_install.err
#SBATCH -p normal
#SBATCH --cpus-per-task=8
#SBATCH -t 48:00:00
#SBATCH --mem-per-cpu=16000

set -euo pipefail

eval "$(/home/gzaragoza/miniconda3/bin/conda shell.bash hook)"

ENV="q2coord"
Q2_LABEL="qiime2/label/r2024.10"

conda activate "$ENV"

# Install the 2024.10 amplicon distro into the existing env
conda install -y \
  -c "$Q2_LABEL" -c conda-forge -c bioconda \
  "qiime2-amplicon=2024.10.*"

qiime info

