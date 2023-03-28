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
		HTSLIB_BGZIP_INDEX(
			FREEBAYES.out.vcf,
			"${params.outdir}/logs"
		)
		BCFTOOLS_ANNOTATE(
			HTSLIB_BGZIP_INDEX.out.vcf
		)
		
	emit:
		vcf = HTSLIB_BGZIP_INDEX.out.vcf

}
