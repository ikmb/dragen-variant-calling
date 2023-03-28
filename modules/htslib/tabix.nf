process TABIX {

	tag "${meta.patient_id}|${meta.sample_id}"

	label 'short_serial'

    container 'quay.io/biocontainers/htslib:1.16--h6bc39ce_0'

	input:
	tuple val(meta),path(vcf)

	output:
	tuple val(meta),path(vcf),path(tbi), emit: vcf

	script:
	tbi = vcf + ".tbi"

	"""
		tabix $vcf
	"""

}