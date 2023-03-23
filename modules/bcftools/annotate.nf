process BCFTOOLS_ANNOTATE {

	tag "${meta.patient_id}|${meta.sample_id}"

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/Annotated", mode: 'copy'

	label 'short_serial'

    container 'quay.io/biocontainers/bcftools:1.14--hde04aa1_1'

	input:
	tuple val(meta),path(vcf),path(tbi)

	output:
	tuple val(meta),path(vcf_a),path(tbi_a), emit: vcf

	script:
	vcf_a = vcf.getSimpleName() + ".annotated.vcf.gz"
	tbi_a = vcf_a + ".tbi"

	"""
		bcftools annotate -a $params.dbsnp -c ID -o $vcf_a $vcf
		bcftools index -t $vcf_a 
	"""

} 