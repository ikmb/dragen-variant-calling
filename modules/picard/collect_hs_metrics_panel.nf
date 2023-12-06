process PICARD_COLLECT_HS_METRICS_PANEL {

    container 'ikmb/dragen-variant-calling:1.1'

    tag "${meta.sample_id}|${panel_name}"

    publishDir "${params.outdir}/Summary/Panel/PanelCoverage", mode: "copy"

    input:
    tuple val(meta),path(bam),path(bai),val(panel_name),path(panel),val(cov)
    path(targets)

    output:
    tuple val(panel_name),path(coverage), emit: coverage
    tuple val(meta),path(target_coverage_xls)
    path(target_coverage)

    script:
    coverage = "${meta.patient_id}_${meta.sample_id}.${panel_name}.hs_metrics.txt"
    target_coverage = "${meta.patient_id}_${meta.sample_id}.${panel_name}.per_target.hs_metrics.txt"
    target_coverage_xls = "${meta.patient_id}_${meta.sample_id}.${panel_name}.per_target.hs_metrics_mqc.xlsx"

    def options = ""
    def merge_options = ""
    // if reference coverages are provided, set here
    if (cov) {
        options = "--ref ${cov}"
    }
    // If a specific pading value is set, use this
    if (params.interval_padding == 15) {
            merge_options = "PADDING=15"
    }    
    def padded_panel = panel.getBaseName() + ".padded_${params.interval_padding}bp.interval_list"
    // do something here - get coverage and build an XLS sheet
    // First we identify which analysed exons are actually part of the exome kit target definition.
    """

    picard -Xmx${task.memory.toGiga()}G IntervalListTools \
        INPUT=$panel \
        SECOND_INPUT=$targets \
        ACTION=SUBTRACT \
        OUTPUT=overlaps.interval_list $merge_options

     picard -Xmx${task.memory.toGiga()}G IntervalListTools \
        INPUT=$panel \
        ACTION=CONCAT \
        PADDING=${params.interval_padding} \
        OUTPUT=$padded_panel

    picard -Xmx${task.memory.toGiga()}G CollectHsMetrics \
        INPUT=${bam} \
        OUTPUT=${coverage} \
        TARGET_INTERVALS=${padded_panel} \
        BAIT_INTERVALS=${padded_panel} \
        CLIP_OVERLAPPING_READS=false \
        REFERENCE_SEQUENCE=${params.ref} \
        TMP_DIR=tmp \
        MINIMUM_MAPPING_QUALITY=$params.min_mapq \
        PER_TARGET_COVERAGE=$target_coverage

    target_ref_coverage2xls.pl $options --infile $target_coverage --min_cov $params.panel_coverage --skip overlaps.interval_list --outfile $target_coverage_xls

    """
}
