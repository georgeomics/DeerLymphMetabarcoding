#!/bin/bash
#SBATCH --job-name=QIIME-geo
#SBATCH --cpus-per-task=2
#SBATCH -o geo_%A.out
#SBATCH -e geo_%A.err
#SBATCH --time=00:30:00

source ~/.bashrc
export LC_ALL=en_US.UTF-8
eval "$(/home/gzaragoza/miniconda3/bin/conda shell.bash hook)"
conda activate q2coord

out_prefix="$1"
metadata="$2"
lat_col="${3:-latitude}"
lon_col="${4:-longitude}"
perms="${5:-999}"

output_prefix="${out_prefix}_analysis_"
beta_dir="${output_prefix}Beta"
out_dir="${output_prefix}GeoStats"
rm -rf "$out_dir"
mkdir -p "$out_dir"

bray_dm="$beta_dir/bray_curtis_distance_matrix.qza"
jacc_dm="$beta_dir/jaccard_distance_matrix.qza"
uu_dm="$beta_dir/unweighted_unifrac_distance_matrix.qza"
wu_dm="$beta_dir/weighted_unifrac_distance_matrix.qza"

# 1) Build geographic distance matrix
geo_tsv="$out_dir/geo_distance_km.tsv"

python - <<PY
import pandas as pd, numpy as np
from io import StringIO

meta_path = "${metadata}"
lat_col, lon_col = "${lat_col}", "${lon_col}"

lines = [l for l in open(meta_path).read().splitlines() if not l.startswith("#q2:types")]
if lines and lines[0].startswith("#"):
    lines[0] = lines[0][1:]

tmp = pd.read_csv(StringIO("\n".join(lines)), sep="\t", dtype=str)
df = tmp.set_index(tmp.columns[0])

lat = pd.to_numeric(df[lat_col], errors="coerce")
lon = pd.to_numeric(df[lon_col], errors="coerce")

keep = lat.notna() & lon.notna()
lat, lon, ids = lat[keep].to_numpy(), lon[keep].to_numpy(), df.index[keep].to_list()

R = 6371.0088
latr, lonr = np.radians(lat), np.radians(lon)
dlat, dlon = latr[:, None] - latr[None, :], lonr[:, None] - lonr[None, :]
a = np.sin(dlat/2)**2 + np.cos(latr)[:, None] * np.cos(latr)[None, :] * np.sin(dlon/2)**2
d = 2 * R * np.arcsin(np.minimum(1.0, np.sqrt(a)))

with open("${geo_tsv}", "w") as f:
    f.write("\t" + "\t".join(ids) + "\n")
    for i, sid in enumerate(ids):
        f.write(sid + "\t" + "\t".join(f"{x:.6f}" for x in d[i, :]) + "\n")
PY

geo_qza="$out_dir/geo_distance_km.qza"
qiime tools import --type DistanceMatrix --input-path "$geo_tsv" --output-path "$geo_qza"

# 2) Mantel tests
mantel_dir="$out_dir/Mantel"
mkdir -p "$mantel_dir"
for dm in "$bray_dm" "$jacc_dm" "$uu_dm" "$wu_dm"; do
  base="$(basename "$dm" .qza)"
  qiime diversity mantel \
    --i-dm1 "$dm" \
    --i-dm2 "$geo_qza" \
    --p-method spearman \
    --p-permutations "$perms" \
    --p-intersect-ids \
    --o-visualization "$mantel_dir/mantel_${base}_vs_geo.qzv"
done

# 3) BIOENV
for dm in "$bray_dm" "$jacc_dm" "$uu_dm" "$wu_dm"; do
  base="$(basename "$dm" .qza)"
  qiime diversity bioenv \
    --i-distance-matrix "$dm" \
    --m-metadata-file "$metadata" \
    --o-visualization "$out_dir/bioenv_${base}.qzv"
done

# 4) Alpha correlations and group significance
qiime diversity alpha-correlation \
  --i-alpha-diversity "$beta_dir/shannon_vector.qza" \
  --m-metadata-file "$metadata" \
  --p-method spearman \
  --p-intersect-ids \
  --o-visualization "$out_dir/alpha_corr_shannon.qzv"

qiime diversity alpha-group-significance \
  --i-alpha-diversity "$beta_dir/shannon_vector.qza" \
  --m-metadata-file "$metadata" \
  --o-visualization "$out_dir/shannon_group_significance_urban.qzv"

# 5) PERMANOVA for each beta distance matrix
for dm in "$bray_dm" "$jacc_dm" "$uu_dm" "$wu_dm"; do
  base="$(basename "$dm" .qza)"
  qiime diversity adonis \
    --i-distance-matrix "$dm" \
    --m-metadata-file "$metadata" \
    --p-formula "urban" \
    --p-permutations "$perms" \
    --o-visualization "$out_dir/adonis_${base}_urban.qzv"
done

