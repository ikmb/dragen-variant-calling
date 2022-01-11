include { make_vcf ; make_gvcf ; merge_gvcfs ; joint_call  ; trio_call } from './../../modules/dragen/main.nf' params(params)
include { vcf_add_header ; vcf_index ; vcf_by_sample } from "./../../modules/vcf/main.nf" params(params)

// reads in, vcf out
workflow DRAGEN_SINGLE_SAMPLE {

	take:
		reads
		bed
		samplesheet
	main:
		make_vcf(reads.groupTuple(by: [0,1,2]),bed.collect(),samplesheet.collect())
		vcf_index(make_vcf.out[0])
		vcf_add_header(vcf_index.out)
	emit:
		vcf = vcf_add_header.out
		bam = make_vcf.out[1]
		vcf_sample = vcf_add_header.out
		dragen_logs = make_vcf.out[3]
}

// joint calling with multiple samples
workflow DRAGEN_JOINT_CALLING {

	take:
		reads
		bed
		samplesheet

	main:
		make_gvcf(reads,bed.collect(),samplesheet.collect())
		merge_gvcfs(make_gvcf.out[0].collect(),bed.collect())
		joint_call(merge_gvcfs.out[0].collect(),bed.collect())
		vcf_index(joint_call.out[0])
		vcf_by_sample(vcf_index.out,make_gvcf.out[2])
		vcf_add_header(vcf_index.out)
	emit:
		bam = make_gvcf.out[1]
		vcf = vcf_add_header.out
		vcf_sample = vcf_by_sample.out	
		dragen_logs = make_gvcf.out[4].concat(merge_gvcfs.out[2],joint_call.out[2])
}

// joint trio analysis
workflow DRAGEN_TRIO_CALLING {

	take:
		reads
		bed
		samplesheet

	main:
		make_gvcf(reads,bed.collect(),samplesheet.collect())
		trio_call(make_gvcf.out[0].groupTuple(by: 0),bed.collect(),samplesheet.collect())
		vcf_index(trio_call.out[0])
		vcf_by_sample(vcf_index.out.collect(),make_gvcf.out[2])
		vcf_add_header(vcf_index.out)
	emit:
		bam = make_gvcf.out[1]
		vcf = vcf_add_header.out
		vcf_sample = vcf_by_sample.out[0]
		dragen_logs = make_gvcf.out[4].concat(trio_call.out[2])

}
