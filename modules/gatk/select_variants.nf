process GATK_SELECT_VARIANTS {

    tag "${smeta.sample_id}"

	container 'broadinstitute/gatk:4.1.8.1'

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/", mode: 'copy'

	input:
	tuple val(meta),path(vcf),path(tbi)
	val(smeta)

	output:
	tuple val(smeta),path(vcf_sample),path(vcf_sample_tbi), emit: vcf

	script:
	vcf_sample = smeta.sample_id + ".vcf.gz"
	vcf_sample_tbi = vcf_sample + ".tbi"

	"""
		gatk SelectVariants --remove-unused-alternates --exclude-non-variants -V $vcf -sn ${smeta.sample_id} -O variants.vcf.gz -OVI
        gatk LeftAlignAndTrimVariants -R $params.ref -V variants.vcf.gz -O $vcf_sample -OVI

	"""

}