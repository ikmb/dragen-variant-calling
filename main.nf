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
--genome			Assembly version to use (GRCh38)
--exome				This is an exome dataset
--ped				A pedigree file in PED format (see online documentation)
--email                        	Email address to send reports to (enclosed in '')
--run_name			Name of this run

Optional parameters:

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

// validate input options
if (params.kit && !params.exome || params.exome && !params.kit) {
	exit 1, "Exome analysis requires both --kit and --exome"
}

if (!params.genome) {
	exit 1, "Must provide an assembly name (--genome)"
}

params.assembly = "GRCh38"
if (params.genome == "hg19") {
	params.assembly = "GRCh37"
}
// The Dragen index and the matching FASTA sequence
params.dragen_ref_dir = params.genomes[params.genome].dragenidx

params.ref = params.genomes[params.genome].fasta
params.dbsnp = params.genomes[params.genome].dbsnp
params.out_format = "bam"

// Mode-dependent settings
if (params.exome) {

	BED = params.bed ?: params.genomes[params.genome].kits[ params.kit ].bed
        targets = params.bed ?: params.genomes[params.genome].kits[ params.kit ].targets
        baits = params.bed ?: params.genomes[params.genome].kits[ params.kit ].baits

        Channel.fromPath(targets)
                .ifEmpty{exit 1; "Could not find the target intervals for this exome kit..."}
                .set { Targets }

        Channel.fromPath(baits)
                .ifEmpty {exit 1; "Could not find the bait intervals for this exome kit..." }
                .set { Baits }

        Channel.fromPath(file(BED))
        .ifEmpty { exit 1; "Could not find the BED interval file..." }
        .set { BedIntervals }


} else {

	BED = params.bed ?: params.genomes[params.genome].bed
	params.out_format = "cram"

	Targets = Channel.empty()
	Baits = Channel.empty()
	BedIntervals = Channel.empty()

} 

if (params.ped) {

	Channel.fromPath(params.ped)
		.ifEmpty { exit 1; "Could not find the PED file..." }
		.set { PedFile }
}

// import workflows
include { EXOME_QC } from "./workflows/qc/main.nf" params(params)
include { DRAGEN_SINGLE_SAMPLE ; DRAGEN_TRIO_CALLING ; DRAGEN_JOINT_CALLING } from "./workflows/dragen/main.nf" params(params)
include { VEP } from "./workflows/vep/main.nf" params(params)

// Input channels
Channel.fromPath( file(params.ref) )
	.ifEmpty { exit 1; "Ref fasta file not found, exiting..." }
	.set { ref_fasta }
 
Channel.from(file(params.samples))
       	.splitCsv(sep: ';', header: true)
	.map{ row-> tuple(row.IndivID,row.SampleID,file(row.R1),file(row.R2)) }
	.set { Reads }

// Console reporting
log.info "---------------------------"
log.info "Variant calling DRAGEN"
log.info " - Version ${workflow.manifest.version} -"
log.info "---------------------------"
log.info "Assembly:     	${params.genome}"
log.info "Intervals:	${BED}"
if (params.exome) {
	log.info "Mode:		Exome"
	log.info "Kit:		${params.kit}"
} else {
	log.info "Mode:		WGS"
}
if (params.ped) {
	log.info "Pedigree file		${params.ped}"
}
log.info "CNV calling:	${params.cnv}"
log.info "SV calling:	${params.sv}"

workflow {

	main:

	if (params.joint_calling) {
		if (params.ped) {
			DRAGEN_TRIO_CALLING(Reads,BedIntervals,PedFile)
			vcf = DRAGEN_TRIO_CALLING.out.vcf
			bam = DRAGEN_TRIO_CALLING.out.bam
		} else {	
			DRAGEN_JOINT_CALLING(Reads,BedIntervals)
			vcf = DRAGEN_JOINT_CALLING.out.vcf
			bam = DRAGEN_JOINT_CALLING.out.bam
		}
	} else {
		DRAGEN_SINGLE_SAMPLE(Reads,BedIntervals)
		vcf = DRAGEN_SINGLE_SAMPLE.out.vcf
		bam = DRAGEN_SINGLE_SAMPLE.out.bam
	}


	if (params.vep) {
 	       VEP(vcf)
	}

	if (params.exome) {	
		EXOME_QC(bam,Targets,Baits)
	}

}
