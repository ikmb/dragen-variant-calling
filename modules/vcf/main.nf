process VCF_ANNOTATE {

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/Annotated", mode: 'copy'

	label 'default'

	tag "${meta.sample_id}"

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

process STAGE_VCF {

	label 'default'

	publishDir "${outdir}", mode: 'copy'

	input:
	tuple val(meta),path(vcf),path(tbi)
	val(outdir)

	output:
	tuple val(meta),path(vcf),path(tbi), emit: vcf

	script:
	tbi = vcf + ".tbi"
	
	"""
		touch dummy.txt
	"""

}

process VCF_SPLIT_SEQ {

	label 'default'

	input:
	tuple val(meta),path(vcf)

	each chr from params.chromosomes

	output:
	path(vcf_chr)

	script:
	vcf_chr = vcf.getBaseName() + ".${chr}.vcf.gz"

	"""
		bcftools view -r $chr -O z -o $vcf_chr $vcf
	"""
}

process VCF_INDEX {

	label 'default'

	input:
	tuple val(meta),path(vcf)

	output:
	tuple val(meta),path(vcf),path(tbi), emit: vcf

	script:
	tbi = vcf + ".tbi"

	"""
		tabix $vcf
	"""

}

process VCF_STATS {

	label 'default'

	publishDir "${params.outdir}/logs", mode: 'copy'

        input:
        tuple val(meta),path(vcf),path(tbi)

        output:
        path(vstats), emit: stats

        script:
        vstats = vcf.getBaseName() + ".stats"

        """
                bcftools stats $vcf > $vstats
        """
}

process VCF_BY_SAMPLE {

	label 'gatk'

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/", mode: 'copy'

	input:
	tuple val(meta),path(vcf),path(tbi)
	val(smeta)

	output:
	tuple val(smeta),path(vcf_sample),path(vcf_sample_tbi), emit: vcf

	script:
	vcf_sample = smeta.sample_id + ".vcf.gz"
	vcf_sample_tbi = vcf_sample + ".tbi"

	"""
		gatk SelectVariants --remove-unused-alternates --exclude-non-variants -V $vcf -sn ${smeta.sample_id} -O variants.vcf.gz -OVI
                gatk LeftAlignAndTrimVariants -R $params.ref -V variants.vcf.gz -O $vcf_sample -OVI

	"""

}

process VCF_ADD_HEADER {

	label 'default'

        publishDir "${params.outdir}/Variants", mode: 'copy'

        input:
        tuple val(meta),file(vcf),file(tbi)

        output:
        tuple val(meta),file(vcf_r),file(tbi_r), emit: vcf

        script:

        vcf_r = vcf.getBaseName() + ".final.vcf.gz"
        tbi_r = vcf_r + ".tbi"

        """
                echo "##reference=${params.vep_assembly}" > header.txt
                bcftools annotate -h header.txt -O z -o $vcf_r $vcf
                tabix $vcf_r
        """

}

process VCF_COMPRESS {

	label 'default'

	publishDir "${outdir}", mode: 'copy'

	input:
	tuple val(meta),path(vcf)
	val(outdir)

	output:
	tuple val(meta),path(vcf_gz),path(vcf_gz_tbi), emit: vcf

	script:
	vcf_gz = vcf + ".gz"
	vcf_gz_tbi = vcf_gz + ".tbi"

	"""
		bgzip $vcf
		tabix $vcf_gz
	"""

}
