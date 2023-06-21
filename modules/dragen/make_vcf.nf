// end-to-end single sample variant calling
// Dragen has many optional arguments for running integrated sub-pipelines

process MAKE_VCF {

    tag "${meta.patient_id}|${meta.sample_id}"

    label 'dragen'

    publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/", mode: 'copy'

    input:
    tuple val(meta), path(lreads),path(rreads)
    path(bed)
    path(samplesheet)
    path(cnv_panel)

    output:
    tuple val(meta),path("${outdir}/*filtered.vcf.gz"), emit: vcf
    tuple val(meta),path(bam),path(bai), emit: bam
    tuple val(meta),path("${outdir}/*"), emit: results
    tuple path(dragen_start),path(dragen_end), emit: log
    path("${outdir}/*.csv"), emit: qc
    tuple val(meta),path("${outdir}/${sv}"),path("${outdir}/${sv_tbi}"), optional: true, emit: sv
    tuple val(meta),path("${outdir}/${cnv}"),path("${outdir}/${cnv_tbi}"), optional: true, emit: cnv

    script:
    def prefix = meta.sample_id
    vcf = prefix + ".hard-filtered.vcf.gz"
    vcf_tbi = vcf + ".tbi"
    sv = prefix + ".sv.vcf.gz"
    sv_tbi = sv + ".tbi"
    cnv = prefix + ".cnv.vcf.gz"
    cnv_tbi = cnv + ".tbi"
    bam = prefix + "." + params.out_format
    bai = bam + "." + params.out_index
    outdir = prefix + "_results"
    dragen_start = prefix + ".dragen_log.vcf.start.log"
    dragen_end = prefix + ".dragen_log.vcf.end.log"
            
    def options = ""
    def mv_options = ""

    // Disable maximum likelihood filter
    if (params.no_ml) {
        options = options.concat(" --vc-ml-enable-recalibration=false ")
    } else {
        options = options.concat(" --vc-ml-dir=/opt/edico/resources/ml_model/hg38 --vc-ml-enable-recalibration=true ")
    }

    // Enable calling of PgX star alleles, only dragen > 4.0
    if (params.pgx) {
        options = options.concat(" --enable-starallele true ")
    }

    // This is an exome run
    if (params.exome) {
        mv_options = "mkdir -p $outdir/wgs && mv $outdir/*wgs*.csv $outdir/wgs"
        options = options.concat(" --vc-target-bed $bed ")
        if (params.cnv) {
            options = options.concat(" --cnv-target-bed $bed ")
            if (cnv_panel) {
                options = options.concat(" --cnv-normals-list ${cnv_panel} ")
            } else {
                options = options.concat(" --cnv-enable-self-normalization true ")
            } 
        }
        if (params.sv) {
            options = options.concat(" --sv-exome true --sv-call-regions-bed $bed ")

        }
    // this is WGS data
    } else {
        if (params.clingen) {
            options = options.concat(" --enable-cyp2d6=true --enable-smn=true ")
        }
        if (params.cnv) {
            options = options.concat("--cnv-enable-self-normalization true --cnv-interval-width 1000 ")
        }
    }
    
    // *****************
    // Universal options
    // *****************

    // Run Expansionhunter
    if (params.expansion_hunter) {
        options = options.concat(" --repeat-genotype-enable=true --repeat-genotype-specs=${params.expansion_json} ")
    }

    // Run HLA caller
    if (params.hla) {
        options = options.concat(" --enable-hla true ")
    }
    
    // Run CNV caller
    if (params.cnv) {
        options = options.concat(" --enable-cnv true ")
    }
    
    // Run SV caller
    if (params.sv) {
        options = options.concat(" --enable-sv true ")
        //post = "manta2alissa.pl -i ${outdir}/${meta.sample_id}.sv.vcf.gz -o ${outdir}/${meta.sample_id}.sv2alissa.vcf"
    }
    
    """

        /opt/edico/bin/dragen_lic -f genome &> $dragen_start

        mkdir -p $outdir
        
        samplesheet2dragen.pl --samples $samplesheet > files.csv

        /opt/edico/bin/dragen -f \
            -r ${params.dragen_ref_dir} \
            --fastq-list files.csv \
            --fastq-list-sample-id ${meta.sample_id} \
            --enable-variant-caller true \
            --enable-map-align-output true \
            --enable-map-align true \
            --enable-duplicate-marking true \
            --dbsnp $params.dbsnp \
            ${options} \
            --intermediate-results-dir ${params.dragen_tmp} \
            --output-directory $outdir \
            --output-file-prefix ${prefix} \
            --output-format $params.out_format
    
        mv $outdir/$bam $bam
        mv $outdir/$bai $bai

        $mv_options    

        /opt/edico/bin/dragen_lic -f genome &> $dragen_end

    """
}
