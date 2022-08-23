include { vep ; vep2alissa } from "./../../modules/vep/main.nf"
include { vcf_compress ; vcf_compress as vcf_compress_vep } from "./../../modules/vcf/main.nf"

workflow VEP {

	take:
		vcf

	main:
		vep(vcf)
		vcf_compress_vep(vep.out.vcf, "${params.outdir}/VEP")
		vep2alissa(vep.out.vcf)
		vcf_compress(vep2alissa.out.vcf,"${params.outdir}/ALISSA")
	emit:
		vep_vcf = vcf_compress_vep.out[0]
		alissa_vcf = vcf_compress.out[0]
}
