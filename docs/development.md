# Development guide

This is a list of helpful pointers to aid in the development of this pipeline. It includes information about the code base as well as the common workflows needed to e.g. roll out new releases or add new references/assets. 
# Overview

[The code](#the-code)

[The workflow](#understanding-the-workflow)

[Release checklist](#release-checklist)

[Gene Panels](#adding-new-gene-panels)

[CNV panel of normals](#creating-cnv-panels)

# The code

This pipelines uses Nextflow [DSL2](https://www.nextflow.io/docs/latest/dsl2.html) code conventions. The general structure can be broken down as follows:

- `main.nf` is the entry into the pipeline. It loads some library files and calls the actual workflow in `workflows/dragen.nf`
- `workflows/dragen.nf` defines the main logic of the pipeline. It sets some key options, reads the samplesheet and calls the various subworkflows and modules
- `subworkflows/` location where self-contained processing chains are defined (also part of the pipeline logic). 
- `modules/` the various process definitions that make up the pipeline
- `conf/` location of the general and site-specific config files
- `conf/resources.config` holds many of the important options about the location of reference files, panel definitions etc
- `assets` holds some of the (smaller) reference files needed by the pipeline, such as exome kit interval lists
- `bin` location of custom scripts needed by some of the pipeline processes
- `doc` the documentation lives here

# Understanding the workflow

The Dragen systems offers an end-to-end processing of raw reads into variant calls of different types (SNPS, Indels, CNVs and SVs). This pipeline in addition performs a range of QC measures and processing of Dragen outputs to make them compatible with downstream diagnostic applications. 

The main logic of this processing chain is defined in [dragen.nf](../workflows/dragen.nf) and should be human-readable. 

In brief:

- A samplesheet is read and turned into a Nextflow channel with a metadata object and raw reads included
- Data is passed forward to the Dragen module - either for single-sample, joint or trio calling (depending on the options provided by the user)
- Within the Dragen module, several things happen
  - The samplesheet is turned into a Dragen-compliant "manifest" (input-csv) based on the read data seen in the process folder (because we can have multiple sets of PE files for one patient, sorting this out beforehand seemed a bit complicated)
  - Optional steps for processing are switched on depending on user-provided options and whether or not the data comes from exome or genome sequencing
  - The actual Dragen process is executed
  - Various specific output items are emitted in dedicated channels 
- VCF files are annotated
- Additional statistics are computed
- Dragen processing logs are collected across all Dragen jobs to summarize the amount of bases used
- A MultiQC report is generated

# Release checklist

Below follow some general points to be mindful of when updating the pipeline and drafting a new release. 

As a general comment, do not change any of the locally "installed" files and their paths, ever. The point of a versioned pipeline is that we should always be able to go back to an old version.
Since not all parts of this pipeline can be included in this code base and must live on the cluster itself, these files should not be touched in any way!!

# Updating software environment and Docker container

This pipeline provisions software packages via Docker containers. These are hard-coded into each [module](../modules/). For most things, we use containers from [Bioconda](https://bioconda.github.io/). However, for the analysis of panel metrics, a pipeline-specific container is built on every push, merge and release of this pipeline using github [workflows](../.github/workflows). 

For releases specifically, please make sure that you

- Update the release version in [nextflow.config](../nextflow.config)
- Update the name of the container in [nextflow.config](../nextflow.config)
- Update the name of the container in [collect_hs_metrics_panels.nf](../modules/picard/collect_hs_metrics_panel.nf)

The version in the container name will correspond to the release you are about to create in github - so something like `1.1`or similar. 
## Updating VEP version

If VEP is updated (und thus the version of EnsEMBL used as the basis for gene models), this necessitates the following changes:

- re-computing all [gene panels](#adding-new-gene-panels), starting from the gene lists under [gene_lists](../assets/panels/gene_lists)
  - all panel reference coverages, for at least 100 BAM files that have been aligned with the to-be-used version of Dragen
- update the VEP [module](../modules/vep.nf) to reflect any necessary syntax changes (if any)
- install the matching local VEP references and plugins - as defined in the site-specific config [file](../conf/diagnostic.config)
  - Download the VEP references from the EnsEMBL [FTP](https://ftp.ensembl.org/pub/release-109/variation/vep/) server and unpack them in the folder specified in the site-specific config
  - Clone the EnsEMBL VEP [plugins](https://github.com/Ensembl/VEP_plugins) repo into the folder specified in the site-specific config and check out the appropriate version
- Add parsing capabilities for any new VEP annotations to the Alissa conversion [script](../bin/vep2allisa.pl)

## Updating exome kit(s)

If you have added a new exome kit, or god forbid, changed an existing one, the following things need to be checked/updated:

- Generate the target BED file as well as a bait and target interval list
  - These files must be 'unpadded', meaning any padding to these regions are added by the pipeline later on
- If needed, compute a new CNV reference panel for this kit (based on data generated with the kit beforehand!)
- Update the [usage](usage.md) documentation to inform users about the new kit and its name

## Updating Dragen version

Well, this is not gonna be fun, because this has very far-reaching implications for various parts of the pipeline....

- Run 100+ samples through the core workflow to produce new BAM files
  - Update all panel [reference coverages](#adding-new-gene-panels)
  - Generate a new [CNV reference panel](#creating-cnv-panels) for all relevant kits (probably only xGenv2)
- Perform validation of resulting variant calls against genome-in-a-bottle

# Adding new gene panels

Gene panels are used to evaluate the sequencing success for a sample based on the coverage of diagnostically relevant genes. To add new gene panels, the following procedure is recommended:

1) Write all [HGNC-compliant](https://www.genenames.org/) gene names in a text file (line by line) and store it in `assets/panels/gene_lists`. If a gene goes by multiple names, you can write them in the same line, separated by ','.

2) Using the [perl script](../bin/ensembl_panel2bed.pl) included with this pipeline, turn the gene list into an exon-level BED file (using only canonical transcripts)

```bash
perl ensembl_panel2bed.pl --infile gene_lists/my_gene_list.txt > hg38/my_gene_list.bed
```

Note that the pipeline will throw an error if one of your genes was not found. This most likely means that you used a name that is not HGNC compliant. Try searching HGNC and/or EnsEMBL for the correct spelling/name.

Please also note that the perl script requires a working installation of the [EnsEMBL API](https://www.ensembl.org/info/docs/api/api_installation.html) to be installed in version 109. You can do this in e.g. a conda environment or directly on the system. Trying to containerize this has sadly not been successful.

3) Convert the BED file into a picard-style interval list using picard tools (picard BedToIntervalList) and store both the bed file and the interval list in the subfolder `assets/panels/hg38`

```bash
picard BedToIntervalList I=my_gene_list.bed O=my_gene_list.interval_list SD=/work_ifs/ikmb_repository/references/dragen/hg38/hg38.fa
```

4) Add the new panel to the resource config file in `conf/resources.config` 

...and update the documentation.

5) Compute reference coverages for this panel and exome kit combination

Reference coverages are configured for each panel - see [resources.config](../conf/resources.config). Obviously, these coverages are not only dependent on the panel, but also the exome kit used. So you need to run this multiple times if you are actively maintaining multiple exome kits in this code base.

These files (.coverages.txt) include information on the mean coverage for each target in a given panel, across a large number of previously sequenced samples (> 100). 

The column structure looks as follows (note that the header column is not included in the actual file):

| target | mean coverage | coverage sample 1 | coverage sample 2 | coverage sample n |
| ------ | ------------- | ----------------- | ----------------- | ----------------- |
| ISG15.ENST00000649529.1 | 89.94642857142857 | 129.0 | 104.0 | 68.5 |

The values are taken from Picard target metrics, using the tool [CollectHsMetrics](../modules/picard/collect_hs_metrics.nf). A terribly simplistic ruby [script](../bin/util/picard_sum_target_coverages.rb) is included that parses a list of such metrics from a folder and combines them into the coverages.txt format required by this pipeline.

Data from such files are [used](../modules/picard/collect_hs_metrics_panel.nf) to annotate gaps in target coverages with meaningful reference values.

# Creating CNV panels

CNV panels must be re-computed if any of the following components are changed:

- The Dragen reference
- The Dragen version
- The exome kit
- The sequencing instrument/technology

The firs two points do not require fresh sequencing data. If however a new generation of sequencer was used or the exome kit was in some way changed (i.e. new version), new data should be produced first!

## Preparation

It is recommended to take at least 50 samples for this process to achieve a reasonable distribution. Preferably, all samples are "known good" meaning they have passed all the typical QC measures, have roughly equal total coverage and are not in some other form "outliers". Samples should also not be biased towards certain genetic diseases but instead come from "normal" controls.

## Producing BAM files

Each sample first needs to be processed from raw reads to BAM format using the [Dragen system](https://support-docs.illumina.com/SW/DRAGEN_v310/Content/SW/DRAGEN/CNVInputs.htm). You can technically just use the pipeline for this, but do not enable `--cnv` or `--sv` and make sure that the correct kit is used (you may have to add it first!).

## Generating target counts

The BAM files generated in the previous step can now be used to compute [target counts](https://support-docs.illumina.com/SW/DRAGEN_v310/Content/SW/DRAGEN/PanelOfNormals.htm).

For exome CNV PoNs, please make sure you provide the matching exome targets in BED format to the [workflow](https://support-docs.illumina.com/SW/DRAGEN_v310/Content/SW/DRAGEN/CNVTargetCounts.htm#Whole)

Note that the pipeline assumes that the panel-of-normal was produced with `--cnv-enable-gcbias-correction true`. 

## Specifying a panel-of-normals

The panel-of-normals can now be provided as a text file listing the full path to all the target counts generated in the previous step from your "normal" BAM references. This is generally done by adding the option `--cnv-normals-list` to the Dragen command. Or in case of this pipeline, either updating the kit specifications under [conf/resources.config](../conf/resources.config) (if this is a permanent change), or through the option `--cnv_panel` from the command line. 

## Caveats

This pipeline is strictly version controlled; this includes (most of) the reference that are used. Please note therefore that updates you make to the panel-of-normals exists only from the point forward at which it was introduced into the code base. You will not be able run an older version of the pipeline on new data with your updated panel-of-normals being used automatically. In such a scenario, you must provide your PoN via the command line option `--cnv_panel` - although you may still run into the issue that the version of the Dragen or its references are then mismatched to your PoN. 

