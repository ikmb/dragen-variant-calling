process VALIDATE_SAMPLESHEET {

	label 'default'

	tag "${csv}"

	input:
	path(csv)

	output:
	path(ss)

	script:
	ss = "Samples.validated.csv"
	def options = ""
	if (params.trio) {
		options = "--trio 1"
	}

	"""
		validate_samplesheet.pl --infile $csv $options
		cp $csv $ss
	"""
}

process TARGET_METRICS {

	tag "${meta.sample_id}"

	label 'default'

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/Picard_Metrics", mode: 'copy'

	input:
	tuple val(meta), file(bam), file(bai)
	path(targets)
	path(baits) 

	output:
	path(outfile)
	path(outfile_per_target)

	script:
	outfile = meta.patient_id + "_" + meta.sample_id + ".hybrid_selection_metrics.txt"
	outfile_per_target = meta.patient_id + "_" + meta.sample_id + ".hybrid_selection_per_target_metrics.txt"

	"""
	picard -Xmx${task.memory.toGiga()}G CollectHsMetrics \
                INPUT=${bam} \
	        OUTPUT=${outfile} \
       	        PER_TARGET_COVERAGE=${outfile_per_target} \
       	        TARGET_INTERVALS=${targets} \
        	BAIT_INTERVALS=${baits} \
       	        REFERENCE_SEQUENCE=${params.ref} \
        	MINIMUM_MAPPING_QUALITY=$params.min_mapq \
               	TMP_DIR=tmp
       	"""
}

process WGS_METRICS {

	tag "${meta.sample_id}"

	label 'mosdepth'

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/Metrics", mode: 'copy'
	
	input:
	tuple val(meta),path(bam),path(bai)
	path(bed)

	output:
	path(genome_global_coverage)

	script:
	base_name = bam.getBaseName()
	genome_bed_coverage = base_name + ".mosdepth.region.dist.txt"
	genome_global_coverage = base_name + ".mosdepth.global.dist.txt"

	"""
		mosdepth -t ${task.cpus} -n -f ${params.ref} -x -Q 10 -b $bed $base_name $bam
	"""
}

