# Summary of available outputs

Outputs are written to the folder specified by `--outdir`. Usually, this will be "results". 

Within the results folder, you find:

- [QC Report](#qc)
- [Patient reports](#patient-report)
- [Joint Callset](#joint-callset)
- [Trio Callset](#trio-callset)
- [VEP](#vep)

## QC

<details markdown="1">
<summary>Output files</summary>

- `Summary` 
  - `multiqc_report.html`: The MultiQC report for this analysis

</details>

## Patient Report

<details markdown="1">
<summary>Output files</summary>

- `PatientID/SampleID`
  - `*.bam`: The aligned reads in BAM format (exome analysis)
  - `*.cram` : The aligned reads in CRAM format (WGS analysis)
  - `*.hard-filtered.vcf.gz` : The hard-filtered call set of SNPs and INDELs
  - `SampleID_results`
    - `*.cnv.vcf.gz` : The copy number calls in VCF format (optional)
    - `.sv.vcf.gz` : The structural variant calls in VCF format (optional)
    - `.vcf.gz` : The unfiltered callset of SNPs and INDELs
    - `.csv` : Several metrics used to generate the MultiQC report

</details>

## Joint calling

<details markdown="1">
<summary>Output files</summary>

- `JointCalling`
  - `*.hard-filtered.vcf.gz` : The hard-filtered call set of SNPs and INDELs
  - `*.vcf.gz` : The unfiltered callset of SNPs and INDELs
  - `.csv` : Several metrics used to generate the MultiQC report

</details>

## Trio calling

<details markdown="1">
<summary>Output files</summary>

- `TrioCall/results`
  - `*.hard-filtered.vcf.gz` : The hard-filtered call set of SNPs and INDELs
  - `*.vcf.gz` : The unfiltered callset of SNPs and INDELs
  - `.csv` : Several metrics used to generate the MultiQC report

</details>

## VEP

<details markdown="1">
<summary>Output files</summary>

- `VEP`
  - `*.vep.vcf.gz` - The VEP annotated (multi-sample) VCF file
  - `*.alissa2vep.vcf.gz` - The Alissa-compatible annotated VCF file

</details>

