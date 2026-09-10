#!/bin/bash
#SBATCH --job-name=QIIME-analyze
#SBATCH --cpus-per-task=4
#SBATCH -o test_%A.out
#SBATCH -e test_%A.err
#SBATCH --time=01:00:00

echo "Parameters: $*"

#mkdir -p logs

source ~/.bashrc
export LC_ALL=en_US.UTF-8
conda activate q2coord

input_repseq="$1" # representative seqs
input_table="$2" # table 
input_metadata="$3" # metadata
sampling_depth="$4" # rarefaction sampling depth
out_prefix="$5" 

output_prefix="${out_prefix}_analysis_"

# Proportion urbanized
urban_column=prop_urban
adonis_metadata=~/projects/deer_metabarcoding/metadata/prop_urban_metadata.tsv

artifact_pfx="${output_prefix}a_"
vis_pfx="${output_prefix}v_"

echo "Begin alignment"
aligned_artifact="${artifact_pfx}Aligned.qza"
qiime alignment mafft \
  --i-sequences "$input_repseq" \
  --o-alignment "$aligned_artifact"

echo "Mask alignment"
masked_artifact="${artifact_pfx}Masked.qza"
qiime alignment mask \
  --i-alignment "$aligned_artifact" \
  --o-masked-alignment "$masked_artifact"

echo "Build phylogeny"
unrooted_tree_artifact="${artifact_pfx}UnrootedTree.qza"
rooted_tree_artifact="${artifact_pfx}RootedTree.qza"

qiime phylogeny fasttree \
  --i-alignment "$masked_artifact" \
  --o-tree "$unrooted_tree_artifact"

qiime phylogeny midpoint-root \
  --i-tree "$unrooted_tree_artifact" \
  --o-rooted-tree "$rooted_tree_artifact"

tree_export_dir="${output_prefix}Tree"
rm -rf "$tree_export_dir"
mkdir -p "$tree_export_dir"

qiime tools export \
  --input-path "$rooted_tree_artifact" \
  --output-path "$tree_export_dir"

tree_newick="${tree_export_dir}/tree.nwk"

### run if needed ###
echo "Alpha rarefaction curves"
alpha_rare_qzv="${vis_pfx}AlphaRarefaction.qzv"

qiime diversity alpha-rarefaction \
  --i-table "$input_table" \
  --i-phylogeny "$rooted_tree_artifact" \
  --p-max-depth 6000 \
  --m-metadata-file "$input_metadata" \
  --o-visualization "$alpha_rare_qzv"

###
echo "Core metrics (phylogenetic)"
beta_dir="${output_prefix}Beta"
rm -rf "$beta_dir"

qiime diversity core-metrics-phylogenetic \
  --i-phylogeny "$rooted_tree_artifact" \
  --i-table "$input_table" \
  --p-sampling-depth "$sampling_depth" \
  --m-metadata-file "$input_metadata" \
  --output-dir "$beta_dir" \
  --p-n-jobs-or-threads "${SLURM_CPUS_PER_TASK:-1}"

###
echo "Beta diversity significance with proportion urban"
beta_sig_dir="${output_prefix}BetaSig"
rm -rf "$beta_sig_dir"
mkdir -p "$beta_sig_dir"

bray_dm="$beta_dir/bray_curtis_distance_matrix.qza"
jacc_dm="$beta_dir/jaccard_distance_matrix.qza"

qiime diversity adonis \
  --i-distance-matrix "$bray_dm" \
  --m-metadata-file "$adonis_metadata" \
  --p-formula "$urban_column" \
  --p-permutations 999 \
  --o-visualization "$beta_sig_dir/bray_curtis-adonis_${urban_column}.qzv"

qiime diversity adonis \
  --i-distance-matrix "$jacc_dm" \
  --m-metadata-file "$adonis_metadata" \
  --p-formula "$urban_column" \
  --p-permutations 999 \
  --o-visualization "$beta_sig_dir/jaccard-adonis_${urban_column}.qzv"

###
echo "Alpha diversity correlations + tabulations"
alpha_dir="${output_prefix}Alpha"
rm -rf "$alpha_dir"
mkdir -p "$alpha_dir"

echo "Alpha diversity correlations with proportion urban"

qiime diversity alpha-correlation \
  --i-alpha-diversity "$beta_dir/shannon_vector.qza" \
  --m-metadata-file "$input_metadata" \
  --p-method spearman \
  --o-visualization "$alpha_dir/shannon-correlation_${urban_column}.qzv"

qiime diversity alpha-correlation \
  --i-alpha-diversity "$beta_dir/observed_features_vector.qza" \
  --m-metadata-file "$input_metadata" \
  --p-method spearman \
  --o-visualization "$alpha_dir/observed-features-correlation_${urban_column}.qzv"

# Tabulate alpha metrics
qiime metadata tabulate \
  --m-input-file "$beta_dir/faith_pd_vector.qza" \
  --o-visualization "$alpha_dir/faith_pd_vector.qzv"

qiime metadata tabulate \
  --m-input-file "$beta_dir/observed_features_vector.qza" \
  --o-visualization "$alpha_dir/observed_features_vector.qzv"

qiime metadata tabulate \
  --m-input-file "$beta_dir/shannon_vector.qza" \
  --o-visualization "$alpha_dir/shannon_vector.qzv"

qiime metadata tabulate \
  --m-input-file "$beta_dir/evenness_vector.qza" \
  --o-visualization "$alpha_dir/evenness_vector.qzv"

echo "Done"
echo "Tree newick:"
echo "- $tree_newick"
echo "View QIIME2 visualizations on https://view.qiime2.org/:"
echo "- $alpha_dir"
echo "- $beta_dir"
echo "- $beta_sig_dir"
