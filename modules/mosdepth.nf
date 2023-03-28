process MOSDEPTH {

	tag "${meta.patient_id}|${meta.sample_id}"

	label 'medium_parallel'

    container 'quay.io/biocontainers/mosdepth:0.3.3--h37c5b7d_2'

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/Metrics", mode: 'copy'
	
	input:
	tuple val(meta),path(bam),path(bai)
	path(bed)

	output:
	path(genome_global_coverage), emit: report

	script:
	base_name = bam.getBaseName()
	genome_bed_coverage = base_name + ".mosdepth.region.dist.txt"
	genome_global_coverage = base_name + ".mosdepth.global.dist.txt"

	"""
		mosdepth -t ${task.cpus} -n -f ${params.ref} -x -Q 10 -b $bed $base_name $bam
	"""
}
