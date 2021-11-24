# Usage information

## Basic execution

A basic command to execute the pipeline will look as follows:

```bash
nextflow run ikmb/dragen-variant-calling --samples Samples.csv --assembly hg38 --mode wgs --qc
```

Information on the command line options are listed in the following:

## Options

### `--samples` [ CSV file (mandatory ]
A samplesheet including information about the read files. The easiest way to generate this file is the included script `bin/samplesheet_from_folder.rb`:

```bash
ruby samplesheet_from_folder.rb --folder /path/to/reads > Samples.csv
```

This script assumes the current naming convention for Illumina paired-end read files generated at the CCGA. If this is not the case, you may have to produce this file "manually":

```bash
IndivID;SampleID;R1;R2
Patient1;SampleXX;/path/to/reads_R1_001.fastq.gz;/path/to/reads_R2_001.fastq.gz
```

Note that the pipeline will combine fastQ files by sample - in case you ran a libary across multiple lanes. This is done based on IndivID and SampleID columns. 

### `--assembly` [ hg38 (default), hg19 ] 
The mapping reference to be used by Dragen. We have two ALT aware versions available - hg38 with haplotypes and decoys (hg38HD) as well as hg19 (came with Dragen). 

### `--mode` [ wes | wgs ]
The analysis mode to use -  wes = exomes, wgs = whole genomes. This option mostly determined which calling intervalls are used and what kind of metrics are produced. 

### `--kit` 
For WES samples, the enrichment kit can be specified to enable targetted analysis and QC metrics. The most likely option to use at the CCGA would be 'xGen_v2'.

### `--qc` [ true | false (default)]
Whether to generate MultiQC run metrics. If the mode is 'wgs', global coverage stats are produced across all chromosomes. If the mode is 'wes', the 

## Special options (need more testing, not to be used in production)

### `--cnv` [ true | false (default) ]
Enable CNV calling. This is currently only recommended for WGS data as there is no built-in way to normalize single-sample exome data sets. 

###  `--sv` [ true | false (default) ]
Enable structural variant calling. This is only recommended for WGS data.

