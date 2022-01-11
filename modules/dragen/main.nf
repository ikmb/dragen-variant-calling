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
	tuple val(famID),path("${outdir}/*.gvcf.gz")
	tuple val(indivID),val(sampleID),path("${outdir}/*.${params.out_format}"),path("${outdir}/*.${params.out_index}")
	tuple val(indivID),val(sampleID)
	path("${outdir}")
	tuple path(dragen_start),path(dragen_end)

	script:
	gvcf = sampleID + ".gvcf.gz"
	outdir = sampleID + "_results"
	dragen_start = sampleID + "dragen_log.gvcf.start.log"
	dragen_end = sampleID + "dragen_log.gvcf.end.log"

	def options = ""
	if (params.exome) {
		options = options.concat("--vc-target-bed $bed ")
		if (params.cnv) {
			options = options.concat("--cnv-target-bed $bed --cnv-enable-self-normalization true --cnv-interval-width 500 ")
		}
		if (params.sv) {
			options = options.concat("--sv-target-bed $bed ")
		}
	} else {
		if (params.cnv) {
			options = options.concat("--cnv-enable-self-normalization true --cnv-interval-width 1000 ")
		}
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
		--intermediate-results-dir ${params.dragen_tmp} \
		--output-directory $outdir \
		--output-file-prefix $sampleID \
		--output-format $params.out_format $options

	/opt/edico/bin/dragen_lic -f genome &> $dragen_end

	"""
}

// Merge gVCFs into multi-sample gVCF
process merge_gvcfs {

	label 'dragen'

	publishDir "${params.outdir}/Dragen/gVCF", mode: 'copy'

	input:
	path(gvcfs)
	path(bed)

	output:
	path(merged_gvcf)
	path("merged_vcf/*")
	tuple path(dragen_start),path(dragen_end)

	script:
	def options = ""
	if (params.exome) {
		options = "--gg-regions ${bed}"
	}
	merged_gvcf = params.run_name + ".gvcf.gz"

	dragen_start = params.run_name + ".dragen_log.merge_gvcf.start.log"
	dragen_end = params.run_name + ".dragen_log.merge_gvcf.end.log"

	"""
	
		/opt/edico/bin/dragen_lic -f genome &> $dragen_start

		for i in \$(echo *.gvcf.gz)
       			do echo \$i >> variants.list
	        done

		mkdir -p merged_vcf

		/opt/edico/bin/dragen -f \
			-r ${params.dragen_ref_dir} \
			--enable-combinegvcfs true \
			--output-directory merged_vcf \
			--output-file-prefix ${params.run_name} \
			--intermediate-results-dir ${params.dragen_tmp} \
			$options \
			--variant-list variants.list

		mv merged_vcf/*vcf.gz . 

		/opt/edico/bin/dragen_lic -f genome &> $dragen_end
	"""
}

// Take single gVCFs and call trio analysis
process trio_call {

	label 'dragen'

	publishDir "${params.outdir}/Dragen/TrioCall", mode: 'copy'

	input:
	tuple val(famID),path(gvcfs)
	path(bed)
	path(samplesheet)

	output:
	path("*hard-filtered.vcf.gz")
	path("results")
	tuple path(dragen_start),path(dragen_end)

	script:

	prefix = params.run_name + ".trio"
	def options = ""
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

       	publishDir "${params.outdir}/Dragen/JointCall", mode: 'copy'

	input:
	path(mgvcf) 
	path(bed)

	output:
	path("*hard-filtered.vcf.gz")
	path("results/*")
	tuple path(dragen_start),path(dragen_end)

	script:
	prefix = params.run_name + ".joint_genotyped"
	dragen_start = params.run_name + ".dragen_log.joint_calling.start.log"
	dragen_end = params.run_name + ".dragen_log.joint_calling.end.log"
		
	"""

		/opt/edico/bin/dragen_lic -f genome &> $dragen_start

		mkdir -p results

		/opt/edico/bin/dragen -f \
		-r ${params.dragen_ref_dir} \
		--enable-joint-genotyping true \
		--intermediate-results-dir ${params.dragen_tmp} \
		--variant $mgvcf \
		--dbsnp $params.dbsnp \
		--output-directory results \
		--output-file-prefix $prefix

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
	path(vcf)
	tuple val(indivID),val(sampleID),path(bam),path(bai)
	path("${outdir}/*")
	tuple path(dragen_start),path(dragen_end)

	script:
	vcf = sampleID + ".vcf.gz"
	bam = sampleID +  "." + params.out_format
	bai = bam + "." + params.out_index
	outdir = sampleID + "_results"

	dragen_start = sampleID + ".dragen_log.vcf.start.log"
	dragen_end = sampleID + ".dragen_log.vcf.end.log"
			
	def options = ""

	if (params.exome) {
		options = options.concat("--vc-target-bed $bed ")
		if (params.cnv) {
                	options = options.concat("--cnv-target-bed $bed --cnv-enable-self-normalization true  --cnv-interval-width 500 ")
                }
                if (params.sv) {
			options = options.concat("--sv-target-bed $bed ")
                }
        } else {
		if (params.cnv) {
			options = options.concat("--cnv-enable-self-normalization true --cnv-interval-width 1000 ")
                }
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
                	
			mv $outdir/$vcf $vcf
			mv $outdir/$bam $bam
			mv $outdir/$bai $bai

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
