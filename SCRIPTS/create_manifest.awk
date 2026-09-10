# Set the input directory and output manifest file
input_dir="/home/ge199066/projects/deer_metabarcoding/DATA/AllRawFiles"
output_manifest="/home/ge199066/projects/deer_metabarcoding/metadata/manifest.tsv"

# Header
printf "sample-id\tforward-absolute-filepath\treverse-absolute-filepath\n" > "$output_manifest"

# Build manifest
ls "$input_dir"/*.fastq.gz | awk -v dir="$input_dir" '
  /_R1_/ {
    fn = $0
    gsub(/^.*\//, "", fn)

    sample_id = fn
    sub(/_.*/, "", sample_id)   # keep only "3-9" or "Z-17" (everything before first underscore)

    forward_read = dir "/" fn
    reverse_read = forward_read
    sub(/_R1_/, "_R2_", reverse_read)

    print sample_id, forward_read, reverse_read
  }' OFS="\t" >> "$output_manifest"