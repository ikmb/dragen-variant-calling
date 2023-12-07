include { PICARD_COLLECT_HS_METRICS_PANEL } from "./../modules/picard/collect_hs_metrics_panel" 
include { MULTIQC_PANEL } from "./../modules/multiqc/main.nf"

workflow PANEL_QC {

	take:
		bam
		panels
		targets

	main:

        ch_bam_panel = bam.combine(panels)

	//ch_bam_panel.view()

        PICARD_COLLECT_HS_METRICS_PANEL(
            ch_bam_panel,
            targets.collect()
        )
        MULTIQC_PANEL(
            PICARD_COLLECT_HS_METRICS_PANEL.out.coverage.groupTuple()
        )
	
	emit:
        qc = MULTIQC_PANEL.out.html

}
