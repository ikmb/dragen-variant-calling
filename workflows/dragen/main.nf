include { make_vcf ; make_gvcf ; merge_gvcfs ; joint_call  ; trio_call } from './../../modules/dragen/main.nf' params(params)

// reads in, vcf out
workflow DRAGEN_SINGLE_SAMPLE {

	take:
		reads
		bed

	main:
		make_vcf(reads.groupTuple(by: [0,1]),bed.collect())

	emit:
		vcf = make_vcf.out[0]
		bam = make_vcf.out[1]

}

// joint calling with multiple samples
workflow DRAGEN_JOINT_CALLING {

	take:
		reads
		bed

	main:
		make_gvcf(reads.groupTuple(by: [0,1]),bed.collect())
		merge_gvcfs(make_gvcf.out[0])
		joint_call(merge_gvcfs.out)

	emit:
		bam = make_gvcf.out[1]
		vcf = joint_call.out[0]
	
}

// joint trio analysis
workflow DRAGEN_TRIO_CALLING {

	take:
		reads
		bed
		ped

	main:
		make_gvcf(reads.groupTuple(by: [0,1]),bed.collect())
		trio_call(make_gvcf.out[0].collect(),bed,ped)

	emit:
		bam = make_gvcf.out[1]
		vcf = trio_call.out[0]

}
