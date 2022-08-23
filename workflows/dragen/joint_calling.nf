include { make_gvcf  } from './../../modules/dragen/make_gvcf'
include { joint_call } from './../../modules/dragen/joint_call'
include { stage_vcf; vcf_compress; vcf_add_header ; vcf_index ; vcf_by_sample } from "./../../modules/vcf/main.nf"
include { MANTA2ALISSA } from "./../../modules/helper/manta"
// joint calling with multiple samples
workflow DRAGEN_JOINT_CALLING {

	take:
		reads
		bed
		samplesheet

	main:
		sv_vcfs = Channel.from([])
		make_gvcf(reads.map { m,l,r ->
                                def new_meta =  [:]
                                new_meta.patient_id = m.patient_id
                                new_meta.sample_id = m.sample_id
                                tuple(new_meta,l,r)
                        }.groupTuple(),
			bed.collect(),
			samplesheet.collect()
		)
		if (params.sv) {
			MANTA2ALISSA(make_gvcf.out.sv)
			vcf_compress(MANTA2ALISSA.out.vcf,"${params.outdir}/ALISSA")
		}
		if (params.cnv) {
			stage_vcf(make_gvcf.out.cnv,"${params.outdir}/ALISSA")
		}
		joint_call(
			make_gvcf.out.gvcf.map { m,g -> 
				def new_meta = [:]
				new_meta.patient_id = "JointCalling"
				new_meta.sample_id = "Dragen-JC"
				tuple(new_meta,g) 
			}.groupTuple(),
			bed.collect()
		)
		vcf_index(joint_call.out.vcf)
		vcf_by_sample(vcf_index.out,make_gvcf.out.sample)
		vcf_add_header(vcf_index.out)
	emit:
		bam = make_gvcf.out.bam
		vcf = vcf_add_header.out
		vcf_sample = vcf_by_sample.out
		dragen_logs = make_gvcf.out.log.concat(joint_call.out.log)
		qc = make_gvcf.out.qc
}
