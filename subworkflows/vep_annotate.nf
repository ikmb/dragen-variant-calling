include { VEP } from "./../modules/vep.nf"
include { VEP2ALISSA } from "./../modules/helper/vep2alissa"
include { HTSLIB_BGZIP_INDEX ;  HTSLIB_BGZIP_INDEX as HTSLIB_BGZIP_INDEX_VEP } from "./../modules/htslib/bgzip_index"

workflow VEP_ANNOTATE {

	take:
		vcf

	main:
	
		VEP(
			vcf
		)

		HTSLIB_BGZIP_INDEX_VEP(
			VEP.out.vcf, 
			"${params.outdir}/VEP"
		)

		VEP2ALISSA(
			VEP_ANNOTATE.out.vcf
		)

		HTSLIB_BGZIP_INDEX(
			VEP2ALISSA.out.vcf,
			"${params.outdir}/ALISSA"
		)

	emit:
		vep_vcf = HTSLIB_BGZIP_INDEX_VEP.out.vcf
		alissa_vcf = HTSLIB_BGZIP_INDEX.out.vcf
}
