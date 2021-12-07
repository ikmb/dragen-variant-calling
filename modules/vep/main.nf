process vep {

	label 'vep'

	publishDir "${params.outdir}/VEP", mode: 'copy'

	input:
	file(vcf) from VepInput

	output:
	set file(vcf_annotated),file(vcf_annotated_alissa)

	script:
	vcf_annotated = vcf.getBaseName() + ".vep.vcf.gz"
	vcf_annotated_alissa = vcf.getBaseName() + ".vep2alissa.vcf.gz"
		
	"""
		
	"""
}
