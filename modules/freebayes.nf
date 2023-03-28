process FREEBAYES {

	tag "${meta.patient_id}|${meta.sample_id}"

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/ID_Check", mode: 'copy'

	label 'medium_serial'

	container 'quay.io/biocontainers/freebayes:1.3.6--h346b5cb_1'

	tag "${meta.patient_id}|${meta.sample_id}"

	input:
	tuple val(meta),path(bam),path(bai)
	path(bed)

	output:
	tuple val(meta),path(vcf), emit: vcf

	script:
	vcf = meta.patient_id + "_" + meta.sample_id + ".id_check.vcf"

	"""
		freebayes -f $params.ref --genotype-qualities --report-monomorphic --min-coverage 5 -t $bed $bam > $vcf
	"""
}
