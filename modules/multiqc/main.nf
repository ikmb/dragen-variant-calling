process MULTIQC {

    label 'short_serial'

    container 'quay.io/biocontainers/multiqc:1.13a--pyhdfd78af_1'

    publishDir "${params.outdir}/Summary/", mode: 'copy'

    input:
    path('*')
    path(config)

    output:
    path("${params.run_name}_multiqc.html"), emit: html

    script:

    """
    cp $params.logo .
    multiqc -c $config -n  ${params.run_name}_multiqc *
    """
}

process MULTIQC_PANEL {

	tag "${panel_name}"

	label 'short_serial'

    container 'quay.io/biocontainers/multiqc:1.13a--pyhdfd78af_1'

    publishDir "${params.outdir}/Summary/Panel", mode: "copy"

    input:
    tuple val(panel_name),path('*')

    output:
    path("${panel_name}_multiqc.html"), emit: html

    script:

    """
    cp $params.logo .
    cp $baseDir/conf/multiqc_config.yaml multiqc_config.yaml
    multiqc -c multiqc_config.yaml --title "DRAGEN pipeline report: ${panel_name}" -n ${panel_name}_multiqc *
    """
}

process MULTIQC_FASTQC {

    label 'short_serial'

    container 'quay.io/biocontainers/multiqc:1.13a--pyhdfd78af_1'

    publishDir "${params.outdir}/Summary/FastQC", mode: 'copy'

    input:
    path('*')
    path(config)

    output:
    path("${params.run_name}_fastqc_multiqc.html"), emit: html

    script:

    """

    cp $params.logo .
    multiqc -c $config -n  ${params.run_name}_fastqc_multiqc *

    """
}
