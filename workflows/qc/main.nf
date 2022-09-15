include { TARGET_METRICS ; WGS_METRICS } from './../../modules/qc/main.nf'
include { MULTIQC } from "./../../modules/multiqc/main.nf"

workflow EXOME_QC {

	take:
		bam
		targets
		baits

	main:
		TARGET_METRICS( bam, targets.collect(), baits.collect() )

	emit:
		cov_report = TARGET_METRICS.out[0]

}

workflow WGS_QC {

	take:
		bam
		bed

	main:
		WGS_METRICS(bam,bed.collect())

	emit:
		cov_report = WGS_METRICS.out

}
