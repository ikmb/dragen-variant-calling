process vcf_split_seq {

	label 'default'

	input:
	path(vcf)

	each chr from params.chromosomes

	output:
	path(vcf_chr)

	script:
	vcf_chr = vcf.getBaseName() + ".${chr}.vcf.gz"

	"""
		bcftools view -r $chr -O z -o $vcf_chr $vcf
	"""
}

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

	publishDir "${params.outdir}/logs", mode: 'copy'

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

process vcf_by_sample {

	label 'gatk'

	publishDir "${params.outdir}/${indivID}/${sampleID}/", mode: 'copy'

	input:
	tuple path(vcf),path(tbi)
	tuple val(indivID),val(sampleID)

	output:
	tuple path(vcf_sample),path(vcf_sample_tbi)

	script:
	vcf_sample = sampleID + ".vcf.gz"
	vcf_sample_tbi = vcf_sample + ".tbi"

	"""
		gatk SelectVariants --remove-unused-alternates --exclude-non-variants -V $vcf -sn $sampleID -O variants.vcf.gz -OVI
                gatk LeftAlignAndTrimVariants -R $params.ref -V variants.vcf.gz -O $vcf_sample -OVI

	"""

}

process vcf_add_header {

	label 'default'

        publishDir "${params.outdir}/Variants", mode: 'copy'
        input:
        tuple file(vcf),file(tbi)

        output:
        tuple file(vcf_r),file(tbi_r)

        script:

        vcf_r = vcf.getBaseName() + ".final.vcf.gz"
        tbi_r = vcf_r + ".tbi"

        """
                echo "##reference=${params.vep_assembly}" > header.txt
                bcftools annotate -h header.txt -O z -o $vcf_r $vcf
                tabix $vcf_r
        """

}

process vcf_compress {

	label 'default'

	publishDir "${outdir}", mode: 'copy'

	input:
	path(vcf)
	val(outdir)

	output:
	tuple path(vcf_gz),path(vcf_gz_tbi)

	script:
	vcf_gz = vcf + ".gz"
	vcf_gz_tbi = vcf_gz + ".tbi"

	"""
		bgzip $vcf
		tabix $vcf_gz
	"""

}
