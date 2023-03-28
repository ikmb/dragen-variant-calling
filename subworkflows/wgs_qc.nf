include { MOSDEPTH } from "./../modules/mosdepth"

workflow WGS_QC {

	take:
		bam
		bed

	main:
		MOSDEPTH(
            bam,
            bed.collect()
        )

	emit:
		cov_report = MOSDEPTH.out.report

}
