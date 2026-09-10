#!/bin/bash
#SBATCH --job-name=QIIME-sex-age
#SBATCH --cpus-per-task=2
#SBATCH -o sex_age_%A.out
#SBATCH -e sex_age_%A.err
#SBATCH --time=00:30:00

set -e

source ~/.bashrc
export LC_ALL=en_US.UTF-8
conda activate q2coord

out_prefix="$1"
metadata="$2"

beta_dir="${out_prefix}_analysis_Beta"
out_dir="${out_prefix}_analysis_SexAge"

rm -rf "$out_dir"
mkdir -p "$out_dir"

bray_dm="$beta_dir/bray_curtis_distance_matrix.qza"
jacc_dm="$beta_dir/jaccard_distance_matrix.qza"

# Reduced metadata files
python - <<PY
import pandas as pd

metadata = pd.read_csv(
    "${metadata}",
    dtype=str,
    keep_default_na=False
)

sex = metadata[["sample-id", "Sex"]].copy()
sex = sex[
    (sex["sample-id"] != "") &
    (sex["Sex"] != "") &
    (~sex["Sex"].str.lower().isin(["na", "unknown"]))
]
sex.columns = ["#SampleID", "Sex"]
sex.to_csv(
    "${out_dir}/sex_metadata.tsv",
    sep="\t",
    index=False
)

age = metadata[["sample-id", "AgeCategor"]].copy()
age = age[
    (age["sample-id"] != "") &
    (age["AgeCategor"] != "") &
    (~age["AgeCategor"].str.lower().isin(["na", "unknown"]))
]
age.columns = ["#SampleID", "AgeCategor"]
age.to_csv(
    "${out_dir}/age_metadata.tsv",
    sep="\t",
    index=False
)

print("Sex samples:", len(sex))
print(sex["Sex"].value_counts())

print("Age samples:", len(age))
print(age["AgeCategor"].value_counts())
PY

sex_metadata="$out_dir/sex_metadata.tsv"
age_metadata="$out_dir/age_metadata.tsv"

# Filter beta diversity matrices to samples with known age
qiime diversity filter-distance-matrix \
  --i-distance-matrix "$bray_dm" \
  --m-metadata-file "$age_metadata" \
  --o-filtered-distance-matrix "$out_dir/bray_curtis_age_filtered.qza"

qiime diversity filter-distance-matrix \
  --i-distance-matrix "$jacc_dm" \
  --m-metadata-file "$age_metadata" \
  --o-filtered-distance-matrix "$out_dir/jaccard_age_filtered.qza"

# Filter alpha diversity vectors to samples with known age
qiime diversity filter-alpha-diversity \
  --i-alpha-diversity "$beta_dir/shannon_vector.qza" \
  --m-metadata-file "$age_metadata" \
  --o-filtered-alpha-diversity "$out_dir/shannon_age_filtered.qza"

qiime diversity filter-alpha-diversity \
  --i-alpha-diversity "$beta_dir/observed_features_vector.qza" \
  --m-metadata-file "$age_metadata" \
  --o-filtered-alpha-diversity "$out_dir/observed_features_age_filtered.qza"

# Beta diversity: sex
qiime diversity adonis \
  --i-distance-matrix "$bray_dm" \
  --m-metadata-file "$sex_metadata" \
  --p-formula "Sex" \
  --p-permutations 999 \
  --o-visualization "$out_dir/bray_curtis-adonis_Sex.qzv"

qiime diversity adonis \
  --i-distance-matrix "$jacc_dm" \
  --m-metadata-file "$sex_metadata" \
  --p-formula "Sex" \
  --p-permutations 999 \
  --o-visualization "$out_dir/jaccard-adonis_Sex.qzv"

# Beta diversity: age category
qiime diversity adonis \
  --i-distance-matrix "$out_dir/bray_curtis_age_filtered.qza" \
  --m-metadata-file "$age_metadata" \
  --p-formula "AgeCategor" \
  --p-permutations 999 \
  --o-visualization "$out_dir/bray_curtis-adonis_AgeCategor.qzv"

qiime diversity adonis \
  --i-distance-matrix "$out_dir/jaccard_age_filtered.qza" \
  --m-metadata-file "$age_metadata" \
  --p-formula "AgeCategor" \
  --p-permutations 999 \
  --o-visualization "$out_dir/jaccard-adonis_AgeCategor.qzv"

# Alpha diversity: sex
qiime diversity alpha-group-significance \
  --i-alpha-diversity "$beta_dir/shannon_vector.qza" \
  --m-metadata-file "$sex_metadata" \
  --o-visualization "$out_dir/shannon-Sex.qzv"

qiime diversity alpha-group-significance \
  --i-alpha-diversity "$beta_dir/observed_features_vector.qza" \
  --m-metadata-file "$sex_metadata" \
  --o-visualization "$out_dir/observed_features-Sex.qzv"

# Alpha diversity: age category
qiime diversity alpha-group-significance \
  --i-alpha-diversity "$out_dir/shannon_age_filtered.qza" \
  --m-metadata-file "$age_metadata" \
  --o-visualization "$out_dir/shannon-AgeCategor.qzv"

qiime diversity alpha-group-significance \
  --i-alpha-diversity "$out_dir/observed_features_age_filtered.qza" \
  --m-metadata-file "$age_metadata" \
  --o-visualization "$out_dir/observed_features-AgeCategor.qzv"

echo "Done"
echo "Results:"
echo "$out_dir"