// MODULE FILE
// Dragen variant caller

// Process FastQ files into gVCF and BAM/CRAM
process make_gvcf {
		
	label 'dragen'

	publishDir "${params.outdir}/${indivID}/${sampleID}/", mode: 'copy'

	input:
	tuple val(famID),val(indivID), val(sampleID), path(lreads),path(rreads)
	path(bed)
	path(samplesheet)

	output:
	tuple val(famID),path("${outdir}/*.gvcf.gz"), emit: gvcf
	path("${outdir}/*.gvcf.gz"), emit: gvcf_no_fam
	tuple val(indivID),val(sampleID),path("${outdir}/*.${params.out_format}"),path("${outdir}/*.${params.out_index}"), emit: bam
	tuple val(indivID),val(sampleID), emit: sample
	path("${outdir}/*"), emit: results
	tuple path(dragen_start),path(dragen_end), emit: log
	path("${outdir}/*.csv"), emit: qc

	script:
	gvcf = sampleID + ".gvcf.gz"
	outdir = sampleID + "_results"
	dragen_start = sampleID + "dragen_log.gvcf.start.log"
	dragen_end = sampleID + "dragen_log.gvcf.end.log"

	def options = ""
	if (params.ml_dir) {
		options = options.concat(" --vc-ml-dir=${params.ml_dir} --vc-ml-enable-recalibration=true ")
	}
	if (params.exome) {
		options = options.concat("--vc-target-bed $bed ")
		if (params.cnv) {
			options = options.concat("--cnv-target-bed $bed --cnv-enable-self-normalization true --cnv-interval-width 500 ")
		}
		if (params.sv) {
			options = options.concat("--sv-exome true --sv-call-regions-bed $bed ")
		}
	} else {
		if (params.clingen) {
			options = options.concat(" --enable-cyp2d6=true --enable-smn=true --enable-gba=true ")
		}
		if (params.cnv) {
			options = options.concat(" --cnv-enable-self-normalization true --cnv-interval-width 1000 ")
		}
	}
	if (params.expansion_hunter) { 
                options = options.concat(" --repeat-genotype-enable=true --repeat-genotype-specs=${params.expansion_json} ")
        }
	if (params.hla) {
		options = options.concat(" --enable-hla true ")
	}
	if (params.cnv) {
		options = options.concat("--enable-cnv true ")
	}
	if (params.sv) {
		options = options.concat("--enable-sv true ")
	}
	"""

	/opt/edico/bin/dragen_lic -f genome &> $dragen_start

	mkdir -p $outdir

	samplesheet2dragen.pl --samples $samplesheet > files.csv

	/opt/edico/bin/dragen -f \
		-r ${params.dragen_ref_dir} \
		--fastq-list files.csv \
		--fastq-list-sample-id $sampleID \
		--read-trimmers none \
		--enable-variant-caller true \
		--enable-map-align-output true \
		--enable-map-align true \
		--enable-duplicate-marking true \
		--vc-emit-ref-confidence GVCF \
		--vc-enable-vcf-output true \
		--intermediate-results-dir ${params.dragen_tmp} \
		--output-directory $outdir \
		--output-file-prefix $sampleID \
		--output-format $params.out_format $options

	/opt/edico/bin/dragen_lic -f genome &> $dragen_end

	"""
}

// Take single gVCFs and call trio analysis
process trio_call {

	label 'dragen'

	publishDir "${params.outdir}/TrioCall", mode: 'copy'

	input:
	tuple val(famID),path(gvcfs)
	path(bed)
	path(samplesheet)

	output:
	path("*hard-filtered.vcf.gz"), emit: vcf
	path("results/*"), emit: results
	tuple path(dragen_start),path(dragen_end), emit: log

	script:

	prefix = params.run_name + ".trio"
	def options = ""
	if (params.ml_dir) {
                options = options.concat(" --vc-ml-dir ${params.ml_dir} --vc-ml-enable-recalibration=true")
        }
	if (params.exome) {
                options = "--vc-target-bed $bed "
	}

	dragen_start = famID + ".dragen_log.trio.start.log"
	dragen_end = famID + ".dragen_log.trio.end.log"

	"""

		/opt/edico/bin/dragen_lic -f genome &> $dragen_start

		samplesheet2ped.pl --samples $samplesheet > family.ped

		mkdir -p results 

		/opt/edico/bin/dragen -f \
			-r ${params.dragen_ref_dir} \
			--variant ${gvcfs.join( ' --variant ')} \
			--pedigree-file family.ped \
			--intermediate-results-dir ${params.dragen_tmp} \
			--dbsnp $params.dbsnp \
			--output-directory results \
			--output-file-prefix $prefix \
			--enable-joint-genotyping true \
			$options			
					
			cp results/*.vcf.gz* . 

		/opt/edico/bin/dragen_lic -f genome &> $dragen_end
	"""
}

// Joint variant calls from merged gVCF
process joint_call {

	label 'dragen'

       	publishDir "${params.outdir}/JointCall", mode: 'copy'

	input:
	path(gvcfs) 
	path(bed)

	output:
	path("*hard-filtered.vcf.gz"), emit: vcf
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

// end-to-end single sample variant calling
process make_vcf {

	label 'dragen'

	publishDir "${params.outdir}/${indivID}/${sampleID}/", mode: 'copy'

	input:
	tuple val(famID),val(indivID), val(sampleID), path(lreads),path(rreads)
	path(bed)
	path(samplesheet)

	output:
	path(vcf), emit: vcf
	tuple val(indivID),val(sampleID),path(bam),path(bai), emit: bam
	path("${outdir}/*"), emit: results
	tuple path(dragen_start),path(dragen_end), emit: log
        path("${outdir}/*.csv"), emit: qc

	script:
	vcf = sampleID + ".hard-filtered.vcf.gz"
	vcf_tbi = vcf +".tbi"
	bam = sampleID +  "." + params.out_format
	bai = bam + "." + params.out_index
	outdir = sampleID + "_results"

	dragen_start = sampleID + ".dragen_log.vcf.start.log"
	dragen_end = sampleID + ".dragen_log.vcf.end.log"
			
	def options = ""
	if (params.ml_dir) {
                options = options.concat(" --vc-ml-dir ${params.ml_dir} --vc-ml-enable-recalibration=true ")
        }
	if (params.exome) {
		options = options.concat("--vc-target-bed $bed ")
		if (params.cnv) {
                	options = options.concat("--cnv-target-bed $bed --cnv-enable-self-normalization true  --cnv-interval-width 500 ")
                }
                if (params.sv) {
			options = options.concat("--sv-exome true --sv-call-regions-bed $bed ")
                }
        } else {
                if (params.clingen) {
                        options = options.concat(" --enable-cyp2d6=true --enable-smn=true ")
                }
		if (params.cnv) {
			options = options.concat("--cnv-enable-self-normalization true --cnv-interval-width 1000 ")
                }
        }
	if (params.expansion_hunter) {
                options = options.concat(" --repeat-genotype-enable=true --repeat-genotype-specs=${params.expansion_json} ")
        }
        if (params.hla) {
                options = options.concat(" --enable-hla true ")
        }
	if (params.cnv) {
		options = options.concat("--enable-cnv true ")
        }
	if (params.sv) {
        	options = options.concat("--enable-sv true ")
        }
                  
        """

		/opt/edico/bin/dragen_lic -f genome &> $dragen_start

		mkdir -p $outdir
		
		samplesheet2dragen.pl --samples $samplesheet > files.csv

                /opt/edico/bin/dragen -f \
                        -r ${params.dragen_ref_dir} \
			--fastq-list files.csv \
                        --fastq-list-sample-id $sampleID \
                        --read-trimmers none \
                        --enable-variant-caller true \
                        --enable-map-align-output true \
                        --enable-map-align true \
                        --enable-duplicate-marking true \
			--dbsnp $params.dbsnp \
			${options} \
                        --intermediate-results-dir ${params.dragen_tmp} \
                        --output-directory $outdir \
                        --output-file-prefix $sampleID \
                        --output-format $params.out_format
                	
			mv $outdir/$bam $bam
			mv $outdir/$bai $bai
			mv $outdir/*filtered.vcf.gz $vcf
			mv $outdir/*filtered.vcf.gz.tbi $vcf_tbi

		/opt/edico/bin/dragen_lic -f genome &> $dragen_end
	"""
}

process call_cnvs {

	label 'dragen'
	
	publishDir "${params.outdir}/${indivID}/${sampleID}/CNVs", mode: 'copy'

	input:
	tuple val(indivID),val(sampleID),path(bam),path(bai)
	path(bed)

	output:
	path(results)

	script:	

	def input_option = "--bam-input"
	if (params.cram) {
		input_option = "--cram-input"
	}

	def options = ""
	if (params.exome) {
		options = options.concat("--cnv-target-bed $bed --cnv-enable-self-normalization true  --cnv-interval-width 500 ")
	} else {
		optoins = options.concat("--cnv-enable-self-normalization true --cnv-interval-width 1000 ")
	}

	results = "cnv_" + sampleID
	
	"""
		mkdir -r $results

		/opt/edico/bin/dragen -f \
			-r ${params.dragen_ref_dir} \
			$input_option $bam \
			--output-directory $results \
			--output-file-prefix $sampleID \
			--enable-map-align false \
			--enable-cnv true \
			$options 	

	"""
}
