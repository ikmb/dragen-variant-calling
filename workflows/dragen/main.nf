include { make_vcf ; make_gvcf  ; joint_call  ; trio_call } from './../../modules/dragen/main.nf' params(params)
include { vcf_add_header ; vcf_index ; vcf_by_sample } from "./../../modules/vcf/main.nf" params(params)

// reads in, vcf out
workflow DRAGEN_SINGLE_SAMPLE {

	take:
		reads
		bed
		samplesheet
	main:
		make_vcf(reads.groupTuple(by: [0,1,2]),bed.collect(),samplesheet.collect())
		vcf_index(make_vcf.out.vcf)
		vcf_add_header(vcf_index.out)
	emit:
		vcf = vcf_add_header.out
		bam = make_vcf.out.bam
		vcf_sample = vcf_add_header.out
		dragen_logs = make_vcf.out.log
		qc = make_vcf.out.qc
}

// joint calling with multiple samples
workflow DRAGEN_JOINT_CALLING {

	take:
		reads
		bed
		samplesheet

	main:
		make_gvcf(reads,bed.collect(),samplesheet.collect())
		joint_call(make_gvcf.out.gvcf_no_fam.collect(),bed.collect())
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

// joint trio analysis
workflow DRAGEN_TRIO_CALLING {

	take:
		reads
		bed
		samplesheet

	main:
		make_gvcf(reads,bed.collect(),samplesheet.collect())
		trio_call(make_gvcf.out.gvcf.groupTuple(by: 0),bed.collect(),samplesheet.collect())
		vcf_index(trio_call.out.vcf)
		vcf_by_sample(vcf_index.out.collect(),make_gvcf.out.sample)
		vcf_add_header(vcf_index.out)
	emit:
		bam = make_gvcf.out.bam
		vcf = vcf_add_header.out
		vcf_sample = vcf_by_sample.out[0]
		dragen_logs = make_gvcf.out.log.concat(trio_call.out.log)
		qc = make_gvcf.out.qc

}
