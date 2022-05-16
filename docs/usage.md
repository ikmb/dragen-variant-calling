# Usage information

## Basic execution

A basic command to execute the pipeline will look as follows:

```bash
nextflow run ikmb/dragen-variant-calling --samples Samples.csv --assembly hg38 --exome --kit xGen_v2
```

Information on the command line options are listed in the following:

## Options

### `--samples` [ CSV file (mandatory ]
A samplesheet including information about the read files. The easiest way to generate this file is the included [script](../bin/dragen_samplesheet.pl):

```bash
perl dragen_samplesheet.pl --folder "/path/to/reads/" > Samples.csv
```

This script assumes the current naming convention for Illumina paired-end read files generated at the CCGA. If this is not the case, you may have to produce this file "manually":

```bash
famID,indivID,RGID,RGSM,RGLB,Lane,Read1File,Read2File,PaternalID,MaternalID,Sex,Phenotype
FAM1,I33977-L2,HHNVKDRXX.2.I33977-L2,I33977-L2,I33977-L2,2,/work_ifs/sukmb352/projects/exomes/SF_Exome-Val_IDTv2_01/data/I33977-L2_S59_L002_R1_001.fastq.gz,/work_ifs/sukmb352/projects/exomes/SF_Exome-Val_IDTv2_01/data/I33977-L2_S59_L002_R2_001.fastq.gz,0,0,other,0
```

If your libraries were sequenced across multiple lanes, specify this via the Lane column. The pipeline will correctly group multi-lanes libaries. The samplesheet generator script should take of this, usually. 

#### Standard analysis

If you are only interested in single VCFs per sample, you can leave the columns famID, PaternalID, MaternalID, Sex and Phenotype at their defaults.

#### Trio analysis

For trio analysis `--trio` you have to code your PED like information into the samplesheet. 

* famID is used to group samples into a set for trio analysis

* PaternalID is used to specify fatherhood; in a trio analysis, the parents would have a 0 here; the child would list the value from the RGSM column of the father

* MaternalID same principle as for PaternalID

* Sex lists the gender of the sample (1 = male, 2 = female, other = unknown)

* Phenotype lists whether the sample is affected by the phenotype of interest (if any). Allowed values are: 0 = missing, 1 = unaffected, 2 = affected, -9 = missing. 

### `--assembly` [ hg38 (default), hg19 ] 
The mapping reference to be used by Dragen. We have two ALT aware versions available - hg38 with haplotypes and decoys (hg38HD) as well as hg19 (came with Dragen). 

### `--exome`
Specifiy that this is an exome analysis - requires '--kit' as well. 

### `--kit` 
For WES samples, the enrichment kit can be specified to enable targetted analysis and QC metrics. The most likely option to use at the CCGA would be 'xGen_v2'.

### `--vep` [ true | false (default) ]
Run the Variant Effect Predictor.

### `--expansion_hunter` [ true (default) | false ]
Run the Expansion Hunter software. 

## Special options (need more testing, not to be used in production)

### `--cnv` [ true | false (default) ]
Enable CNV calling. This is currently only recommended for WGS data as there is no built-in way to normalize single-sample exome data sets. 

###  `--sv` [ true | false (default) ]
Enable structural variant calling. This is only recommended for WGS data.

