include { PICARD_COLLECT_HS_METRICS } from "./../modules/picard/collect_hs_metrics"

workflow EXOME_QC {

	take:
		bam
		targets
		baits

	main:
		PICARD_COLLECT_HS_METRICS( 
            bam, 
            targets.collect(), 
            baits.collect() 
        )

	emit:
		cov_report = PICARD_COLLECT_HS_METRICS.out.report

}