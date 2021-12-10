include { target_metrics } from './../../modules/qc/main.nf' params(params)

workflow EXOME_QC {

	take:
		bam
		targets
		baits

	main:
		target_metrics( bam, targets.collect(), baits.collect() )

	emit:
		cov_report = target_metrics.out[0]

}
