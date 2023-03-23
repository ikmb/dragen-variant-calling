process VALIDATE_SAMPLESHEET {

	tag "${csv}"

	input:
	path(csv)

	output:
	path(ss), emit: csv

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
