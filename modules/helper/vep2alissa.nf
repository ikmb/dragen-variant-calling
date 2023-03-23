process VEP2ALISSA {

	tag "${meta.patient_id}|${meta.sample_id}"

	input:
	tuple val(meta),path(vcf)

	output:
	tuple val(meta),path(alissa_vcf), emit: vcf

	script:
	alissa_vcf = meta.sample_id + ".alissa2vep.vcf"

	"""
		vep2alissa.pl --infile $vcf > $alissa_vcf
	"""
    
}
