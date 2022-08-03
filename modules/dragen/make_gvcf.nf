// MODULE FILE
// Dragen variant caller

// Process FastQ files into gVCF and BAM/CRAM
process make_gvcf {
		
	label 'dragen'

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/", mode: 'copy'

	input:
	tuple val(meta),path(lreads),path(rreads)
	path(bed)
	path(samplesheet)

	output:
	tuple val(meta),path("${outdir}/*.gvcf.gz"), emit: gvcf
	tuple val(meta),path("${outdir}/${align}"),path("${outdir}/${align_index}"), emit: bam
	val(meta), emit: sample
	path("${outdir}/*"), emit: results
	tuple path(dragen_start),path(dragen_end), emit: log
	path("${outdir}/*.csv"), emit: qc
	path("${outdir}/${meta.sample_id}.target.counts.gc-corrected.gz"), optional: true, emit: targets

	script:
	gvcf = meta.sample_id + ".gvcf.gz"
	align = meta.sample_id + "." + params.out_format
	align_index = align + "." + params.out_index
	outdir = meta.sample_id + "_results"
	dragen_start = meta.sample_id + "dragen_log.gvcf.start.log"
	dragen_end = meta.sample_id + "dragen_log.gvcf.end.log"

	def options = ""
	if (params.ml_dir) {
		options = options.concat(" --vc-ml-dir=${params.ml_dir} --vc-ml-enable-recalibration=true ")
	}
	if (params.exome) {
		options = options.concat("--vc-target-bed $bed ")
		if (params.cnv) {
			options = options.concat("--cnv-target-bed $bed ")
			if (params.cnv_panel) {
				options = options.concat("--cnv-normals-list ${params.cnv_panel} ")
			} else {
				options.concat("--cnv-enable-self-normalization true ")
			}
		}
		if (params.sv) {
			options = options.concat("--sv-exome true --sv-call-regions-bed $bed ")
		}
	} else {
		if (params.clingen) {
			options = options.concat(" --enable-cyp2d6=true --enable-smn=true --enable-gba=true ")
		}
		if (params.cnv) {
			options = options.concat(" --cnv-enable-self-normalization true --cnv-interval-width 1000 ")
		}
	}
	if (params.expansion_hunter) { 
                options = options.concat(" --repeat-genotype-enable=true --repeat-genotype-specs=${params.expansion_json} ")
        }
	if (params.hla) {
		options = options.concat(" --enable-hla true ")
	}
	if (params.cnv) {
		options = options.concat("--enable-cnv true ")
	}
	if (params.sv) {
		options = options.concat("--enable-sv true ")
	}
	"""

	/opt/edico/bin/dragen_lic -f genome &> $dragen_start

	mkdir -p $outdir

	samplesheet2dragen.pl --samples $samplesheet > files.csv

	/opt/edico/bin/dragen -f \
		-r ${params.dragen_ref_dir} \
		--fastq-list files.csv \
		--fastq-list-sample-id ${meta.sample_id} \
		--read-trimmers none \
		--enable-variant-caller true \
		--enable-map-align-output true \
		--enable-map-align true \
		--enable-duplicate-marking true \
		--vc-emit-ref-confidence GVCF \
		--vc-enable-vcf-output true \
		--intermediate-results-dir ${params.dragen_tmp} \
		--output-directory $outdir \
		--output-file-prefix ${meta.sample_id} \
		--output-format $params.out_format $options

	/opt/edico/bin/dragen_lic -f genome &> $dragen_end

	"""
}
