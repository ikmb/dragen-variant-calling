include { MAKE_VCF } from './../../modules/dragen/make_vcf'
include { STAGE_VCF; VCF_COMPRESS; VCF_ADD_HEADER ; VCF_INDEX } from "./../../modules/vcf/main.nf"
include { MANTA2ALISSA } from "./../../modules/helper/manta"
// reads in, vcf out
workflow DRAGEN_SINGLE_SAMPLE {

	take:
		reads
		bed
		samplesheet
	main:
		MAKE_VCF(reads.map {m,l,r ->
				def new_meta =  [:]
				new_meta.patient_id = m.patient_id
	                        new_meta.sample_id = m.sample_id
				tuple(new_meta,l,r)
			}.groupTuple(),
			bed.collect(),
			samplesheet.collect()
		)
		ch_secondary = Channel.from([])

		if (params.sv) {
			ch_secondary = ch_secondary.mix(MAKE_VCF.out.sv)
		}
		if (params.cnv) {
			ch_secondary = ch_secondary.mix(MAKE_VCF.out.cnv)
		}
		stage_vcf(ch_secondary)		
	
		VCF_INDEX(MAKE_VCF.out.vcf)
		VCF_ADD_HEADER(VCF_INDEX.out.vcf)
	emit:
		vcf = VCF_ADD_HEADER.out.vcf
		bam = MAKE_VCF.out.bam
		vcf_sample = VCF_ADD_HEADER.out
		dragen_logs = MAKE_VCF.out.log
		qc = MAKE_VCF.out.qc
}
