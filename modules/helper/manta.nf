process MANTA2ALISSA {

	tag "${meta.patient_id}|${meta.sample_id}"
	
	input:
	tuple val(meta),path(vcf)

	output:
	tuple val(meta),path(vcf_alissa), emit: vcf

	script:

	vcf_alissa = vcf.getSimpleName() + ".sv2alissa.vcf"

	"""
		manta2alissa.pl -i ${vcf} -o ${vcf_alissa}
	"""

}
