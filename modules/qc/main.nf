process target_metrics {

	label 'default'

	publishDir "${params.outdir}/${indivID}/${sampleID}/Picard_Metrics", mode: 'copy'

	input:
	tuple val(indivID), val(sampleID), file(bam), file(bai)
	path(targets)
	path(baits) 

	output:
	path(outfile)
	path(outfile_per_target)

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
       	        REFERENCE_SEQUENCE=${params.ref} \
        	MINIMUM_MAPPING_QUALITY=$params.min_mapq \
               	TMP_DIR=tmp
       	"""
}
