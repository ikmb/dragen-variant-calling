#!/usr/bin/env nextflow

REF_DIR = params.genomes[params.genome].dragen_index_dir
REF = params.genomes[params.genome].fasta

if (params.mode == "wgs") {
	BED = params.bed ?: params.genomes[params.genome].bed
	out_format = "cram"

	TargetToHS = Channel.empty()
	BaitsToHS = Channel.empty()

} else if (params.mode == "wes" && params.kit ) {
	BED = params.bed ?: params.genomes[params.genome].kits[ params.kit ].bed
	out_format = "bam"
	targets = params.bed ?: params.genomes[params.genome].kits[ params.kit ].targets
	baits = params.bed ?: params.genomes[params.genome].kits[ params.kit ].baits

	Channel.fromPath(targets)
		.ifEmpty{exit 1; "Could not find the target intervals for this exome kit..."}
		.set { TargetsToHS }

	Channel.fromPath(baits)
		.ifEmpty {exit 1; "Could not find the bait intervals for this exome kit..." }
		.set { BaitsToHS }

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
	.into { target_gvcf; target_joint_calling ; target:vcf; target_merge_vcf; bed_to_coverage }

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

if (params.joint_calling) {	
	process make_gvcf {

		label 'dragen'

		publishDir "${params.outdir}/${libraryID}/", mode: 'copy'

		input:
		set indivID, sampleID, libraryID, rgID, platform_unit, platform, platform_model, center, date, fastqR1, fastqR2 from alignReads
		file(bed) from target_gvcf.collect()

		output:
		file("${outdir}/*.gvcf.gz") into Gvcf
		set val(indivID),val(sampleID),file("${outdir}/*.bam"),file("${outdir}/*.bai") into Bam
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


		input:
		file(gvcfs) from Gvcf.collect()
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

} else {

	process make_vcf {

		label 'dragen'

                publishDir "${params.outdir}/${libraryID}/", mode: 'copy'

                input:
                set indivID, sampleID, libraryID, rgID, platform_unit, platform, platform_model, center, date, fastqR1, fastqR2 from alignReads
                file(bed) from target_vcf.collect()

                output:
                file(vcf) into Vcf
                set val(indivID),val(sampleID),file(bam),file(bai) into Bam
                file("${outdir}/*.csv") into BamQC

                script:
                vcf = sampleID + ".vcf.gz"
		bam = sampleID + ".bam"
		bai = bam + ".bai"
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
                        --intermediate-results-dir ${params.dragen_tmp} \
                        --RGID $rgID \
			--RGSM $sampleID \
                        --RGCN $center \
                        --RGDT $date \
                        --RGLB $libraryID \
                        --output-directory $outdir \
                        --output-file-prefix $sampleID \
                        --output-format $out_format
                	
			mv $outdir/$vcf $vcf
			mv $outdir/$bam $bam
			mv $outdir/$bai $bai
		"""
        }
}

if (params.qc)  {

	if (params.wes) {

		process hc_metrics {

			publishDir "${params.outdir}/${indivID}/${sampleID}/Processing/Picard_Metrics", mode: 'copy'

			input:
			set val(indivID), val(sampleID), file(bam), file(bai) from Bam
			file(targets) from TargetsToHS.collect()
			file(baits) from BaitsToHS.collect()

			output:
			file(outfile) into HybridCaptureMetricsOutput mode flatten
			file(outfile_per_target)

			script:
			outfile = indivID + "_" + sampleID + ".hybrid_selection_metrics.txt"
			outfile_per_target = indivID + "_" + sampleID + ".hybrid_selection_per_target_metrics.txt"

			"""
			picard -Xmx${task.memory.toGiga()}G CollectHsMetrics \
		                INPUT=${bam} \
        		        OUTPUT=${outfile} \
	        	        PER_TARGET_COVERAGE=${outfile_per_target} \
	        	        TARGET_INTERVALS=${targets} \
        	        	BAIT_INTERVALS=${baits} \
	        	        REFERENCE_SEQUENCE=${FASTA} \
        	        	MINIMUM_MAPPING_QUALITY=$params.min_mapq \
	                	TMP_DIR=tmp
	        	"""
		}

	}

	process coverage {

		publishDir "${params.outdir}/${indivID}/${sampleID}/Processing/", mode: 'copy'		
	
		input:
		set val(indivID),val(sampleID),file(bam),file(bai) from BamToCoverage
		file(bed) from bed_to_coverage.collect()

		output:
	        set file(genome_bed_coverage),file(genome_global_coverage) into Coverage

        	script:
	        base_name = bam.getBaseName()
        	genome_bed_coverage = base_name + ".mosdepth.region.dist.txt"
	        genome_global_coverage = base_name + ".mosdepth.global.dist.txt"

        	"""
                	mosdepth -t ${task.cpus} -n -f $REF -x -Q 10 -b $bed $base_name $bam
	        """
	}
}
