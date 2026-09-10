#!/bin/bash
#SBATCH --job-name=QIIME-mantel
#SBATCH --cpus-per-task=2
#SBATCH -o mantel_%A.out
#SBATCH -e mantel_%A.err
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

beta_dir="${out_prefix}_analysis_Beta"
out_dir="${out_prefix}_analysis_GeoStats"
mantel_dir="$out_dir/Mantel"

mkdir -p "$mantel_dir"

geo_tsv="$out_dir/geo_distance_km.tsv"
geo_qza="$out_dir/geo_distance_km.qza"

# Build geographic distance matrix
python - <<PY
import pandas as pd
import numpy as np
from io import StringIO

lines = [
    line for line in open("${metadata}").read().splitlines()
    if not line.startswith("#q2:types")
]

tmp = pd.read_csv(
    StringIO("\n".join(lines)),
    sep="\t",
    dtype=str
)

df = tmp.set_index(tmp.columns[0])

lat = pd.to_numeric(df["${lat_col}"], errors="coerce")
lon = pd.to_numeric(df["${lon_col}"], errors="coerce")

keep = lat.notna() & lon.notna()

lat = lat[keep].to_numpy()
lon = lon[keep].to_numpy()
ids = df.index[keep].to_list()

R = 6371.0088

latr = np.radians(lat)
lonr = np.radians(lon)

dlat = latr[:, None] - latr[None, :]
dlon = lonr[:, None] - lonr[None, :]

a = (
    np.sin(dlat / 2) ** 2
    + np.cos(latr)[:, None]
    * np.cos(latr)[None, :]
    * np.sin(dlon / 2) ** 2
)

distances = 2 * R * np.arcsin(np.minimum(1.0, np.sqrt(a)))

with open("${geo_tsv}", "w") as f:
    f.write("\t" + "\t".join(ids) + "\n")

    for i, sample_id in enumerate(ids):
        values = "\t".join(f"{x:.6f}" for x in distances[i, :])
        f.write(sample_id + "\t" + values + "\n")
PY

# Import geographic distance matrix
qiime tools import \
  --input-path "$geo_tsv" \
  --type DistanceMatrix \
  --output-path "$geo_qza"

# Bray-Curtis Mantel test
qiime diversity mantel \
  --i-dm1 "$beta_dir/bray_curtis_distance_matrix.qza" \
  --i-dm2 "$geo_qza" \
  --p-method spearman \
  --p-permutations "$perms" \
  --p-intersect-ids \
  --o-visualization "$mantel_dir/mantel_bray_curtis_vs_geo.qzv"

# Jaccard Mantel test
qiime diversity mantel \
  --i-dm1 "$beta_dir/jaccard_distance_matrix.qza" \
  --i-dm2 "$geo_qza" \
  --p-method spearman \
  --p-permutations "$perms" \
  --p-intersect-ids \
  --o-visualization "$mantel_dir/mantel_jaccard_vs_geo.qzv"
