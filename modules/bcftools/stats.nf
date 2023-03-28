process BCFTOOLS_STATS {

        tag "${meta.patient_id}|${meta.sample_id}"

	label 'short_serial'

        container 'quay.io/biocontainers/bcftools:1.14--hde04aa1_1'

	publishDir "${params.outdir}/logs", mode: 'copy'

        input:
        tuple val(meta),path(vcf),path(tbi)

        output:
        path(vstats), emit: stats

        script:
        vstats = vcf.getBaseName() + ".stats"

        """
        bcftools stats $vcf > $vstats
        """
}