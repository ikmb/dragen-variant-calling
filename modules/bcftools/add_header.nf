process BCFTOOLS_ADD_HEADER {

    tag "${meta.patient_id}|${meta.sample_id}"

    container 'quay.io/biocontainers/bcftools:1.14--hde04aa1_1'

    publishDir "${params.outdir}/Variants", mode: 'copy'

    input:
    tuple val(meta),file(vcf),file(tbi)

    output:
    tuple val(meta),file(vcf_r),file(tbi_r), emit: vcf

    script:

    vcf_r = vcf.getBaseName() + ".final.vcf.gz"
    tbi_r = vcf_r + ".tbi"

    """
    echo "##reference=${params.vep_assembly}" > header.txt
    bcftools annotate -h header.txt -O z -o $vcf_r $vcf
    tabix $vcf_r
    """

}