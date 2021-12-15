process vcf_index {

	label 'default'

	input:
	path(vcf)

	output:
	tuple path(vcf),path(tbi)

	script:
	tbi = vcf + ".tbi"

	"""
		tabix $vcf
	"""

}

process vcf_stats {

	label 'default'

        input:
        tuple path(vcf),path(tbi)

        output:
        path(vstats)

        script:
        vstats = vcf.getBaseName() + ".stats"

        """
                bcftools stats $vcf > $vstats
        """
}
