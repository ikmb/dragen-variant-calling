#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Help message
helpMessage = """
===============================================================================
IKMB DRAGEN pipeline | version ${workflow.manifest.version}
===============================================================================
Usage: nextflow run ikmb/XXX

Required parameters:
--samples			Samplesheet in CSV format (see online documentation)
--assembly			Assembly version to use (GRCh38)
--exome				This is an exome dataset
--email                        	Email address to send reports to (enclosed in '')
--run_name			Name of this run
--trio				Run this as trio analysis

Optional parameters:
--expansion_hunter		Run expansion hunter (default: true)
--vep				Run Variant Effect Predictor (default: true)
--interval_padding		Add this many bases to the calling intervals (default: 10)
--cnv				Enable CNV calling (not recommended for exomes)
--sv				Enable SV calling (not recommended for exomes)

Expert options (usually not necessary to change!):

Output:
--outdir                       Local directory to which all output is written (default: results)
"""

params.help = false

// Show help when needed
if (params.help){
    log.info helpMessage
    exit 0
}

def summary = [:]

if (!params.run_name) {
	exit 1, "Must provide a --run_name!"
}

if (params.joint_calling && params.trio) {
	exit 1, "Cannot specify joint-calling and trio analysis simultaneously"
}
// validate input options
if (params.kit && !params.exome || params.exome && !params.kit) {
	exit 1, "Exome analysis requires both --kit and --exome"
}

if (!params.assembly) {
	exit 1, "Must provide an assembly name (--assembly)"
}

params.assembly = "hg38"
params.chromosomes = [ "chr1", "chr2", "chr3", "chr4", "chr5", "chr6", "chr7", "chr8", "chr9", "chr10", "chr11", "chr12", "chr13", "chr14", "chr15", "chr16", "chr17", "chr18", "chr19", "chr20", "chr21", "chr22", "chrX", "chrY", "chrM" ]

if (params.assembly == "hg19") {
	params.vep_assembly = "GRCh37"
}
 
// The Dragen index and the matching FASTA sequence
params.dragen_ref_dir = params.genomes[params.assembly].dragenidx

params.ref = params.genomes[params.assembly].fasta
params.dbsnp = params.genomes[params.assembly].dbsnp

panels = Channel.empty()

params.kill_list = false

// Mode-dependent settings
if (params.exome) {

	BED = params.bed ?: params.genomes[params.assembly].kits[ params.kit ].bed
        targets = params.bed ?: params.genomes[params.assembly].kits[ params.kit ].targets
        baits = params.bed ?: params.genomes[params.assembly].kits[ params.kit ].baits
	params.out_format = "bam"
	params.out_index = "bai"
        Channel.fromPath(targets)
                .ifEmpty{exit 1; "Could not find the target intervals for this exome kit..."}
                .set { Targets }

        Channel.fromPath(baits)
                .ifEmpty {exit 1; "Could not find the bait intervals for this exome kit..." }
                .set { Baits }

	if (params.kill) {
        	params.kill_list = params.kill
	} else if (params.kit && params.genomes[params.assembly].kits[params.kit].kill) {
        	params.kill_list = params.genomes[params.assembly].kits[params.kit].kill
	}

	if (params.panel) {
        	panel = params.genomes[params.assembly].panels[params.panel].intervals
	        panels = Channel.fromPath(panel)
	} else if (params.panel_intervals) {
        	Channel.fromPath(params.panel_intervals)
	        .ifEmpty { exit 1; "Could not find the specified gene panel (--panel_intervals)" }
        	.set { panels }
	} else if (params.all_panels) {
        	panel_list = []
	        panel_names = params.genomes[params.assembly].panels.keySet()
        	panel_names.each {
	                interval = params.genomes[params.assembly].panels[it].intervals
        	        panel_list << file(interval)
	        }
        	panels = Channel.fromList(panel_list)
	}
} else {

	BED = params.bed ?: params.genomes[params.assembly].bed
	params.out_format = "cram"
	params.out_index = "crai"
	Targets = Channel.empty()
	Baits = Channel.empty()
	BedFile = Channel.fromPath(BED)

} 

if (params.expansion_hunter) {
	catalog = params.genomes[params.assembly].expansion_catalog
	Channel.fromPath(catalog)
		.ifEmpty { 1; "Could not find expansion catalog for this assembly" }
		.set { expansion_catalog }
} else {
	expansion_catalog = Channel.empty()
}
 
// import workflows
include { EXOME_QC ; WGS_QC  } from "./workflows/qc/main.nf"
include { DRAGEN_SINGLE_SAMPLE ; DRAGEN_TRIO_CALLING ; DRAGEN_JOINT_CALLING } from "./workflows/dragen/main.nf"
include { VEP } from "./workflows/vep/main.nf"
include { EXPANSION_HUNTER } from "./workflows/expansion_hunter/main.nf"
include { intervals_to_bed } from "./modules/intervals/main.nf"
include { vcf_stats } from "./modules/vcf/main.nf"
include { validate_samplesheet } from "./modules/qc/main.nf"
include { multicqc } from "./modules/multiqc/main.nf"
include { dragen_usage } from "./modules/logging/main.nf"
include { SOFTWARE_VERSIONS } from "./workflows/versions/main.nf"
include { PANEL_QC } from "./workflows/panels/main.nf"
  
// Input channels
Channel.fromPath( file(params.ref) )
	.ifEmpty { exit 1; "Ref fasta file not found, exiting..." }
	.set { ref_fasta }

Channel.fromPath(params.samples)
	.splitCsv(sep: ',', header: true)
	.map { row -> tuple(row.famID,row.indivID,row.RGSM,file(row.Read1File, checkIfExists: true),file(row.Read2File, checkIfExists: true)) }
	.set { Reads }
  
Channel.fromPath(params.samples)
	.set { Samplesheet }
 
// Console reporting
log.info "---------------------------"
log.info "Variant calling DRAGEN"
log.info " - Version ${workflow.manifest.version} -"
log.info "---------------------------"
log.info "Assembly:     	${params.assembly}"
log.info "Intervals:	${BED}"
if (params.exome) {
	log.info "Mode:		Exome"
	log.info "Kit:		${params.kit}"
} else {
	log.info "Mode:		WGS"
}
log.info "Align format:	${params.out_format}"
log.info "Trio mode:	${params.trio}"
log.info "CNV calling:	${params.cnv}"
log.info "SV calling:	${params.sv}"

workflow {

	main:

	SOFTWARE_VERSIONS()
	versions = SOFTWARE_VERSIONS.out.yaml

	// rudementary check of samplesheet validity before we run Dragen	
	validate_samplesheet(Samplesheet)
	samples = validate_samplesheet.out

	if (params.exome) {
		intervals_to_bed(Targets)
		BedIntervals = intervals_to_bed.out
	} else {
		BedIntervals = BedFile
	}

	if (params.joint_calling) {
		DRAGEN_JOINT_CALLING(Reads,BedIntervals,samples)
		vcf = DRAGEN_JOINT_CALLING.out.vcf
		bam = DRAGEN_JOINT_CALLING.out.bam
		vcf_sample = DRAGEN_JOINT_CALLING.out.vcf_sample
		dragen_logs = DRAGEN_JOINT_CALLING.out.dragen_logs
	} else if (params.trio) {
			DRAGEN_TRIO_CALLING(Reads,BedIntervals,samples)
                vcf = DRAGEN_TRIO_CALLING.out.vcf
                bam = DRAGEN_TRIO_CALLING.out.bam
		vcf_sample = DRAGEN_TRIO_CALLING.out.vcf_sample
		dragen_logs = DRAGEN_TRIO_CALLING.out.dragen_logs
	} else {
		DRAGEN_SINGLE_SAMPLE(Reads,BedIntervals,samples)
		vcf_sample = DRAGEN_SINGLE_SAMPLE.out.vcf
		vcf = DRAGEN_SINGLE_SAMPLE.out.vcf
		bam = DRAGEN_SINGLE_SAMPLE.out.bam
		dragen_logs = DRAGEN_SINGLE_SAMPLE.out.dragen_logs
	}

	if (params.expansion_hunter) {
		EXPANSION_HUNTER(bam,expansion_catalog)
	}

	if (params.vep) {
 	       VEP(vcf)
	}

	if (params.exome) {	
		EXOME_QC(bam,Targets,Baits)
		coverage = EXOME_QC.out.cov_report
		PANEL_QC(bam,panels,Targets)
	} else {
		WGS_QC(bam,BedIntervals)
		coverage = WGS_QC.out.cov_report
	} 

	vcf_stats(vcf_sample)
	
	dragen_usage(dragen_logs.collect())

	multiqc(vcf_stats.out.concat(coverage,versions,dragen_usage.out).collect())	
}
