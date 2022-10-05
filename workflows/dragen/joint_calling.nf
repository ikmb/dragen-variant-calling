include { MAKE_GVCF } from './../../modules/dragen/make_gvcf'
include { JOINT_CALL } from './../../modules/dragen/joint_call'
include { STAGE_VCF; VCF_COMPRESS; VCF_ADD_HEADER ; VCF_INDEX ; VCF_BY_SAMPLE } from "./../../modules/vcf/main.nf"
include { MANTA2ALISSA } from "./../../modules/helper/manta"
// joint calling with multiple samples
workflow DRAGEN_JOINT_CALLING {

	take:
		reads
		bed
		samplesheet

	main:
		sv_vcfs = Channel.from([])
		MAKE_GVCF(reads.map { m,l,r ->
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
                        //ch_secondary = ch_secondary.mix(MAKE_GVCF.out.sv)
			MANTA2ALISSA(MAKE_GVCF.out.sv)
			VCF_COMPRESS(
				MANTA2ALISSA.out.vcf,
				"${params.outdir}/ALISSA"
			)
                }
                if (params.cnv) {
                        ch_secondary = ch_secondary.mix(MAKE_GVCF.out.cnv)
                }
                STAGE_VCF(ch_secondary,"${params.outdir}/ALISSA")

		JOINT_CALL(
			MAKE_GVCF.out.gvcf.map { m,g -> 
				def new_meta = [:]
				new_meta.patient_id = "JointCalling"
				new_meta.sample_id = "Dragen-JC_${params.run_name}"
				tuple(new_meta,g) 
			}.groupTuple(),
			bed.collect()
		)
		VCF_INDEX(JOINT_CALL.out.vcf)
		VCF_BY_SAMPLE(VCF_INDEX.out.vcf.collect(),MAKE_GVCF.out.sample)
		VCF_ADD_HEADER(VCF_INDEX.out.vcf)
	emit:
		bam = MAKE_GVCF.out.bam
		vcf = VCF_ADD_HEADER.out.vcf
		vcf_sample = VCF_BY_SAMPLE.out
		dragen_logs = MAKE_GVCF.out.log.concat(JOINT_CALL.out.log)
		qc = MAKE_GVCF.out.qc
}
