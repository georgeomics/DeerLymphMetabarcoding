# White-Tailed Deer Lymph Node Metabarcoding Pipeline
Manuscript *"Exploring Retropharyngeal Lymph Node Metabarcoding as a Tool for Characterizing Microbial Signatures in White-Tailed Deer from Urban and Non-Urban Areas"* available at Stacks Journal.

# Overview
Below is a brief outline regarding the steps completed for this project:

* Create Manifest
    * Creates QIIME2 manifest from the raw FASTQ files
    * Links each sample ID to its forward and reverse FASTQ files
* Quality Control
    * Import raw reads into QIIME2
    * Summarize sequencing quality/read depth
    * Remove primer and adapter sequences
* Merge
    * Run DADA2 to clean up paired reads
    * Remove low quality sequences
    * Join forward and reverse reads
    * Generate final ASV table and representative sequences
* Decontamination
    * Use negative controls to identify contaminants and remove contaminant ASVs
* Classification
    * Assign taxonomy to Amplicon Sequence Variants (ASVs) using the SILVA reference database
    * Removes mitochondrial/chloroplast sequences to retain bacterial taxa
* Diversity Analysis
    * Generate the phylogenetic tree
    * Generate rarefaction curves
    * Calculate alpha- and beta-diversity metrics
    * Mantel tests
    * Sex/age comparisons

# 1. Create Manifest (`create_manifest.awk`)

Make a manifest for the files using awk in vim named "prepare_manifest.awk" within the scripts directory.

Generates the QIIME2 paired-end manifest (manifest.tsv) from your raw FASTQ filenames so QIIME can import demultiplexed paired reads. The manifest is a table that tells QIIME2:

Each sample ID
The absolute filepath to its forward reads (R1)
The absolute filepath to its reverse reads (R2)
QIIME2 uses this file during qiime tools import to correctly associate read pairs with samples without relying on directory structure.

To run, use the format: $ `ls -1 raw_data/ | awk -v wd="$(pwd)/raw_data/" -f scripts/prepare_manifest.awk - > manifest.tsv`

# 2. Quality Control (`qiime_qc.sh`)

* Imports paired-end reads into a QIIME2 artifact (`.qza`)
* Generates initial demux summaries (`.qzv`) for QC inspection
* Trims primers with cutadapt and summarizes again
  * Essentially a “ingest + primer removal + sanity check” step before denoising/ASV inference.

The following are the primer sequences to be removed with Cutadapt:  
* Forward: TCGTCGGCAGCGTCAGATGTGTATAAGAGACAGCCTACGGGNGGCWGCAG  
* Reverse: GTCTCGTGGGCTCGGAGATGTGTATAAGAGACAGGACTACHVGGGTATCTAATCC
* Cutadapt flag meanings:
    * Adapter f: reverse compliment of reverse primer
    * Front f: front primer in 5’ to 3
    * Adapter R: reverse compliment of forward primer
    * Front R: reverse primer in 5’ to 3
    * --p-discard-untrimmed true (which will discard all sequences that don’t get trimmed) 

# 3. Merge Reads ('qiime_merge.sh')

Runs DADA2 denoising on the primer trimmed paired reads to infer ASVs (Amplicon Sequence Variants)
* Note: This is the core denoise + ASV inference stage that is used in classification and diversity analyses.

Produces:
* Feature table
* Representative sequences
* Denoising stats

Denoising is the step where DADA2 models and removes sequencing/PCR errors from the read data, then collapses reads into exact biological sequence variants (ASVs) instead of broader similarity clusters. Includes:
* Filtering low-quality reads
* Learning an error model from quality scores
* Merging paired reads
* Removing chimeras

Outputs:
* ASV count table per sample
* Representative ASV sequences used downstream for taxonomy/phylogenetic diversity

Note: Make sure to replace `<truncation_length>` with an integer representing the interger each read should be shortened to: `sbatch scripts/qiime_merge.sh qiime_out/preliminary_reads_a_Trimmed.qza qiime_out/preliminary <truncation_length>`

# 4. Decontamination (`qiime_decontam.sh`)
Uses negative control samples to identify likely contaminant ASVs with the prevalence based decontam method
* Removes contaminants using a 0.10 threshold
* Removes the negative control samples from the cleaned feature table

# 5. Classification (`qiime_classify.sh`)
Assigns taxonomy to ASVs using a pretrained classifier (e.g., SILVA), then filters the feature table to the desired taxonomic scope (here: phylum-level, excluding mitochondria/chloroplast), and produces summary tables and taxa barplots
* First you must copy the data base available at https://data.qiime2.org/classifiers/sklearn-1.4.2/silva/ (or updated versions) into your working directory 

Silva prefixes are: domain (d__), superkingdom (sk__), kingdom (k__), subkingdom (ks__), superphylum (sp__), phylum (p__), subphylum (ps__), infraphylum (pi__), superclass (sc__), class (c__), subclass (cs__), infraclass (ci__), superorder (so__), order (o__), suborder (os__), superfamily (sf__), family (f__), subfamily (fs__), genus (g__)

# 6. Diversity Analysis

Note that diversity analyses are split across three scripts for the main diversity calculations, spatial/urban analyses, and sex/age comparisons.

## `qiime_analyze.sh`
Builds a phylogeny from representative sequences, generates rarefaction curves, and calculates alpha- and beta-diversity metrics at the given rarefaction depth.

Generates Shannon diversity, observed ASVs, Bray-Curtis dissimilarity, Jaccard distance, and other core diversity outputs
* Tests associations between proportion urban and alpha diversity using Spearman correlations
* Tests associations between proportion urban and beta diversity using PERMANOVA with 999 permutations

## `qiime_distance_short.sh`
Uses sample coordinates to calculate pairwise geographic distances and evaluate spatial patterns in microbial community composition
* Runs Mantel tests comparing geographic distance with Bray-Curtis, Jaccard, and UniFrac distance matrices

## `qiime_sex_age_short.sh`
Tests whether microbial diversity differs by sex and age class after removing samples with missing or unknown group info
* Tests Bray-Curtis and Jaccard beta diversity using PERMANOVA with 999 permutations
* Tests Shannon diversity and observed ASVs among sex and age groups using alpha-diversity group significance tests
Workflow

Note: Run `qiime_analyze.sh` first to generate the phylogeny and diversity outputs used by the downstream scripts
* `qiime_distance.sh` and `qiime_sex_age_short.sh` can then be run using those diversity outputs