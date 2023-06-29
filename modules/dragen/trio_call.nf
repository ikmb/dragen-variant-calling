// Take single gVCFs and call trio analysis
process TRIO_CALL {

    label 'dragen'

    publishDir "${params.outdir}/TrioCalling", mode: 'copy'

    input:
    tuple val(meta),path(gvcfs)
    path(bed)
    path(samplesheet)

    output:
    tuple val(meta),path("*hard-filtered.vcf.gz"), emit: vcf
    tuple val(meta),path("results/*"), emit: results
    tuple path(dragen_start),path(dragen_end), emit: log

    script:

    prefix = params.run_name + ".trio"
    def options = ""
    if (params.ml_dir) {
                options = options.concat(" --vc-ml-dir ${params.ml_dir} --vc-ml-enable-recalibration=true")
        }
    if (params.exome) {
                options = "--vc-target-bed $bed "
    }

    dragen_start = meta.family_id + ".dragen_log.trio.start.log"
    dragen_end = meta.family_id + ".dragen_log.trio.end.log"

    """

        /opt/edico/bin/dragen_lic -f genome &> $dragen_start

        samplesheet2ped.pl --samples $samplesheet > family.ped

        mkdir -p results 

        /opt/edico/bin/dragen -f \
            -r ${params.dragen_ref_dir} \
            --variant ${gvcfs.join( ' --variant ')} \
            --pedigree-file family.ped \
            --intermediate-results-dir ${params.dragen_tmp} \
            --dbsnp $params.dbsnp \
            --output-directory results \
            --output-file-prefix $prefix \
            --enable-joint-genotyping true \
            $options            
                    
            cp results/*.vcf.gz* . 

        /opt/edico/bin/dragen_lic -f genome &> $dragen_end
    """
}
