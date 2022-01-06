process intervals_to_bed {

	executor 'local'
	label 'default'
	
	input:
	path(targets)

	output:
	path(bed)

	script:
	bed = targets.getBaseName() + ".bed"

	"""
		picard IntervalListTools I=$targets O=targets.padded.interval_list PADDING=$params.interval_padding
		picard IntervalListToBed I=targets.padded.interval_list O=$bed
	"""

} 
