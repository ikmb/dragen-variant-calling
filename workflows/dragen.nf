// ******************************
// Pipeline options and settings
// ******************************

// Requested analysis is for exomes
if (params.exome) {

    params.out_format = "bam"
    params.out_index = "bai"

    targets = params.targets ?: params.genomes[params.assembly].kits[ params.kit ].targets
    ch_targets = Channel.fromPath(
        file(targets, checkIfExists: true)
    )

    baits = params.baits ?: params.genomes[params.assembly].kits[ params.kit ].baits
    ch_baits = Channel.fromPath(
        file(baits, checkIfExists: true)
    )

    if (params.cnv_panel) {
        ch_cnv_panel = Channel.fromPath(params.cnv_panel, checkIfExists: true).collect()
    } else if (params.genomes[params.assembly].kits[params.kit].cnv_panel) {
        ch_cnv_panel = Channel.fromPath(params.genomes[params.assembly].kits[params.kit].cnv_panel).collect()
    } else {
        ch_cnv_panel = Channel.value([])
    }

    // Specific target panels
    if (params.panel) {
        panel = params.genomes[params.assembly].panels[params.panel].intervals
        ch_panels = Channel.from( [ params.panel, file(panel, checkIfExists: true) ] )
    } else if (params.panel_intervals) {
        Channel.from([ "Custom",file(params.panel_intervals,checkIfExists: true)])
        .set { ch_panels }
    } else if (params.all_panels) {
        panel_list = []
        panel_names = params.genomes[params.assembly].panels.keySet()
        panel_names.each {
            interval = params.genomes[params.assembly].panels[it].intervals
            panel_list << [ it,file(interval) ]
        }
        ch_panels = Channel.fromList(panel_list)
    } else {
        ch_panels = Channel.from([])
    }

// analysis if for genomes
} else {

    params.out_format = "cram"
    params.out_index = "crai"

    bed_file = params.bed ?: params.genomes[params.assembly].bed
    ch_bed = Channel.fromPath(bed_file)

    ch_targets = Channel.empty()
    ch_baits = Channel.empty()

    ch_cnv_panel = Channel.from([])
} 

if (params.expansion_hunter ) {  params.expansion_json = params.genomes[params.assembly].expansion_catalog } else {  params.expansion_json = null }

ch_id_check_bed = Channel.fromPath(file(params.genomes[ params.assembly ].qc_bed, checkIfExists: true))
multiqc_config = Channel.fromPath(file("${baseDir}/conf/multiqc_config.yaml", checkIfExists: true))

if (params.genomes[params.assembly].ml_dir) { params.ml_dir = params.genomes[params.assembly].ml_dir } else { params.ml_dir = null }

// ******************************
// Subworkflows and modules
// ******************************

include { WGS_QC } from "./../subworkflows/wgs_qc"
include { EXOME_QC } from "./../subworkflows/exome_qc"
include { DRAGEN_SINGLE_SAMPLE } from "./../subworkflows/dragen/single_sample"
include { DRAGEN_TRIO_CALLING } from "./../subworkflows/dragen/trio_calling"
include { DRAGEN_JOINT_CALLING } from "./../subworkflows/dragen/joint_calling"
include { WHATSHAP } from "./../modules/whatshap"
include { VEP_ANNOTATE } from "./../subworkflows/vep_annotate"
include { PICARD_INTERVAL_LIST_TO_BED } from "./../modules/picard/interval_list_to_bed"
include { BCFTOOLS_STATS } from "./../modules/bcftools/stats"
include { VALIDATE_SAMPLESHEET } from "./../modules/validate_samplesheet"
include { MULTIQC; MULTIQC_FASTQC } from "./../modules/multiqc/main.nf"
include { DRAGEN_USAGE } from "./../modules/logging/main.nf"
include { VERSIONS } from "./../subworkflows/versions"
include { PANEL_QC } from "./../subworkflows/panel_qc"
include { ID_CHECK } from "./../subworkflows/id_check"
include { FASTQC } from "./../modules/fastqc"

// ************************************************
// Pipeline input(s)
// ************************************************

ch_samplesheet = Channel.fromPath(params.samples, checkIfExists: true)

ch_ref = Channel.fromPath( [ file(params.ref), file(params.ref + ".fai") ] )
    .ifEmpty { exit 1; "Ref fasta file not found, exiting..." }

ch_qc = Channel.from([])

workflow DRAGEN_VARIANT_CALLING {

    main:

        // Capture software version(s)
        VERSIONS()
        versions = VERSIONS.out.yaml
        ch_qc = ch_qc.mix(versions)

        // Validate format of samplesheet
        VALIDATE_SAMPLESHEET(
            ch_samplesheet
        )
        ch_samples = VALIDATE_SAMPLESHEET.out.csv

        ch_samples
            .splitCsv ( header: true, sep: ',')
            .map { create_fastq_channel(it) }
            .set { ch_reads }        
            
        if (params.exome) {
            PICARD_INTERVAL_LIST_TO_BED(ch_targets)
            ch_bed_intervals = PICARD_INTERVAL_LIST_TO_BED.out.bed
        } else {
            ch_bed_intervals = ch_bed
        }

        // Read-QC prior
        FASTQC(
            ch_reads   
        )

        // Perform joint-calling of samples
        if (params.joint_calling) {

            DRAGEN_JOINT_CALLING(
                ch_reads,
                ch_bed_intervals,
                ch_samples,
                ch_cnv_panel
            )

            vcf         = DRAGEN_JOINT_CALLING.out.vcf
            bam         = DRAGEN_JOINT_CALLING.out.bam
            vcf_sample  = DRAGEN_JOINT_CALLING.out.vcf_sample
            dragen_logs = DRAGEN_JOINT_CALLING.out.dragen_logs

            ch_qc = ch_qc.mix(DRAGEN_JOINT_CALLING.out.qc)

        // or perform Trio analysis
        } else if (params.trio) {

            DRAGEN_TRIO_CALLING(
                ch_reads,
                ch_bed_intervals,
                ch_samples,
                ch_cnv_panel
            )

            vcf         = DRAGEN_TRIO_CALLING.out.vcf
            bam         = DRAGEN_TRIO_CALLING.out.bam
            vcf_sample  = DRAGEN_TRIO_CALLING.out.vcf_sample
            dragen_logs = DRAGEN_TRIO_CALLING.out.dragen_logs

            ch_qc = ch_qc.mix(DRAGEN_TRIO_CALLING.out.qc)

        // else perform single-sample analysis
        } else {

            DRAGEN_SINGLE_SAMPLE(
                ch_reads,
                ch_bed_intervals,
                ch_samples,
                ch_cnv_panel
            )

            vcf_sample  = DRAGEN_SINGLE_SAMPLE.out.vcf
            vcf         = DRAGEN_SINGLE_SAMPLE.out.vcf
            bam         = DRAGEN_SINGLE_SAMPLE.out.bam
            dragen_logs = DRAGEN_SINGLE_SAMPLE.out.dragen_logs

            ch_qc = ch_qc.mix(DRAGEN_SINGLE_SAMPLE.out.qc)

        }

        // Variant effect prediction
        if (params.vep) {
            VEP_ANNOTATE(
                vcf
            )
        }

        // QC Metrics
        if (params.exome) {    

            EXOME_QC(
                bam,
                ch_targets,
                ch_baits
            )

            PANEL_QC(
                bam,
                ch_panels,
                ch_targets
            )

            ch_qc       = ch_qc.mix(EXOME_QC.out.cov_report)

        } else {

            WGS_QC(
                bam,
                ch_bed_intervals
            )

            ch_qc       = ch_qc.mix(WGS_QC.out.cov_report)

        } 
        
        // ID Check for comparison with genotyping data
        ID_CHECK(
            bam,
            ch_id_check_bed
        )

        check_vcf       = ID_CHECK.out.vcf

        // VCF file statistics    
        BCFTOOLS_STATS(
            vcf
        )

        ch_qc = ch_qc.mix(BCFTOOLS_STATS.out.stats)

        // How many bases have been processed (for accounting)
        DRAGEN_USAGE(
            dragen_logs.collect()
        )

        ch_qc = ch_qc.mix(DRAGEN_USAGE.out.yaml)

        // Generate QC report
        MULTIQC(
            ch_qc.collect(),
            multiqc_config.collect()
        )

    emit:
    qc = MULTIQC.out.html

}

def create_fastq_channel(LinkedHashMap row) {

    // famID,indivID,RGID,RGSM,RGLB,Lane,Read1File,Read2File,PaternalID,MaternalID,Sex,Phenotype

    def meta = [:]
    meta.family_id = row.famID
    meta.patient_id = row.indivID
    meta.sample_id = row.RGSM
    meta.library_id = row.RGLB
    meta.lane = row.Lane
    meta.readgroup_id = row.RGID
    meta.paternal_id = row.PaternalID
    meta.maternal_id = row.MaternalID
    meta.sex = row.Sex
    meta.phenotype = row.Phenotye

    def array = []
    array = [ meta, file(row.Read1File), file(row.Read2File) ]

    return array
}
