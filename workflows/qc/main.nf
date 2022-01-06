include { target_metrics ; wgs_metrics ; multiqc } from './../../modules/qc/main.nf' params(params)

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

workflow WGS_QC {

	take:
		bam
		bed

	main:
		wgs_metrics(bam,bed.collect())

	emit:
		cov_report = wgs_metrics.out

}
