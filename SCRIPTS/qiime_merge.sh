#!/bin/bash
#SBATCH --job-name=QIIME-merge
#SBATCH --cpus-per-task=16
#SBATCH -o test_%A.out
#SBATCH -e test_%A.err
#SBATCH --time=06:00:00

echo "Parameters: $*"

source ~/.bashrc
export LC_ALL=en_US.UTF-8
conda activate q2coord

input_file="$1" # Trimmed demux .qza
output_prefix="${2}_merged_" # Prefix
trunc_f="$3" # Forward truncation length
trunc_r="$4" # Reverse truncation length

artifact_pfx="${output_prefix}a_"
vis_pfx="${output_prefix}v_"
stats_pfx="${output_prefix}s_"

echo "Begin DADA2 denoise-paired"
table_artifact="${artifact_pfx}Table.qza"
rep_seq_artifact="${artifact_pfx}RepSeqs.qza"
denoise_artifact="${artifact_pfx}DenoisingStats.qza"

qiime dada2 denoise-paired \
  --i-demultiplexed-seqs "$input_file" \
  --p-trim-left-f 0 \
  --p-trim-left-r 0 \
  --p-trunc-len-f "$trunc_f" \
  --p-trunc-len-r "$trunc_r" \
  --p-n-threads "${SLURM_CPUS_PER_TASK:-1}" \
  --o-table "$table_artifact" \
  --o-representative-sequences "$rep_seq_artifact" \
  --o-denoising-stats "$denoise_artifact" \
  --verbose

echo "Visualize denoising stats"
denoise_vis="${vis_pfx}DenoiseStats.qzv"
qiime metadata tabulate \
  --m-input-file "$denoise_artifact" \
  --o-visualization "$denoise_vis"

echo "Summarize feature table"
table_vis="${vis_pfx}Table.qzv"
qiime feature-table summarize \
  --i-table "$table_artifact" \
  --o-visualization "$table_vis"

echo "Export table and write TSV summary"
table_export_dir="${output_prefix}table_export"
rm -rf "$table_export_dir"
mkdir -p "$table_export_dir"

qiime tools export \
  --input-path "$table_artifact" \
  --output-path "$table_export_dir"

summary_stats="${stats_pfx}DadaSummary.tsv"
biom convert \
  -i "$table_export_dir/feature-table.biom" \
  -o "$summary_stats" \
  --to-tsv

echo "Tabulate representative sequences"
rep_seq_vis="${vis_pfx}RepSeqs.qzv"
qiime feature-table tabulate-seqs \
  --i-data "$rep_seq_artifact" \
  --o-visualization "$rep_seq_vis"

echo "Done"
echo "Download:"
echo "- $summary_stats"
echo "View on https://view.qiime2.org/:"
echo "- $denoise_vis"
echo "- $table_vis"
echo "- $rep_seq_vis"

