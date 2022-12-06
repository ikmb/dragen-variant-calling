include { PANEL_REF_COVERAGE } from "./../../modules/picard/main.nf" params(params)
include { MULTIQC_PANEL } from "./../../modules/multiqc/main.nf" params(params)

workflow PANEL_QC {

	take:
		bam
		panels
		targets

	main:
		PANEL_REF_COVERAGE(bam.combine(panels),targets.collect())
		MULTIQC_PANEL(
			PANEL_REF_COVERAGE.out.coverage.groupTuple()
		)
	
	emit:
		qc = MULTIQC_PANEL.out.report

}
	
