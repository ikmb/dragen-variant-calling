#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Help message
helpMessage = """
===============================================================================
IKMB DRAGEN pipeline | version ${workflow.manifest.version}
===============================================================================
Usage: nextflow run ikmb/XXX

Required parameters:
--samples			Samplesheet in CSV format (see online documentation)
--assembly			Assembly version to use (GRCh38)
--exome				This is an exome dataset
--email                        	Email address to send reports to (enclosed in '')
--run_name			Name of this run
--trio				Run this as trio analysis

Optional parameters:
--kit				Exome kit to use (xGen_v2)
--expansion_hunter		Run expansion hunter (default: true)
--vep				Run Variant Effect Predictor (default: true)
--interval_padding		Add this many bases to the calling intervals (default: 10)
--cnv				Enable CNV calling (not recommended for exomes)
--sv				Enable SV calling (not recommended for exomes)
--hla 				Enable calling of class I HLA alleles
--clingen			Enable high-precision calling of challening genes (CYP2D6, SMN, GBA) - WGS only. 

Expert options (usually not necessary to change!):

Output:
--outdir                       Local directory to which all output is written (default: results)
"""

params.help = false

// Show help when needed
if (params.help){
    log.info helpMessage
    exit 0
}

// Set pipeline wide options
def summary = [:]

if (!params.run_name) {
	exit 1, "Must provide a --run_name!"
}

if (params.joint_calling && params.trio) {
	exit 1, "Cannot specify joint-calling and trio analysis simultaneously"
}
// validate input options
if (params.kit && !params.exome || params.exome && !params.kit) {
	exit 1, "Exome analysis requires both --kit and --exome"
}

if (!params.assembly) {
	exit 1, "Must provide an assembly name (--assembly)"
}

if (params.exome && params.clingen) {
	exit 1, "Cannot run the clinical gene sub-pipeline on exome data!"
}

params.assembly = "hg38"

if (params.assembly == "hg19") {
	params.vep_assembly = "GRCh37"
}
 
// The Dragen index and the matching FASTA sequence
params.dragen_ref_dir = params.genomes[params.assembly].dragenidx

params.ref = params.genomes[params.assembly].fasta
params.dbsnp = params.genomes[params.assembly].dbsnp

multiqc_config = Channel.fromPath(file("${baseDir}/conf/multiqc_config.yaml", checkIfExists: true))

// Apply ML filter on final call set, if defined
if (params.genomes[params.assembly].ml_dir && params.ml) {
	params.ml_dir = params.genomes[params.assembly].ml_dir
} else {
	params.ml_dir = null
}

panels = Channel.empty()

id_check_bed = Channel.fromPath(file(params.genomes[ params.assembly ].qc_bed, checkIfExists: true))

// Mode-dependent settings
if (params.exome) {

	BED = params.bed ?: params.genomes[params.assembly].kits[ params.kit ].bed
        targets = params.bed ?: params.genomes[params.assembly].kits[ params.kit ].targets
        baits = params.bed ?: params.genomes[params.assembly].kits[ params.kit ].baits
	params.out_format = "bam"
	params.out_index = "bai"
        Channel.fromPath(targets)
                .ifEmpty{exit 1; "Could not find the target intervals for this exome kit..."}
                .set { Targets }

        Channel.fromPath(baits)
                .ifEmpty {exit 1; "Could not find the bait intervals for this exome kit..." }
                .set { Baits }

	if (params.genomes[params.assembly].kits[params.kit].cnv_panel) {
       		params.cnv_panel = params.genomes[params.assembly].kits[params.kit].cnv_panel
		cnv_panel = file(params.cnv_panel,checkIfExists: true)
	} else {
        	params.cnv_panel = null
	}

	// Specific target panels
	if (params.panel) {
        	panel = params.genomes[params.assembly].panels[params.panel].intervals
	        panels = Channel.fromPath(panel)
		panels = Channel.from([ val(params.panel),file(panel)])
	} else if (params.panel_intervals) {
        	Channel.fromPath(params.panel_intervals)
	        .ifEmpty { exit 1; "Could not find the specified gene panel (--panel_intervals)" }
        	.set { panels }
	} else if (params.all_panels) {
        	panel_list = []
	        panel_names = params.genomes[params.assembly].panels.keySet()
        	panel_names.each {
	                interval = params.genomes[params.assembly].panels[it].intervals
        	        panel_list << [ val(it),file(interval) ]
	        }
        	panels = Channel.fromList(panel_list)
	}

} else {

	BED = params.bed ?: params.genomes[params.assembly].bed
	params.out_format = "cram"
	params.out_index = "crai"
	Targets = Channel.empty()
	Baits = Channel.empty()
	BedFile = Channel.fromPath(BED)
	params.cnv_panel = false
} 

if (params.expansion_hunter) {
	params.expansion_json = params.genomes[params.assembly].expansion_catalog
} else {
	params.expansion_json = null
}

def multiqc_report = []

summary['DragenReference'] = params.dragen_ref_dir
if (params.kit) {
	summary['Kit'] = params.kit
}

// import workflows and modules
include { EXOME_QC ; WGS_QC  } from "./workflows/qc/main.nf"
include { DRAGEN_SINGLE_SAMPLE } from "./workflows/dragen/single_sample"
include { DRAGEN_TRIO_CALLING } from "./workflows/dragen/trio_calling"
include { DRAGEN_JOINT_CALLING } from "./workflows/dragen/joint_calling"
include { WHATSHAP } from "./modules/whatshap"
include { VEP } from "./workflows/vep/main.nf"
include { INTERVALS_TO_BED } from "./modules/intervals/main.nf"
include { VCF_STATS } from "./modules/vcf/main.nf"
include { VALIDATE_SAMPLESHEET } from "./modules/qc/main.nf"
include { MULTIQC; MULTIQC_FASTQC } from "./modules/multiqc/main.nf"
include { DRAGEN_USAGE } from "./modules/logging/main.nf"
include { VERSIONS } from "./workflows/versions/main.nf"
include { PANEL_QC } from "./workflows/panels/main.nf"
include { ID_CHECK } from "./workflows/id_check"
include { FASTQC } from "./modules/fastqc"
  
// Input channels
Channel.fromPath( file(params.ref) )
	.ifEmpty { exit 1; "Ref fasta file not found, exiting..." }
	.set { ref_fasta }

Channel.fromPath(params.samples)
	.splitCsv(sep: ',', header: true)
	.map { create_fastq_channel(it) }
	.set { Reads }
  
Channel.fromPath(params.samples)
	.set { Samplesheet }
 
// Console reporting
log.info "---------------------------"
log.info "Variant calling DRAGEN"
log.info " - Version ${workflow.manifest.version} -"
log.info "---------------------------"
log.info "Assembly:     	${params.assembly}"
log.info "Intervals:	${BED}"
if (params.exome) {
	log.info "Mode:		Exome"
	log.info "Kit:		${params.kit}"
} else {
	log.info "Mode:		WGS"
	log.info "ClinGen		${params.clingen}"
}
if (params.ml_dir) {
	log.info "ML:		${params.ml_dir}"
} else {
	log.info "No ML filtering ..."
}
log.info "Align format:	${params.out_format}"
log.info "Trio mode:	${params.trio}"
log.info "CNV calling:	${params.cnv}"
if (params.cnv_panel) {
	"CNV Panel: 	${params.cnv_panel}"
}
log.info "SV calling:	${params.sv}"
log.info "ExpansionHunter	${params.expansion_hunter}"
log.info "HLA typing	${params.hla}"
log.info "VEP prediction: ${params.vep}"
log.info "Phasing:	${params.phase}"
log.info "---------------------------"

workflow {

	main:

	VERSIONS()
	versions = VERSIONS.out.yaml

	// rudementary check of samplesheet validity before we run Dragen	
	VALIDATE_SAMPLESHEET(Samplesheet)
	samples = VALIDATE_SAMPLESHEET.out
	ch_qc = Channel.from([])

	ch_qc = ch_qc.mix(versions)

	if (params.exome) {
		INTERVALS_TO_BED(Targets)
		BedIntervals = INTERVALS_TO_BED.out
	} else {
		BedIntervals = BedFile
	}

	// Read QC; can remove when multiqc offers native support for Dragen FastQC metrics
	FASTQC(
		Reads
	)

	// Dragen processing modes
	if (params.joint_calling) {
		DRAGEN_JOINT_CALLING(Reads,BedIntervals,samples)
		vcf = DRAGEN_JOINT_CALLING.out.vcf
		bam = DRAGEN_JOINT_CALLING.out.bam
		vcf_sample = DRAGEN_JOINT_CALLING.out.vcf_sample
		dragen_logs = DRAGEN_JOINT_CALLING.out.dragen_logs
		ch_qc = ch_qc.mix(DRAGEN_JOINT_CALLING.out.qc)
	} else if (params.trio) {
		DRAGEN_TRIO_CALLING(Reads,BedIntervals,samples)
                vcf = DRAGEN_TRIO_CALLING.out.vcf
                bam = DRAGEN_TRIO_CALLING.out.bam
		vcf_sample = DRAGEN_TRIO_CALLING.out.vcf_sample
		dragen_logs = DRAGEN_TRIO_CALLING.out.dragen_logs
		ch_qc = ch_qc.mix(DRAGEN_TRIO_CALLING.out.qc)
	} else {
		DRAGEN_SINGLE_SAMPLE(Reads,BedIntervals,samples)
		vcf_sample = DRAGEN_SINGLE_SAMPLE.out.vcf
		vcf = DRAGEN_SINGLE_SAMPLE.out.vcf
		bam = DRAGEN_SINGLE_SAMPLE.out.bam
		dragen_logs = DRAGEN_SINGLE_SAMPLE.out.dragen_logs
		ch_qc = ch_qc.mix(DRAGEN_SINGLE_SAMPLE.out.qc)
	}

	// Effect prediction for the primary VCF(s)
	if (params.vep) {
 	       VEP(vcf)
	}

	// Perform phasing of primary VCF(s)
	if (params.phase) {
		WHATSHAP(
			vcf_sample.join(bam)
		)
	}

	// Analysis-specific metrics (WGS or exome)
	if (params.exome) {	
		EXOME_QC(bam,Targets,Baits)
		coverage = EXOME_QC.out.cov_report
		PANEL_QC(bam,panels,Targets)
		ch_qc = ch_qc.mix(coverage)
	} else {
		WGS_QC(bam,BedIntervals)
		coverage = WGS_QC.out.cov_report
		ch_qc = ch_qc.mix(coverage)
	} 

	if (params.check) {
		ID_CHECK(bam,id_check_bed)
		check_vcf = ID_CHECK.out.vcf
	}

	// Statistics for primary VCF(s)
	VCF_STATS(vcf_sample)

	ch_qc = ch_qc.mix(VCF_STATS.out.stats)

	// How many bases have been processed (for accounting)
	DRAGEN_USAGE(dragen_logs.collect())

	ch_qc = ch_qc.mix(DRAGEN_USAGE.out.yaml)

	// Primary QC report
	MULTIQC(
		ch_qc.collect(),
		multiqc_config.collect()
	)
	// Read qc (until Multiqc can process FastQC from Dragen	
	MULTIQC_FASTQC(
		FASTQC.out.zip.map {m,z -> z }.collect(),
		multiqc_config.collect()
	)

	multiqc_report = MULTIQC.out.report.toList()
}

// Turn input meta data into a hash object and file paths
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

workflow.onComplete {

  log.info "========================================="
  log.info "Duration:		$workflow.duration"
  log.info "========================================="

  def email_fields = [:]
  email_fields['version'] = workflow.manifest.version
  email_fields['session'] = workflow.sessionId
  email_fields['runName'] = params.run_name
  email_fields['Samples'] = params.samples
  email_fields['success'] = workflow.success
  email_fields['dateStarted'] = workflow.start
  email_fields['dateComplete'] = workflow.complete
  email_fields['duration'] = workflow.duration
  email_fields['exitStatus'] = workflow.exitStatus
  email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
  email_fields['errorReport'] = (workflow.errorReport ?: 'None')
  email_fields['commandLine'] = workflow.commandLine
  email_fields['projectDir'] = workflow.projectDir
  email_fields['script_file'] = workflow.scriptFile
  email_fields['launchDir'] = workflow.launchDir
  email_fields['user'] = workflow.userName
  email_fields['Pipeline script hash ID'] = workflow.scriptId
  email_fields['manifest'] = workflow.manifest
  email_fields['summary'] = summary

  email_info = ""
  for (s in email_fields) {
	email_info += "\n${s.key}: ${s.value}"
  }

  def output_d = new File( "${params.outdir}/pipeline_info/" )
  if( !output_d.exists() ) {
      output_d.mkdirs()
  }

  def output_tf = new File( output_d, "pipeline_report.txt" )
  output_tf.withWriter { w -> w << email_info }	

 // make txt template
  def engine = new groovy.text.GStringTemplateEngine()

  def tf = new File("$baseDir/assets/email_template.txt")
  def txt_template = engine.createTemplate(tf).make(email_fields)
  def email_txt = txt_template.toString()

  // make email template
  def hf = new File("$baseDir/assets/email_template.html")
  def html_template = engine.createTemplate(hf).make(email_fields)
  def email_html = html_template.toString()
  
  def subject = "Dragen analysis finished ($params.run_name)."

  if (params.email) {

        def mqc_report = null
        try {
                if (workflow.success && !params.skip_multiqc) {
                        mqc_report = multiqc_report.getVal()
                        if (mqc_report.getClass() == ArrayList){
                                log.warn "[IKMB DragenVariantCalling] Found multiple reports from process 'multiqc', will use only one"
                                mqc_report = mqc_report[-1]
                        }
                }

        } catch (all) {
                log.warn "[IKMB DragenVariantCalling] Could not attach MultiQC report to summary email"
        }

	def smail_fields = [ email: params.email, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir", mqcFile: mqc_report, mqcMaxSize: params.maxMultiqcEmailFileSize.toBytes() ]
	def sf = new File("$baseDir/assets/sendmail_template.txt")	
    	def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    	def sendmail_html = sendmail_template.toString()

	try {
          if( params.plaintext_email ){ throw GroovyException('Send plaintext e-mail, not HTML') }
          // Try to send HTML e-mail using sendmail
          [ 'sendmail', '-f no-reply@ikmb.uni-kiel.de',  '-t' ].execute() << sendmail_html
        } catch (all) {
          // Catch failures and try with plaintext
          [ 'mail', '-s', subject, params.email ].execute() << email_txt
        }

  }

}

