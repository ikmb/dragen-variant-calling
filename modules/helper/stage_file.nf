process STAGE_FILE {

	publishDir "${outdir}", mode: 'copy'

	input:
	tuple val(meta),path(vcf),path(tbi)
	val(outdir)

	output:
	tuple val(meta),path(vcf),path(tbi), emit: vcf

	script:
	
	"""
		touch dummy.txt
	"""

}