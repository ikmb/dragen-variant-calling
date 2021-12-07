include { make_vcf ; make_gvcf, ; merge_gvcfs ; joint_call  ; trio_call } from './../../modules/dragen/main.nf' params(params)

// reads in, vcf out
workflow dragen_single_sample {

	take:
		reads
		bed

	main:
		make_vcf(reads,bed)

	emit:
		vcf = make_vcf.out[0]
		bam = make_vcf.out[1]

}

// joint calling with multiple samples
workflow dragen_joint_calling {

	take:
		reads
		bed

	main:
		make_gvcf(reads,bed)
		merge_gvcfs(make_gvcf.out[0])
		joint_call(merge_gvcfs.out)

	emit:
		bam = make_gvcf.out[1]
		vcf = joint_call.out[0]
	
}

// joint trio analysis
workflow dragen_trio_calling {

	take:
		reads
		bed
		ped

	main:
		make_gvcf(reads,bed)
		trio_call(make_gvcf.out[0].collect(),bed,ped)

	emit:
		bam = make_gvcf.out[1]
		vcf = trio_call.out[0]

}
