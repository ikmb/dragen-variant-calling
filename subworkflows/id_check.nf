include { FREEBAYES } from './../modules/freebayes'
include { BCFTOOLS_ANNOTATE } from "./../modules/bcftools/annotate"
include { HTSLIB_BGZIP_INDEX } from "./../modules/htslib/bgzip_index"

workflow ID_CHECK {

	take:
		bams
		bed

	main:

		FREEBAYES(
			bams,
			bed.collect()
		)
		BCFTOOLS_ANNOTATE(
			FREEBAYES.out.vcf,
			"${params.outdir}/logs"
		)
		HTSLIB_BGZIP_INDEX(
			BCFTOOLS_ANNOTATE.out.vcf
		)
		
	emit:
		vcf = HTSLIB_BGZIP_INDEX.out.vcf

}
