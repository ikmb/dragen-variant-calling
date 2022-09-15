include { FREEBAYES } from './../modules/freebayes'
include { VCF_ANNOTATE; VCF_COMPRESS } from './../modules/vcf/main'

workflow ID_CHECK {

	take:
		bams
		bed

	main:

		FREEBAYES(
			bams,
			bed.collect()
		)
		VCF_COMPRESS(
			FREEBAYES.out.vcf,
			"${params.outdir}/logs"
		)
		VCF_ANNOTATE(
			VCF_COMPRESS.out.vcf
		)
		
	emit:
		vcf = FREEBAYES.out.vcf

}
