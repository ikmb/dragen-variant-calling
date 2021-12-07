// MODULE FILE
// Dragen variant caller

// Process FastQ files into gVCF and BAM/CRAM
process make_gvcf {
		
	label 'dragen'

	publishDir "${params.outdir}/${indivID}/${sampleID}/", mode: 'copy'

	input:
	tuple val(indivID), val(sampleID), path(lreads),path(rreads)
	path(bed)

	output:
	path("${outdir}/*.gvcf.gz")
	tuple val(indivID),val(sampleID),path("${outdir}/*.bam"),path("${outdir}/*.bai")
	path("${outdir}/*.csv")
	path(log)

	script:
	gvcf = sampleID + ".gvcf.gz"
	outdir = sampleID + "_results"
	log = sampleID + "_gvcf.log"

	def options = ""
	if (params.exome) {
		options = "--vc-target-bed $bed "
		if (params.cnv) {
			options += "--cnv-target-bed $bed "
		}
		if (params.sv) {
			options += "--sv-target-bed $bed "
		}
	} else {
		if (params.cnv) {
			options += "--cnv-enable-self-normalization true --cnv-wgs-interval-width 250"
		}
	}
		  
	if (params.cnv) {
		options += "--enable-cnv true "
	}
	if (params.sv) {
		options += "--enable-sv true "
	}
	"""
	mkdir -p $outdir

	dragen_file_list.pl > files.csv

	/opt/edico/bin/dragen -f \
		-r ${params.dragen_ref_dir} \
		--fastq-list files.csv \
		--fastq-list-sample-id $sampleID \
		--read-trimmers none \
		--enable-variant-caller true \
		--enable-map-align-output true \
		--enable-map-align true \
		--enable-duplicate-marking true \
		$options \
		--vc-emit-ref-confidence GVCF \
		--intermediate-results-dir ${params.dragen_tmp} \
		--output-directory $outdir \
		--output-file-prefix $sampleID \
		--output-format $out_format &> $log
	"""
}

// Merge gVCFs into multi-sample gVCF
process merge_gvcfs {

	label 'dragen'

	publishDir "${params.outdir}/gVCF", mode: 'copy'

	input:
	path(gvcfs)
	path(bed)

	output:
	path(merged_gvcf)
	path("merged_vcf/*")

	script:
	def options = ""
	if (params.exome) {
		options = "--gg-regions ${bed}"
	}
	merged_gvcf = params.run_name + ".gvcf.gz"

	"""

		for i in \$(echo *.gvcf.gz)
       			do echo \$i >> variants.list
	        done

		mkdir -p merged_vcf

		/opt/edico/bin/dragen -f \
			-r ${params.dragen_ref_dir} \
			--enable-combinegvcfs true \
			--output-directory merged_vcf \
			--output-file-prefix $run_name \
			--intermediate-results-dir ${params.dragen_tmp} \
			$options \
			--variant-list variants.list

		mv merged_vcf/*vcf.gz . 
	"""
}

// Take single gVCFs and call trio analysis
process trio_call {

	label 'dragen'

	publishDir "${params.outdir}/TrioCall", mode: 'copy'

	input:
	path(gvcfs)
	path(bed)
	path(ped)

	output:
	path("*.vcf.gz")
	path("results")

	script:

	prefix = params.run_name + ".trio"
	def options = ""
	if (params.exome) {
                options = "--vc-target-bed $bed "
	}

	"""
		/opt/edico/bin/dragen -f \
			-r ${params.dragen_ref_dir} \
			--variant ${gvcfs.join( '--variant ')} \
			--pedigree-file $ped \
			--intermediate-results-dir ${params.dragen_tmp} \
			--dbsnp $params.dbsnp \
			--output-directory results \
			--output-file-prefix $prefix \
			--enable-joint-genotyping true \
			$options			
					
			cp results/*.vcf.gz* . 
	"""
}

// Joint variant calls from merged gVCF
process joint_call {

	label 'dragen'

       	publishDir "${params.outdir}/JointCall", mode: 'copy'

	input:
	path(mgvcf) 
	path(ref) 
	path(bed)

	output:
	path("*.vcf.gz")
	path("results/*")

	script:
	prefix = params.run_name + ".joint_genotyped"
	
	"""
		mkdir -p results

		/opt/edico/bin/dragen -f \
		-r ${params.dragen_ref_dir} \
		--enable-joint-genotyping true \
		--intermediate-results-dir ${params.dragen_tmp} \
		--variant $mgvcf \
		--dbsnp $params.dbsnp \
		--output-directory results \
		--output-file-prefix $prefix \
		$options
		mv results/*vcf.gz* . 
	"""
}

// end-to-end single sample variant calling
process make_vcf {


	label 'dragen'

	 publishDir "${params.outdir}/${sampleID}/", mode: 'copy'
	input:
	set val(indivID), val(sampleID), path(lreads),path(rreads)
	path(bed) from target_vcf.collect()
	file(dragen_reset) from DragenReset.collect()

	output:
	path(vcf) into Vcf
	tuple val(indivID),val(sampleID),path(bam),path(bai)
	path("${outdir}/*.csv")
	path(dragen_log)

	script:
	vcf = sampleID + ".vcf.gz"
	bam = sampleID + ".bam"
	bai = bam + ".bai"
	outdir = sampleID + "_results"
	dragen_log = sampleID + "_vcf.log"
			
	def options = ""

	if (params.exome) {
		options = "--vc-target-bed $bed "
		if (params.cnv) {
                	options += "--cnv-target-bed $bed "
                }
                if (params.sv) {
			options += "--sv-target-bed $bed "
                }
        } else {
		if (params.cnv) {
			options += "--cnv-enable-self-normalization true --cnv-wgs-interval-width 250"
                }
        }

	if (params.cnv) {
		options += "--enable-cnv true "
        }
	if (params.sv) {
        	options += "--enable-sv true "
        }
                  
        """
		mkdir -p $outdir
		
		dragen_file_list.pl > files.csv

                /opt/edico/bin/dragen -f \
                        -r ${params.dragen_ref_dir} \
			--fastq-list files.csv \
                        --fastq-list-sample-id $sampleID \
                        --read-trimmers none \
                        --enable-variant-caller true \
                        --enable-map-align-output true \
                        --enable-map-align true \
                        --enable-duplicate-marking true \
			--dbsnp $DBSNP \
			${options} \
                        --intermediate-results-dir ${params.dragen_tmp} \
                        --output-directory $outdir \
                        --output-file-prefix $sampleID \
                        --output-format $out_format 2>&1 > $dragen_log
                	
			mv $outdir/$vcf $vcf
			mv $outdir/$bam $bam
			mv $outdir/$bai $bai
	"""
}

process calculate_used_bases {

	input:
	path('*')

	output:
	path(report)

	script:
	report = run_name + ".used_bases.json"

	"""

		sum_used_bases.pl > $report

	"""
}
