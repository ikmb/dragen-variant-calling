include { PANEL_COVERAGE } from "./../../modules/picard/main.nf" params(params)
include { multiqc_panel } from "./../../modules/multiqc/main.nf" params(params)

workflow PANEL_QC {

	take:
		bam
		panels
		targets

	main:
		PANEL_COVERAGE(bam.combine(panels),targets.collect())
		multiqc_panel(PANEL_COVERAGE.out[0])
	

	emit:
		qc = multiqc_panel.out

}
	
