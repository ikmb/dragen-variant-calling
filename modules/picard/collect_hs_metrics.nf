process PICARD_COLLECT_HS_METRICS {

    tag "${meta.patient_id}|${meta.sample_id}"

    label "short_serial"

    container 'quay.io/biocontainers/picard:3.0.0--hdfd78af_1'

    publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/Picard_Metrics", mode: 'copy'

    input:
    tuple val(meta), file(bam), file(bai)
    path(targets)
    path(baits) 

    output:
    path(outfile), emit: report
    path(outfile_per_target)

    script:
    outfile = meta.patient_id + "_" + meta.sample_id + ".hybrid_selection_metrics.txt"
    outfile_per_target = meta.patient_id + "_" + meta.sample_id + ".hybrid_selection_per_target_metrics.txt"

    """
    picard -Xmx${task.memory.toGiga()}G CollectHsMetrics \
        INPUT=${bam} \
        OUTPUT=${outfile} \
        PER_TARGET_COVERAGE=${outfile_per_target} \
        TARGET_INTERVALS=${targets} \
        BAIT_INTERVALS=${baits} \
        REFERENCE_SEQUENCE=${params.ref} \
        MINIMUM_MAPPING_QUALITY=$params.min_mapq \
        TMP_DIR=tmp
    """
}
