#!/usr/bin/env nextflow

REF_DIR = params.genomes[params.genome].dragen_index_dir
REF = params.genomes[params.genome].fasta

if (params.mode == "wgs") {
	BED = params.bed ?: params.genomes[params.genome].bed
	out_format = "cram"
} else if (params.mode == "wes" && params.kit ) {
	BED = params.bed ?: params.genomes[params.genome].kits[ params.kit ].bed
	out_format = "bam"
} else {
	exit 1, "Must specifiy if you are running a WGS (--mode wgs) or WES (--mode wes and --kit) analysis"
}

params.run_name = false
run_name = ( params.run_name == false) ? "${workflow.sessionId}" : "${params.run_name}"

Channel.fromPath( file(REF_DIR) )
	.into { ref_index; ref_index_merging; ref_index_join }

Channel.fromPath( file(REF) )
	.ifEmpty { exit 1; "Ref fasta file not found, exiting..." }
	.set { ref_fasta }
 
Channel.fromPath( file(BED) )
	.ifEmpty { exit 1; "Target BED file not found, existing..." }
	.into { target_gvcf; target_joint_calling ; target_merge_vcf }

Channel.from(file(params.samples))
       	.splitCsv(sep: ';', header: true)
	.set { alignReads }

log.info "Variant calling DRAGEN"
log.info " - devel version -"
log.info "----------------------"
log.info "Assembly:     	${params.genome}"
log.info "Mode:		${params.mode}"
if (params.kit) {
	log.info "Kit:		${params.kit}"
}

process make_gvcf {

	label 'dragen'

	publishDir "${params.outdir}/${libraryID}/", mode: 'copy'

	input:
	set indivID, sampleID, libraryID, rgID, platform_unit, platform, platform_model, center, date, fastqR1, fastqR2 from alignReads
	file(bed) from target_gvcf.collect()
	file(ref) from ref_index.collect()

	output:
	file("${outdir}/*.gvcf.gz") into Gvcf
	file("${outdir}/*.bam") into Bam
	file("${outdir}/*.csv") into BamQC

	script:
	gvcf = sampleID + ".gvcf.gz"
	outdir = sampleID + "_results"

	"""
		mkdir -p $outdir
		/opt/edico/bin/dragen -f \
			-r $REF_DIR \
			-1 $fastqR1 \
			-2 $fastqR2 \
			--read-trimmers none \
			--enable-variant-caller true \
			--enable-map-align-output true \
			--enable-map-align true \
			--enable-duplicate-marking true \
			--vc-target-bed $bed \
			--vc-emit-ref-confidence GVCF \
			--intermediate-results-dir ${params.dragen_tmp} \
			--RGID $rgID \
			--RGSM $sampleID \
			--RGCN $center \
			--RGDT $date \
			--RGLB $libraryID \
			--output-directory $outdir \
			--output-file-prefix $sampleID \
			--output-format $out_format
	"""
}

process merge_gvcfs {

	label 'dragen'

        publishDir "${params.outdir}/gVCF", mode: 'copy'

	when:
	params.merge

	input:
	file(gvcfs) from Gvcf.collect()
	file(fasta) from ref_fasta.collect()
	file(bed) from target_merge_vcf.collect()

	output:
	file(merged_gvcf) into MultiVCF
	file("merged_vcf/*")

	script:
	def options = ""
	if (params.mode == "wes") {
		options = "--gg-regions ${bed}"
	}
	merged_gvcf = run_name + ".gvcf.gz"

	"""

		for i in \$(echo *.gvcf.gz)
                         do echo \$i >> variants.list
                done

		mkdir -p merged_vcf

		/opt/edico/bin/dragen -f \
			-r $REF_DIR \
			--enable-combinegvcfs true \
			--output-directory merged_vcf \
			--output-file-prefix $run_name \
			--intermediate-results-dir ${params.dragen_tmp} \
			$options \
			--variant-list variants.list

		mv merged_vcf/*vcf.gz . 
	"""
}

process joint_call {

	label 'dragen'

        publishDir "${params.outdir}/JointCall", mode: 'copy'

	when:
	params.merge

	input:
	file(mgvcf) from MultiVCF.collect()
	file(ref) from ref_index_join.collect()
	file(bed) from target_joint_calling.collect()

	output:
	file("*.vcf.gz") into FinalVcf
	file("results/*")

	script:

	prefix = run_name + ".joint_genotyped"

	"""
		mkdir -p results

		/opt/edico/bin/dragen -f \
			--enable-joint-genotyping true \
			--intermediate-results-dir ${params.dragen_tmp} \
			--variant $mgvcf \
			--ref-dir $REF_DIR \
			--output-directory results \
			--output-file-prefix $prefix

		mv results/*vcf.gz* . 
	"""
}


