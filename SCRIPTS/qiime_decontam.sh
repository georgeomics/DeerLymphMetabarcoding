#!/bin/bash
#SBATCH --job-name=QIIME-decontam
#SBATCH --cpus-per-task=4
#SBATCH -o test_%A.out
#SBATCH -e test_%A.err
#SBATCH --time=02:00:00

echo "Parameters: $*"

source ~/.bashrc
export LC_ALL=en_US.UTF-8
conda activate q2coord

table_qza="$1" # FeatureTable[Frequency] from DADA2 (Table.qza)
repseqs_qza="$2" # FeatureData[Sequence] from DADA2 (RepSeqs.qza)
controls_tsv="$3" # sample metadata: sample-id, is_control (True/False)
out_prefix="$4" # output prefix (full path ok)
threshold="${5:-0.10}" # default 0.10

artifact_pfx="${out_prefix}_a_"
vis_pfx="${out_prefix}_v_"

echo "Identify contaminants (prevalence; uses is_control column)"
scores_qza="${artifact_pfx}DecontamScores.qza"

qiime quality-control decontam-identify \
  --i-table "$table_qza" \
  --m-metadata-file "$controls_tsv" \
  --p-method prevalence \
  --p-prev-control-column is_control \
  --p-prev-control-indicator True \
  --o-decontam-scores "$scores_qza" \
  --verbose

echo "Visualize score distribution"
scores_viz="${vis_pfx}DecontamScores.qzv"

qiime quality-control decontam-score-viz \
  --i-decontam-scores "$scores_qza" \
  --i-table "$table_qza" \
  --i-rep-seqs "$repseqs_qza" \
  --p-threshold "$threshold" \
  --o-visualization "$scores_viz"

echo "Remove contaminants from table + rep-seqs"
filt_table_qza="${artifact_pfx}Table_Decontam.qza"
filt_repseqs_qza="${artifact_pfx}RepSeqs_Decontam.qza"

qiime quality-control decontam-remove \
  --i-decontam-scores "$scores_qza" \
  --i-table "$table_qza" \
  --i-rep-seqs "$repseqs_qza" \
  --p-threshold "$threshold" \
  --o-filtered-table "$filt_table_qza" \
  --o-filtered-rep-seqs "$filt_repseqs_qza" \
  --verbose

echo "Drop control samples from decontaminated table"
noctrl_table_qza="${artifact_pfx}Table_Decontam_NoControls.qza"

qiime feature-table filter-samples \
  --i-table "$filt_table_qza" \
  --m-metadata-file "$controls_tsv" \
  --p-where "[is_control]='True'" \
  --p-exclude-ids \
  --o-filtered-table "$noctrl_table_qza"

echo "Summarize filtered table"
noctrl_table_viz="${vis_pfx}Table_Decontam_NoControls.qzv"
qiime feature-table summarize \
  --i-table "$noctrl_table_qza" \
  --o-visualization "$noctrl_table_viz"

echo "Done"
echo "View on https://view.qiime2.org/:"
echo "- $scores_viz"
echo "- $noctrl_table_viz"
echo "Outputs:"
echo "- $noctrl_table_qza"
echo "- $filt_repseqs_qza"

