include { VEP_ANNOTATE ; VEP2ALISSA } from "./../../modules/vep/main.nf"
include { VCF_COMPRESS ; VCF_COMPRESS as VCF_COMPRESS_VEP } from "./../../modules/vcf/main.nf"

workflow VEP {

	take:
		vcf

	main:
		VEP_ANNOTATE(vcf)
		VCF_COMPRESS_VEP(VEP_ANNOTATE.out.vcf, "${params.outdir}/VEP")
		VEP2ALISSA(VEP_ANNOTATE.out.vcf)
		VCF_COMPRESS(VEP2ALISSA.out.vcf,"${params.outdir}/ALISSA")
	emit:
		vep_vcf = VCF_COMPRESS_VEP.out[0]
		alissa_vcf = VCF_COMPRESS.out[0]
}
