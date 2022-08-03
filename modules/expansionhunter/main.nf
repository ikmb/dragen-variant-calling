process expansion_hunter {

	label 'expansion_hunter'

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/expansions", mode: 'copy'

	input:
	tuple val(meta),val(bam),val(bai)
	path(catalog)

	output:
	tuple val(meta),path(report)
	path expansion_vcf

	script:
	report = meta.patient_id + "_" + meta.sample_id + ".expansion_report.json"
	expansion_vcf = meta.patient_id + "_" + meta.sample_id + ".expansion_report.vcf"
	prefix = meta.patient_id + "_" meta.sample_id + ".expansion_report"

	"""
		ExpansionHunter --reads $bam --reference ${params.ref} --variant-catalog $catalog --output-prefix $prefix
	"""

}

process expansion2xlsx {
	
	label 'default'

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/expansions", mode: 'copy'

	input:
	tuple val(meta),file(report)

	output:
	path(expansion_xls)

	script:

	expansion_xls = report.getBaseName() + ".xlsx"

	"""
		expansions2xls.pl --infile $report --outfile $expansion_xls
	"""
}
