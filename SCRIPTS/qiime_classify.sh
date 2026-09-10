#!/bin/bash
#SBATCH --job-name=QIIME-classify
#SBATCH --cpus-per-task=4
#SBATCH -o test_%A.out
#SBATCH -e test_%A.err
#SBATCH --time=01:00:00

echo "Parameters: $*"

source ~/.bashrc
export LC_ALL=en_US.UTF-8
conda activate q2coord

repseqs_qza="$1" # *_RepSeqs_Decontam.qza
classifier_qza="$2" # SILVA classifier .qza
table_qza="$3" # *_Table_Decontam_NoControls.qza
out_prefix="$4" # output prefix (full path ok)

artifact_pfx="${out_prefix}_a_"
vis_pfx="${out_prefix}_v_"
stats_pfx="${out_prefix}_s_"

echo "Begin classification (classify-sklearn)"
tax_qza="${artifact_pfx}Taxonomy.qza"
qiime feature-classifier classify-sklearn \
  --i-classifier "$classifier_qza" \
  --i-reads "$repseqs_qza" \
  --o-classification "$tax_qza" \
  --p-n-jobs "${SLURM_CPUS_PER_TASK:-1}"

echo "Tabulate taxonomy"
tax_qzv="${vis_pfx}Taxonomy.qzv"
qiime metadata tabulate \
  --m-input-file "$tax_qza" \
  --o-visualization "$tax_qzv"

echo "Filter table to phylum-level; exclude mito/chloro"
phylum_table_qza="${artifact_pfx}Table_Phylum_NoMitoChloro.qza"
qiime taxa filter-table \
  --i-table "$table_qza" \
  --i-taxonomy "$tax_qza" \
  --p-include "p__" \
  --p-exclude mitochondria,chloroplast \
  --o-filtered-table "$phylum_table_qza"

echo "Summarize filtered table (no metadata)"
phylum_table_qzv="${vis_pfx}Table_Phylum_NoMitoChloro.qzv"
qiime feature-table summarize \
  --i-table "$phylum_table_qza" \
  --o-visualization "$phylum_table_qzv"

echo "Export filtered table + TSV"
export_dir="${out_prefix}_phylum_table_export"
rm -rf "$export_dir"
mkdir -p "$export_dir"

qiime tools export \
  --input-path "$phylum_table_qza" \
  --output-path "$export_dir"

tsv_out="${stats_pfx}PhylumTable.tsv"
biom convert \
  -i "$export_dir/feature-table.biom" \
  -o "$tsv_out" \
  --to-tsv

echo "Taxa barplot (no metadata)"
barplot_qzv="${vis_pfx}TaxaBarplot.qzv"
qiime taxa barplot \
  --i-table "$phylum_table_qza" \
  --i-taxonomy "$tax_qza" \
  --o-visualization "$barplot_qzv"

echo "Done"

