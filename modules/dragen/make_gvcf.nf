// MODULE FILE
// Dragen variant caller
// Process FastQ files into gVCF and BAM/CRAM
process MAKE_GVCF {

    tag "${meta.patient_id}|${meta.sample_id}"
        
    label 'dragen'

    publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/", mode: 'copy'

    input:
    tuple val(meta),path(lreads),path(rreads)
    path(bed)
    path(samplesheet)
    path(cnv_panel)

    output:
    tuple val(meta),path("${outdir}/*.gvcf.gz"), emit: gvcf
    tuple val(meta),path("${outdir}/${align}"),path("${outdir}/${align_index}"), emit: bam
    val(meta), emit: sample
    path("${outdir}/*"), emit: results
    tuple path(dragen_start),path(dragen_end), emit: log
    path("${outdir}/*.csv"), emit: qc
    path("${outdir}/${meta.sample_id}.target.counts.gc-corrected.gz"), optional: true, emit: targets
    tuple val(meta),path("${outdir}/${sv}"),path("${outdir}/${sv_tbi}"), optional: true, emit: sv
    tuple val(meta),path("${outdir}/${cnv}"),path("${outdir}/${cnv_tbi}"), optional: true, emit: cnv

    script:
    def prefix = meta.sample_id
    sv = prefix + ".sv.vcf.gz"
    sv_tbi = sv + ".tbi"
    cnv = prefix + ".cnv.vcf.gz"
    cnv_tbi = cnv + ".tbi"
    gvcf = prefix + ".gvcf.gz"
    align = prefix + "." + params.out_format
    align_index = align + "." + params.out_index
    outdir = prefix + "_results"
    dragen_start = prefix + "dragen_log.gvcf.start.log"
    dragen_end = prefix + "dragen_log.gvcf.end.log"

    def options = ""
    def mv_options = ""

    // Disable maximum likelihood filtering
    if (params.no_ml) {
	options = options.concat("  --vc-ml-enable-recalibration=false ")
    } else {
        options = options.concat(" --vc-ml-dir=/opt/edico/resources/ml_model/hg38 --vc-ml-enable-recalibration=true ")
    }

    // Enable calling of PgX star alleles - only Dragen > 4.0
    if (params.pgx) {
        options = options.concat(" --enable-starallele true ")
    }

    // This is exome data
    if (params.exome) {
        options = options.concat(" --vc-target-bed $bed ")
        mv_options = "mkdir -p $outdir/wgs && mv $outdir/*wgs*.csv $outdir/wgs"
        if (params.cnv) {
            options = options.concat(" --cnv-target-bed $bed ")
            if (cnv_panel) {
                options = options.concat(" --cnv-normals-list ${cnv_panel} ")
            } else {
                options.concat(" --cnv-enable-self-normalization true ")
            }
        }
        if (params.sv) {
            options = options.concat(" --sv-exome true --sv-call-regions-bed $bed ")
        }
    // This is WGS data
    } else {
        if (params.clingen) {
            options = options.concat(" --enable-cyp2d6=true --enable-smn=true --enable-gba=true ")
        }
        if (params.cnv) {
            options = options.concat(" --cnv-enable-self-normalization true --cnv-interval-width 1000 ")
        }
    }

    // *****************
    // Universal options
    // *****************

    // Run expansion hunter
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
        --vc-emit-ref-confidence GVCF \
        --vc-enable-vcf-output true \
        --intermediate-results-dir ${params.dragen_tmp} \
        --output-directory $outdir \
        --output-file-prefix ${prefix} \
        --output-format $params.out_format $options

    $mv_options

    /opt/edico/bin/dragen_lic -f genome &> $dragen_end

    """
}
