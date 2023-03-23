process MANTA2ALISSA {

	container 'docker://quay.io/biocontainers/ruby-dna-tools:1.0--hdfd78af_3'

	tag "${meta.patient_id}|${meta.sample_id}"
	
	input:
	tuple val(meta),path(vcf),path(tbi)

	output:
	tuple val(meta),path(vcf_alissa), emit: vcf

	script:

	vcf_alissa = vcf.getSimpleName() + ".sv2alissa.vcf"

	"""
		zcat $vcf | manta2alissa.rb > ${vcf_alissa} 
	"""

}
