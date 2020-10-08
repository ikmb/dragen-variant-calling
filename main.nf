#!/usr/bin/env nextflow

REF = params.genomes[params.genome].reference

if (params.wgs) {
	BED = params.targets ?: params.genomes[params.assembly].targets
} else if {
	BED = params.targets ?: params.genomes[params.assembly].kits[ params.kit ].targets
} else {
	exit 1, "Must specifiy if you are running a WGS (--wgs) or WES (--wes) analysis"
}

ref_index = Channel.fromPath( file(REF) )
	.ifEmpty { exit 1, "Ref file not found, exiting..." }

targets = Channel.fromPath( file(BED) )
	.ifEmpty { exit 1, "Target file not found, existing..." }
	
Channel.fromFilePairs(params.reads, flat: true)
	.ifEmpty { exit 1, "Did not find any read files matching your input expression!" }
	.set {  alignReads; readsFastqc }

process runFastQC {

	label 'default'

	input:
	set val(lib),file(fastqR1),file(fastqR2) from readsFastqc

	output:

	script:

	"""
		fastqc -t 2 $fastqR1 $fastqR2
	"""
}

process makeGVCF {

	label 'dragen'

	publishDir "${params.outdir}/${lib}/gVCF", mode: 'copy'

	input:
        set val(lib),file(fastqR1),file(fastqR2) from alignReads
	file(bed) from targets.collect()
	file(ref) from ref_index.collect()

	output:
	file(gvcf) into Gvcf
	file("results/*")

	script:
	gvcf = "${sampleID}.gvcf.gz"

	"""
		dragen -f \
			-r $REF \
			-1 $fastqR1 \
			-2 $fastqR2 \
			--read-trimmers polyg \
			--enable-variant-caller true \
			--enable-duplicate-marking true \
			--vc-target-bed $bed \
			--vc-emit-ref-confidence GVCF \
			--RGID $rgID \
			--RGSM $sampleID \
			--output-directory results \
			--output-file-prefix $sampleID
		mv results/*.gvcf.gz .
	"""
}

process mergeGVCF {

	label 'dragen'

        publishDir "${params.outdir}/gVCF", mode: 'copy'

	input:
	file(gvcfs) from Gvcf.collect()

	output:
	file(multi_sample_vcf) into MultiVCF
	file("results/*")
	script:
	
	"""

		for i in $(echo *.gvcf.gz); do echo $i >> variants.list; done;

		dragen -f \
			-r $REF \
			--enable-joint-genotyping true \
			--output-directory results \
			--output-file-prefix $run_name \
			--vc-target-bed $bed \
			--ht-reference $REF \
			--intermediate-results-dir tmp \
			--variant-list variants.list

		mv results/*vcf.gz . 
	"""
}

process jointCall {

	label 'dragen'

        publishDir "${params.outdir}/JointCall", mode: 'copy'

	input:
	file(mgvcf) from MultiVCF

	output:
	file(vcf) 

	script:

	prefix = run_name + ".joint_genotyped"

	"""
		dragen -f \
			--enable-joint-genotyping true \
			--variant $mgvcf \
			--ref-dir $REF \
			--vc-target-bed $bed \
			--output-directory results \
			--output-file-prefix $prefix

		mv results/*vcf.gz . 
	"""
}

process runVcfstats {

	label 'default'	

}

process runBamstats {

	label 'default'
}
