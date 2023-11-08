include { PICARD_COLLECT_HS_METRICS_PANEL } from "./../modules/picard/collect_hs_metrics_panel" 
include { MULTIQC_PANEL } from "./../modules/multiqc/main.nf"

workflow PANEL_QC {

	take:
		bam
		panels
		targets

	main:

        PICARD_COLLECT_HS_METRICS_PANEL(
            bam.combine(panels),
            targets.collect()
        )
        MULTIQC_PANEL(
            PICARD_COLLECT_HS_METRICS_PANEL.out.coverage.groupTuple()
        )
	
	emit:
        qc = MULTIQC_PANEL.out.html

}
