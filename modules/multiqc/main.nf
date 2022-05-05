process MULTIQC {

    publishDir "${params.outdir}/Summary/${cname}", mode: 'copy'

    input:
    val(cname)
    path('*')

    output:
    path("${cname}_multiqc.html"), emit: report

    script:

    """
    cp $params.logo .
    cp $baseDir/conf/multiqc_config.yaml multiqc_config.yaml
    multiqc -n ${cname}_multiqc *

    """
}

process MULTIQC_PANEL {

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

