process FASTQC {

	tag "${meta.patient_id}|${meta.sample_id}"

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/FastQC", mode: 'copy'

	label 'fastqc'

	input:
	tuple val(meta),path(R1),path(R2)

	output:
	tuple val(meta),path("*.html"), emit: html
	tuple val(meta),path("*.zip"), emit: zip

	script:

	"""
		fastqc -t 2 $R1 $R2
	"""

}
	
