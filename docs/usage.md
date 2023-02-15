# Usage information

## Basic execution

A basic command to execute the pipeline will look as follows:

```bash
nextflow run ikmb/dragen-variant-calling --samples Samples.csv --assembly hg38 --exome --kit xGen_v2
```

Information on the command line options are listed in the following:

### Analysis strategies

#### Standard analysis

If you are only interested in single VCFs per sample, you can leave the columns famID, PaternalID, MaternalID, Sex and Phenotype at their defaults (see below for information on how to build the input sample sheet).

#### Joint calling

Joint calling for cohorts produces one VCF file for the entire data set. To enable this, use the `--joint_calling` flag. This is "true" by default. 

#### Trio analysis

For trio analysis `--trio` you have to code your PED like information into the samplesheet.

* famID is used to group samples into a set for trio analysis

* PaternalID is used to specify fatherhood; in a trio analysis, the parents would have a 0 here; the child would list the value from the RGSM column of the father

* MaternalID same principle as for PaternalID

* Sex lists the gender of the sample (1 = male, 2 = female, other = unknown)

* Phenotype lists whether the sample is affected by the phenotype of interest (if any). Allowed values are: 0 = missing, 1 = unaffected, 2 = affected, -9 = missing.

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

If your libraries were sequenced across multiple lanes, specify this via the Lane column. The pipeline will correctly group multi-lane libaries. The samplesheet generator script should take care of this, usually. 

Please note that the names of the final files will use the value you have entered for `RGSM` (sample ID) as their root name. The folder structure users the pattern `indivID/RGSM/RGSM_results`. 

### `--email` [ false (default) | me@somewhere.org ]
Have the pipeline send a report upon completion to this email adress. 

### `--assembly` [ hg38 (default), hg19 ] 
The mapping reference to be used by Dragen. We have two ALT aware versions available - hg38 with haplotypes and decoys (hg38HD) as well as hg19 (came with Dragen). 

### `--exome`
Specifiy that this is an exome analysis - requires '--kit' as well. 

### `--kit` 
For WES samples, the enrichment kit can be specified to enable targetted analysis and QC metrics. The most likely option to use at the CCGA would be 'xGen_v2' or 'xGen_v2_cardio'. the latter contains some custom content for cardiogenetics.

- xGen_v2
- xGen_v2_basic (without cardio spike-in)
- Agilent_v6_utr
- Twist_core (with MT spike-in=

### `--panel`
For practical reasons, it can be desirable to determine the coverage of a discrete set of target genes, such as for a gene panel. The pipeline currently
supports the following panels:

- Dilatative Kardiomyopathie 2022 [cardio_hcm_2022]
- Hypertrophe Kardiomyopathie 2022 [cardio_hcm_2022]
- Arrhythmogene rechtsventrikuläre Kardiomyopathie 2022 [cardio_arvc_2022]
- Non-Compaction Kardiomyopathie [cardio_non_compaction]
- Pulmonale Hypertonie 2021 [cardio_pah_2021]
- Gene Immundefekt AGG Exom 2022 [immundef_agg_exom_2022]
- Gene Immundefekt eoIBD 2022 [immundef_eoibd_exom_2022]
- Gene Immundefekt HGG 2022 [immundef_hgg_exom_2022]
- Gene Immundefekt Agammaglobulinämie (25kb panel) [IMM_AGG]
- Gene Immundefekt Hypogammaglobulinämie (25kb panel) [IMM_HGG]
- Gene Immundefekt großes Panel [IMM]
- Gene Immundefekt intestinal (25kb panel) [IMM_IBD]
- Breast cancer panel [ breast_cancer ]
- Liver disease [ Liver ]
- Intellectual disability [ Intellectual_disability ]

Please note that this will also create additional run metrics, including a per-sample list of target exons that fall below a minimum sequence coverage.

### `--all_panels`
This is a short-cut function to enable the production of statistics for all currently defined panels (for a given reference assembly!). Mutually exclusive with `--panel` and `--panel_intervals`.

### `--panel_intervals`
This option allows the user to run non-defined panels. Must be in picard interval list format and match the sequence dictionary of the
genome assembly to run against (use with care!!!). Usually, you would start with a target list in BED format and convert this into an interval list
using the Picard Tools "BedToIntervalList" command.

## Optional analyses

### `--clingen` [ false(default) | true ]
Enable targeted calling routines for clinicallly relevant genes. This option only works with WGS data (i.e. not when specifiying --exome). 

### `--vep` [ true | false (default) ]
Run the Variant Effect Predictor.

### `--expansion_hunter` [ true (default) | false ]
Run the Expansion Hunter software. 

### `--hla` [ false (default) | true ]
Enable HLA calling (class I only). 

## Special options (need more testing, not to be used in production)

### `--cnv` [ true | false (default) ]
Enable CNV calling. This option works best with WGS data where self-normalization works adequately. For Exome data, it is 
recommended to configure a curated panel of normals. This currently only exists for the xGen_v2 kit in combination with the hg38 reference assembly. All other exome analyses will perform self-normalization, if cnv calling is requested.

###  `--sv` [ true | false (default) ]
Enable structural variant calling. This is only recommended for WGS data.

### `--ml` [ true (default) | false ]
Use ML filter instead of built-in hard filtering only. Only available for hg38. 

## Expert options

### `--dragen_unit_cost` [ 0.13 ]
The price for processing of 1Gb of data on the Dragen system in Euros. This is derived from the cost for buying a given processing capacity. 
