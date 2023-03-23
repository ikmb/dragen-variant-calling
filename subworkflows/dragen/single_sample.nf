include { MAKE_VCF } from './../../modules/dragen/make_vcf'
include { HTSLIB_BGZIP_INDEX  } from "./../../modules/htslib/bgzip_index"
include { BCFTOOLS_ADD_HEADER } from "./../../modules/bcftools/add_header"
include { STAGE_FILE } from "./../../modules/helper/stage_file"
include { MANTA2ALISSA } from "./../../modules/helper/manta2alissa"
include { TABIX } from "./../../modules/htslib/tabix"

// reads in, vcf out
workflow DRAGEN_SINGLE_SAMPLE {

	take:
		reads
		bed
		samplesheet

	main:

		MAKE_VCF(
			reads.map {m,l,r ->
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
			MANTA2ALISSA(
				MAKE_VCF.out.sv
			)
			HTSLIB_BGZIP_INDEX(
				MANTA2ALISSA.out.vcf,
				"${params.outdir}/ALISSA"
			)
		}

		if (params.cnv) {
			ch_secondary = ch_secondary.mix(MAKE_VCF.out.cnv)
		}

		STAGE_FILE(
			ch_secondary,
			"${params.outdir}/ALISSA"
		)		
	
		TABIX(
			MAKE_VCF.out.vcf
		)

		BCFTOOLS_ADD_HEADER(
			TABIX.out.vcf
		)

	emit:
		vcf = BCFTOOLS_ADD_HEADER.out.vcf
		bam = MAKE_VCF.out.bam
		vcf_sample = BCFTOOLS_ADD_HEADER.out.vcf
		dragen_logs = MAKE_VCF.out.log
		qc = MAKE_VCF.out.qc
}
