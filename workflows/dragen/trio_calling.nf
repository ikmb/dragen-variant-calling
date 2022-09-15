include { MAKE_GVCF } from './../../modules/dragen/make_gvcf'
include { TRIO_CALL } from './../../modules/dragen/trio_call'
include { STAGE_VCF; VCF_ADD_HEADER ; VCF_INDEX ; VCF_BY_SAMPLE; VCF_COMPRESS } from "./../../modules/vcf/main.nf"
include { MANTA2ALISSA } from "./../../modules/helper/manta"
// joint trio analysis
workflow DRAGEN_TRIO_CALLING {

	take:
		reads
		bed
		samplesheet

	main:
		MAKE_GVCF( reads.map{ m,l,r ->
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
                        ch_secondary = ch_secondary.mix(MAKE_GVCF.out.sv)
                }
                if (params.cnv) {
                        ch_secondary = ch_secondary.mix(MAKE_GVCF.out.cnv)
                }
                STAGE_VCF(ch_secondary)

		TRIO_CALL(
			MAKE_GVCF.out.gvcf.map { m,g ->
				def trio_meta = [:]
				trio_meta.family_id = m.family_id
				trio_meta.patient_id = "TrioCalling"
                                trio_meta.sample_id = "Dragen-TC"
				tuple(trio_meta,g)
			}.groupTuple(),
			bed.collect(),
			samplesheet.collect()
		)
		VCF_INDEX(TRIO_CALL.out.vcf)
		VCF_BY_SAMPLE(VCF_INDEX.out.vcf.collect(),MAKE_GVCF.out.sample)
		VCF_ADD_HEADER(VCF_INDEX.out.vcf)
	emit:
		bam = MAKE_GVCF.out.bam
		vcf = VCF_ADD_HEADER.out.vcf
		vcf_sample = VCF_BY_SAMPLE.out.vcf
		dragen_logs = MAKE_GVCF.out.log.concat(TRIO_CALL.out.log)
		qc = MAKE_GVCF.out.qc

}
