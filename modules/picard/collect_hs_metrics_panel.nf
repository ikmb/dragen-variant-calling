process PICARD_COLLECT_HS_METRICS_PANEL {

	label 'default'

	tag "${meta.sample_id}|${panel_name}"

    publishDir "${params.outdir}/Summary/Panel/PanelCoverage", mode: "copy"

    input:
    tuple val(meta),path(bam),path(bai),val(panel_name),path(panel)
	path(targets)

    output:
    tuple val(panel_name),path(coverage), emit: coverage
    tuple val(meta),path(target_coverage_xls)
    path(target_coverage)

    script:
    coverage = "${meta.patient_id}_${meta.sample_id}.${panel_name}.hs_metrics.txt"
    target_coverage = "${meta.patient_id}_${meta.sample_id}.${panel_name}.per_target.hs_metrics.txt"
    target_coverage_xls = "${meta.patient_id}_${meta.sample_id}.${panel_name}.per_target.hs_metrics_mqc.xlsx"

    // optionally support a kill list of known bad exons
    def options = ""
	def cov = ""
	if (params.genomes[params.assembly].panels[panel_name].coverages) {
		cov = file(params.genomes[params.assembly].panels[panel_name].coverages)
		options = "--ref ${cov}"
	}
    // do something here - get coverage and build an XLS sheet
    // First we identify which analysed exons are actually part of the exome kit target definition.
    """

    picard -Xmx${task.memory.toGiga()}G IntervalListTools \
        INPUT=$panel \
        SECOND_INPUT=$targets \
        ACTION=SUBTRACT \
        OUTPUT=overlaps.interval_list

    picard -Xmx${task.memory.toGiga()}G CollectHsMetrics \
        INPUT=${bam} \
        OUTPUT=${coverage} \
        TARGET_INTERVALS=${panel} \
        BAIT_INTERVALS=${panel} \
        CLIP_OVERLAPPING_READS=false \
        REFERENCE_SEQUENCE=${params.ref} \
        TMP_DIR=tmp \
        MINIMUM_MAPPING_QUALITY=$params.min_mapq \
        PER_TARGET_COVERAGE=$target_coverage

    target_ref_coverage2xls.pl $options --infile $target_coverage --min_cov $params.panel_coverage --skip overlaps.interval_list --outfile $target_coverage_xls

    """
}