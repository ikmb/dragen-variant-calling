include { PANEL_COVERAGE } from "./../../modules/picard/main.nf" params(params)
include { MULTIQC_PANEL } from "./../../modules/multiqc/main.nf" params(params)

workflow PANEL_QC {

	take:
		bam
		panels
		targets

	main:
		PANEL_COVERAGE(bam.combine(panels),targets.collect())
		MULTIQC_PANEL(PANEL_COVERAGE.out[0])
	

	emit:
		qc = MULTIQC_PANEL.out

}
	
