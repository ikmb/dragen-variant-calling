include { vep ; vep2alissa } from "../../modules/vep/main.nf", params(params)

workflow VEP {

	take:
		vcf

	main:
		vep(vcf)
		vep2alissa(vep.out[0])
	emit:
		vep_vcf = vep.out[0]
		alissa_vcf = vep2alissa.out[0]
}
