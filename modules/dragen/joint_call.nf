process JOINT_CALL {

	tag "${meta.patient_id}|${meta.sample_id}"

	label 'dragen'

    publishDir "${params.outdir}/JointCalling", mode: 'copy'

	input:
	tuple val(meta),path(gvcfs) 
	path(bed)

	output:
	tuple val(meta),path("*hard-filtered.vcf.gz"), emit: vcf
	path("results/*"), emit: results
	tuple path(dragen_start),path(dragen_end), emit: log

	script:
	prefix = params.run_name + ".joint_genotyped"
	dragen_start = params.run_name + ".dragen_log.joint_calling.start.log"
	dragen_end = params.run_name + ".dragen_log.joint_calling.end.log"

	def options = ""
	if (params.ml_dir) {
        options = options.concat(" --vc-ml-dir ${params.ml_dir} --vc-ml-enable-recalibration=true")
    }
	
	"""

		/opt/edico/bin/dragen_lic -f genome &> $dragen_start

		mkdir -p results

		/opt/edico/bin/dragen -f \
		-r ${params.dragen_ref_dir} \
		--enable-joint-genotyping true \
		--intermediate-results-dir ${params.dragen_tmp} \
		--variant ${gvcfs.join( ' --variant ')} \
		--dbsnp $params.dbsnp \
		--output-directory results \
		--output-file-prefix $prefix \
		$options

		mv results/*vcf.gz* . 

		/opt/edico/bin/dragen_lic -f genome &> $dragen_end

	"""
}
