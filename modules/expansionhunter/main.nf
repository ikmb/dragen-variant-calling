process expansion_hunter {

	label 'expansion_hunter'

	publishDir "${params.outdir}/${indivID}/${sampleID}/expansions", mode: 'copy'

	input:
	tuple val(indivID),val(sampleID),val(bam),val(bai)
	path(catalog)

	output:
	tuple val(indivID),val(sampleID),path(report)
	path expansion_vcf

	script:
	report = indivID + "_" + sampleID + ".expansion_report.json"
	expansion_vcf = indivID + "_" + sampleID + ".expansion_report.vcf"
	prefix = indivID + "_" + sampleID + ".expansion_report"

	"""
		ExpansionHunter --reads $bam --reference ${params.ref} --variant-catalog $catalog --output-prefix $prefix
	"""

}

process expansion2xlsx {
	
	label 'default'

	publishDir "${params.outdir}/${indivID}/${sampleID}/expansions", mode: 'copy'

	input:
	tuple val(indivID),val(sampleID),file(report)

	output:
	path(expansion_xls)

	script:

	expansion_xls = report.getBaseName() + ".xlsx"

	"""
		expansions2xls.pl --infile $report --outfile $expansion_xls
	"""
}
