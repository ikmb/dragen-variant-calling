process WHATSHAP {

	label 'medium_serial'

	container 'quay.io/biocontainers/whatshap:1.1--py36hae55d0a_1'
	
	tag "${meta.patient_id}|${meta.sample_id}"

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/Phased", mode: 'copy'

	input:
	tuple val(meta),path(vcf),path(tbi),path(bam),path(bai)

	output:
	tuple val(meta),path(vcf_phased), emit: vcf

	script:

	vcf_phased = vcf.getBaseName() + "_phased.vcf.gz"

	"""
		whatshap phase -o $vcf_phased --reference=${params.ref} --indels $vcf $bam
	"""

}
