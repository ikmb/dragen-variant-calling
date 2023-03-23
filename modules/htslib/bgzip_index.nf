process HTSLIB_BGZIP_INDEX {

	tag "${meta.patient_id}|${meta.sample_id}"

	label 'short_serial'

	container 'quay.io/biocontainers/htslib:1.16--h6bc39ce_0'

	publishDir "${outdir}", mode: 'copy'

	input:
	tuple val(meta),path(vcf)
	val(outdir)

	output:
	tuple val(meta),path(vcf_gz),path(vcf_gz_tbi), emit: vcf

	script:
	vcf_gz = vcf + ".gz"
	vcf_gz_tbi = vcf_gz + ".tbi"

	"""
		bgzip $vcf
		tabix $vcf_gz
	"""

}
