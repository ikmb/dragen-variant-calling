process VEP {

    label 'medium_parallel'

    container 'quay.io/biocontainers/ensembl-vep:109.3--pl5321h2a3209d_1'

    tag "${meta.patient_id}|${meta.sample_id}"

    publishDir "${params.outdir}/VEP", mode: 'copy'

    input:
    tuple val(meta),path(vcf),path(tbi)

    output:
    tuple val(meta),path(vcf_annotated), emit: vcf

    script:
    vcf_annotated = vcf.getBaseName() + ".vep.vcf"

    def options = ""
    options = " --af_gnomade --af_gnomadg "

    """
        vep --offline \
            --cache \
            --dir ${params.vep_cache_dir} \
            --species homo_sapiens \
            --assembly $params.vep_assembly \
            -i $vcf \
            --format vcf \
            -o $vcf_annotated --dir_plugins ${params.vep_plugin_dir} \
            --plugin dbNSFP,${params.dbnsfp_db},${params.dbnsfp_fields} \
            --plugin dbscSNV,${params.dbscsnv_db} \
            --plugin CADD,${params.cadd_snps},${params.cadd_indels} \
            --plugin Mastermind,${params.vep_mastermind}\
            --plugin SpliceAI,${params.spliceai_fields} \
            --fasta $params.ref \
            --fork ${task.cpus} \
            --vcf \
            --per_gene \
            --sift p \
            --polyphen p \
            --check_existing \
            --canonical $options

            sed -i.bak 's/CADD_PHRED/CADD_phred/g' $vcf_annotated

        """
}
