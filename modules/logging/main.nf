process dragen_version {

	publishDir "${params.outdir}/DragenLogs/", mode: 'copy'

	label 'dragen'

	output:
	path(dragen_log)

	script:
	dragen_log = "v_dragen.txt"

	"""
		/opt/edico/bin/dragen -V &> $dragen_log
	"""
}

process dragen_usage {

	publishDir "${params.outdir}/DragenLogs/", mode: 'copy'

	input:
	path(logs)

	output:
	path(yaml)

	script:
	yaml = "dragen_usage_mqc.yaml"

	"""
		dragen_usage.pl -u $params.dragen_unit_cost > $yaml
	"""

}

process software_versions {

	publishDir "${params.outdir}/Summary/versions", mode: 'copy'

	input:
	path('*')

	output:
	path(yaml_file)
	path("v*.txt")

	script:
	yaml_file = "software_versions_mqc.yaml"

	"""
 		echo $workflow.manifest.version &> v_ikmb_dragen_variant_calling.txt
		echo $workflow.nextflow.version &> v_nextflow.txt
		parse_versions.pl >  $yaml_file
	"""

}
