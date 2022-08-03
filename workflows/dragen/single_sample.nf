include { make_vcf } from './../../modules/dragen/make_vcf.nf'
include { vcf_add_header ; vcf_index } from "./../../modules/vcf/main.nf"

// reads in, vcf out
workflow DRAGEN_SINGLE_SAMPLE {

	take:
		reads
		bed
		samplesheet
	main:
		make_vcf(reads.map {m,l,r ->
				def new_meta =  [:]
				new_meta.patient_id = m.patient_id
	                        new_meta.sample_id = m.sample_id
				tuple(new_meta,l,r)
			}.groupTuple(),
			bed.collect(),
			samplesheet.collect()
		)
		vcf_index(make_vcf.out.vcf)
		vcf_add_header(vcf_index.out)
	emit:
		vcf = vcf_add_header.out.vcf
		bam = make_vcf.out.bam
		vcf_sample = vcf_add_header.out
		dragen_logs = make_vcf.out.log
		qc = make_vcf.out.qc
}
