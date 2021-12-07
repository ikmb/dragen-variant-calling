#!/usr/bin/env nextflow

// Help message
helpMessage = """
===============================================================================
IKMB DRAGEN pipeline | version ${params.version}
===============================================================================
Usage: nextflow run ikmb/XXX

Required parameters:
--samples			Samplesheet in CSV format (see online documentation)
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
	exit 1; "Must provide a --run_name!"
}

// validate input options
if (params.kit && !params.exome || params.exome && !params.kit) {
	exit 1, "Exome analysis requires both --kit and --exome"
}

// The Dragen index and the matching FASTA sequence
params.dragen_ref_dir = params.genomes[params.genome].dragen_index_dir
params.ref = params.genomes[params.genome].fasta
params.dbsnp = params.genomes[params.genome].dbsnp

// Mode-dependent settings
if (params.exome) {

	BED = params.bed ?: params.genomes[params.genome].kits[ params.kit ].bed
        out_format = "bam"
        targets = params.bed ?: params.genomes[params.genome].kits[ params.kit ].targets
        baits = params.bed ?: params.genomes[params.genome].kits[ params.kit ].baits

        Channel.fromPath(targets)
                .ifEmpty{exit 1; "Could not find the target intervals for this exome kit..."}
                .set { TargetsToHS }

        Channel.fromPath(baits)
                .ifEmpty {exit 1; "Could not find the bait intervals for this exome kit..." }
                .set { BaitsToHS }

        Channel.fromPath(file(BED))
        .ifEmpty { exit 1; "Could not find the BED interval file..." }
        .set { BedIntervals }


} else {
	BED = params.bed ?: params.genomes[params.genome].bed
	out_format = "cram"

	TargetToHS = Channel.empty()
	BaitsToHS = Channel.empty()
	BedIntervals = Channel.empty()

} 

if (params.ped) {

	ped_file = file(params.bed)
	if (!ped_file.exists()) {
		exit 1, "Could not find the specified PED file"
	}
	PedFile = Channel.fromPath(params.ped)
}

// import workflows

include { dragen_single_sample; dragen_trio_calling; dragen_joint_calling } from './workflows/dragen/main.nf' params(params)
	
// Input channels

Channel.fromPath( file(REF) )
	.ifEmpty { exit 1; "Ref fasta file not found, exiting..." }
	.set { ref_fasta }
 
Channel.from(file(params.samples))
       	.splitCsv(sep: ';', header: true)
	.map{ row-> tuple(row.IndivID,row.SampleID,file(row.R1),file(row.R2)) }
	.set { Reads }

// Console reporting
log.info "Variant calling DRAGEN"
log.info " - devel version -"
log.info "----------------------"
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
log.info "CNV calling:	${params.cnv}"
log.info "SV calling:	${params.sv}"

if (params.joint_calling) {

	if (params.ped) {
		dragen_trio_calling(Reads,BedIntervals,PedFile)
	} else {	
		dragen_joint_calling(Reads,BedIntervals)
	}

} else {

	dragen_single_sample(Reads,BedIntervals)

}
	
