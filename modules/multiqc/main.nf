process multiqc {

    label 'multiqc'

    publishDir "${params.outdir}/Summary/", mode: 'copy'

    input:
    path('*')

    output:
    path("${params.run_name}_multiqc.html"), emit: report

    script:

    """
    cp $params.logo .
    cp $baseDir/conf/multiqc_config.yaml multiqc_config.yaml
    multiqc -c multiqc_config.yaml -n  ${params.run_name}_multiqc *

    """
}

process multiqc_panel {

	tag "${panel_name}"

	label 'multiqc'

        publishDir "${params.outdir}/Summary/Panel", mode: "copy"

        input:
        tuple val(panel_name),path('*')

        output:
        path("${panel_name}_multiqc.html"), emit: report

        script:

        """
                cp $params.logo .
                cp $baseDir/conf/multiqc_config.yaml multiqc_config.yaml
                multiqc -c multiqc_config.yaml -n ${panel_name}_multiqc *
        """
}

