process hc_metrics {

	label 'default'

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
       	        REFERENCE_SEQUENCE=${REF} \
        	MINIMUM_MAPPING_QUALITY=$params.min_mapq \
               	TMP_DIR=tmp
       	"""
}

process multiqc {

	label 'default'

	publishDir "${params.outdir}/MultiQC", mode: 'copy'

	input:
	path('*')

	output:
	file("multiqc_report.html") into MultiQC

	script:

	"""
		multiqc . 
	"""	
}
