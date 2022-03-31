process manta {

	label 'manta'

	publishDir "${params.outdir}/${indivID}/${SampleID}/Manta", mode: 'copy'

	input:
	tuple val(indivID),val(sampleID),path(bam),path(bai)
	tuple path(bed_gz),path(bed_gz_tbi)

	output:
	tuple val(indivID),val(sampleID),path(sv),path(sv_tbi), emit: diploid_sv
	tuple val(indivID),val(sampleID),path(sv_can),path(sv_can_tbi), emit: candidate_sv
	tuple val(indivID),val(sampleID),path(indel),path(indel_tbi), emit: small_indels

	script:
	sv = "${indivID}_${sampleID}.diploidSV.vcf.gz"
	sv_tbi = sv + ".tbi"
	indel = "${indivID}_${sampleID}.candidateSmallIndels.vcf.gz"
	indel_tbi = indel + ".tbi"
	sv_can = "${indivID}_${sampleID}.candidateSV.vcf.gz"
	sv_can_tbi = sv_can + ".tbi"

	"""
		configManta.py --bam $bam --referenceFasta ${params.fasta} --runDir manta --callRegions $bed_gz --exome

		manta/runWorkflow.py -j ${task.cpus}

		cp manta/results/variants/diploidSV.vcf.gz $sv
		cp manta/results/variants/diploidSV.vcf.gz.tbi $sv_tbi
		cp manta/results/variants/candidateSmallIndels.vcf.gz $indel
		cp manta/results/variants/candidateSmallIndels.vcf.gz.tbi $indel_tbi
		cp manta/results/variants/candidateSV.vcf.gz $sv_can
		cp manta/results/variants/candidateSV.vcf.gz.tbi $sv_can_tbi

	"""

}

