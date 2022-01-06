include { vep ; vep2alissa } from "./../../modules/vep/main.nf" params(params)
include { vcf_compress ; vcf_compress as vcf_compress_vep } from "./../../modules/vcf/main.nf" params(params)

workflow VEP {

	take:
		vcf

	main:
		vep(vcf)
		vcf_compress_vep(vep.out, "${params.outdir}/VEP")
		vep2alissa(vep.out[0])
		vcf_compress(vep2alissa.out,"${params.outdir}/VEP")
	emit:
		vep_vcf = vcf_compress_vep.out[0]
		alissa_vcf = vcf_compress.out[0]
}
