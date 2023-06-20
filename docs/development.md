# Development guide

# Overview

[The code](#the-code)
[The workflow](#understanding-the-workflow)
[CNV panel of normals](#creating-cnv-panels)

# The code

This pipelines uses Nextflow [DSL2](https://www.nextflow.io/docs/latest/dsl2.html) code conventions. The general structure can be broken down as follows:

- `main.nf` is the entry into the pipeline. It loads some library files and calls the actual workflow in `workflows/dragen.nf``
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

# Creating CNV panels

CNV panels must be re-computed if any of the following components are changed:

- The Dragen reference
- The Dragen version
- The exome kit
- The sequencing instrument/technology

The firs two points do not require fresh sequencing data. If however a new generation of sequencer was used or the exome kit was in some way changed (i.e. new version), new data must be produced first!

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

This pipeline is strictly version controlled; this also means the reference that are used. Please note therefore that updates you make to the panel-of-normals exists only from the point at which it was introduced into the code base. You will not be able run an older version of the pipeline on new data with your updated panel-of-normals being used automatically. In such a scenario, you must provide your PoN via the command line option `--cnv_panel`. 

