#!/bin/sh
#SBATCH --job-name=QIIME-qc
#SBATCH --cpus-per-task=4
#SBATCH -o test_%A.out
#SBATCH -e test_%A.err
#SBATCH --time=02:30:00


echo Parameters: "$@"


source ~/.bashrc # Stokes was not loading this, interfering w/ conda
# Fix a locale issue with python
export LC_ALL=en_US.UTF-8
# activate the conda environment
#conda activate qiime
conda activate q2coord


input_manifest=$1 # CSV of file names
output_prefix=${2}_reads


artifact_prefix=${output_prefix}_a_
vis_prefix=${output_prefix}_v_


# Convert fasta files to qza
echo Converting fasta
qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path "$input_manifest" \
  --output-path "${output_prefix}.qza" \
  --input-format PairedEndFastqManifestPhred33V2



# Samples were already demultiplexed, so we can skip ahead to visualizing them
echo Summarizing Raw
raw_artifact=$output_prefix.qza
raw_vis=${vis_prefix}Raw.qzv
qiime demux summarize \
    --i-data $raw_artifact --o-visualization $raw_vis


# Now trim adapters off
echo Trimming
trimmed_artifact=${artifact_prefix}Trimmed.qza
qiime cutadapt trim-paired \
    --i-demultiplexed-sequences $raw_artifact \
    --p-front-f TCGTCGGCAGCGTCAGATGTGTATAAGAGACAGCCTACGGGNGGCWGCAG \
    --p-front-r GTCTCGTGGGCTCGGAGATGTGTATAAGAGACAGGACTACHVGGGTATCTAATCC \
    --p-discard-untrimmed true \
    --o-trimmed-sequences $trimmed_artifact \
    --verbose


echo Summarizing
trimmed_vis=$output_prefix.qzv
qiime demux summarize \
    --i-data $trimmed_artifact \
    --o-visualization $trimmed_vis


echo Done!
echo Copy visualizations to your computer:
echo - $raw_vis
echo - $trimmed_vis
echo and view them on https://view.qiime2.org/
