
include { TRIO_CALL } from './../../modules/dragen/trio_call'
include { MAKE_GVCF } from './../../modules/dragen/make_gvcf'
include { HTSLIB_BGZIP_INDEX  } from "./../../modules/htslib/bgzip_index"
include { BCFTOOLS_ADD_HEADER } from "./../../modules/bcftools/add_header"
include { STAGE_FILE } from "./../../modules/helper/stage_file"
include { MANTA2ALISSA } from "./../../modules/helper/manta2alissa"
include { TABIX } from "./../../modules/htslib/tabix"
include { GATK_SELECT_VARIANTS } from "./../../modules/gatk/select_variants"

// joint trio analysis
workflow DRAGEN_TRIO_CALLING {

	take:
		reads
		bed
		samplesheet

	main:
		MAKE_GVCF( 
			reads.map{ m,l,r ->
                def new_meta =  [:]
                new_meta.patient_id = m.patient_id
                new_meta.sample_id = m.sample_id
				new_meta.family_id = m.family_id
                tuple(new_meta,l,r)
            }.groupTuple(),
			bed.collect(),
			samplesheet.collect()
		)
		ch_secondary = Channel.from([])

        if (params.sv) {
            //ch_secondary = ch_secondary.mix(MAKE_GVCF.out.sv)
			MANTA2ALISSA(
				MAKE_GVCF.out.sv
			)
			HTSLIB_BGZIP_INDEX(
				MANTA2ALISSA.out.vcf,
				"${params.outdir}/ALISSA"
			)
        }
        
		if (params.cnv) {
            ch_secondary = ch_secondary.mix(MAKE_GVCF.out.cnv)
        }
		
        STAGE_FILE(
			ch_secondary,
			"${params.outdir}/ALISSA"
		)

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

		TABIX(
			TRIO_CALL.out.vcf
		)
		
		GATK_SELECT_VARIANTS(
			TABIX.out.vcf.collect(),
			MAKE_GVCF.out.sample
		)
		
		BCFTOOLS_ADD_HEADER(
			VCF_INDEX.out.vcf
		)

	emit:
		bam = MAKE_GVCF.out.bam
		vcf = BCFTOOLS_ADD_HEADER.out.vcf
		vcf_sample = GATK_SELECT_VARIANTS.out.vcf
		dragen_logs = MAKE_GVCF.out.log.concat(TRIO_CALL.out.log)
		qc = MAKE_GVCF.out.qc

}
