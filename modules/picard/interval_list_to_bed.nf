process PICARD_INTERVAL_LIST_TO_BED {

    tag "${targets}"
    
	executor 'local'

    container 'quay.io/biocontainers/picard:3.0.0--hdfd78af_1'
	
	input:
	path(targets)

	output:
	path(bed_file), emit:bed

	script:
	bed_file = targets.getBaseName() + ".bed"

	"""
		picard IntervalListTools I=$targets O=targets.padded.interval_list PADDING=$params.interval_padding
		picard IntervalListToBed I=targets.padded.interval_list O=$bed_file
	"""

} 