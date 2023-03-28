process PICARD_INTERVAL_LIST_TOOL {

    tag "${targets}|${panel}"

    label 'short_serial'

    container 'quay.io/biocontainers/picard:3.0.0--hdfd78af_1'

    input:
    tuple val(meta),path(bam),path(bai),val(panel_name),path(panel)
	path(targets)

    output:
    tuple val(meta),path(overlaps), emit: overlap

    script:
    target_name = target.getBaseName()
    overlaps = panel_name + "-" + target_name + "-overlaps.interval_list"

    """
    picard -Xmx${task.memory.toGiga()}G IntervalListTools \
        INPUT=$panel \
        SECOND_INPUT=$targets \
        ACTION=SUBTRACT \
        OUTPUT=$overlaps
    """

}