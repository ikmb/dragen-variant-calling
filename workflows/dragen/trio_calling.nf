include { make_gvcf } from './../../modules/dragen/make_gvcf'
include { trio_call } from './../../modules/dragen/trio_call'
include { vcf_add_header ; vcf_index ; vcf_by_sample } from "./../../modules/vcf/main.nf"

// joint trio analysis
workflow DRAGEN_TRIO_CALLING {

	take:
		reads
		bed
		samplesheet

	main:
		make_gvcf( reads.map{ m,l,r ->
                                def new_meta =  [:]
                                new_meta.patient_id = m.patient_id
                                new_meta.sample_id = m.sample_id
                                tuple(new_meta,l,r)
                        }.groupTuple(),
			bed.collect(),
			samplesheet.collect()
		)
		trio_call(
			make_gvcf.out.gvcf.map { m,g ->
				def trio_meta = [:]
				trio_meta.family_id = m.family_id
				trio_meta.patient_id = "TrioCalling"
                                trio_meta.sample_id = "Dragen-TC"
				tuple(trio_meta,g)
			}.groupTuple(),
			bed.collect(),
			samplesheet.collect()
		)
		vcf_index(trio_call.out.vcf)
		vcf_by_sample(vcf_index.out.collect(),make_gvcf.out.sample)
		vcf_add_header(vcf_index.out.vcf)
	emit:
		bam = make_gvcf.out.bam
		vcf = vcf_add_header.out.vcf
		vcf_sample = vcf_by_sample.out.vcf
		dragen_logs = make_gvcf.out.log.concat(trio_call.out.log)
		qc = make_gvcf.out.qc

}
