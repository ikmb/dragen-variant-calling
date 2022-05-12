process multiqc {

    label 'default'

    publishDir "${params.outdir}/Summary/", mode: 'copy'

    input:
    path('*')

    output:
    path("${params.run_name}_multiqc.html"), emit: report

    script:

    """
    cp $params.logo .
    cp $baseDir/conf/multiqc_config.yaml multiqc_config.yaml
    multiqc -n  ${params.run_name}_multiqc *

    """
}

process multiqc_panel {

	label 'default'

        publishDir "${params.outdir}/Summary/Panel", mode: "copy"

        input:
        tuple val(panel_name),path('*')

        output:
        path("${panel_name}_multiqc.html")

        script:

        """
                cp $params.logo .
                cp $baseDir/conf/multiqc_config.yaml multiqc_config.yaml
                multiqc -n ${panel_name}_multiqc *
        """
}

