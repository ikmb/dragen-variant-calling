// end-to-end single sample variant calling
process make_vcf {

	label 'dragen'

	publishDir "${params.outdir}/${meta.patient_id}/${meta.sample_id}/", mode: 'copy'

	input:
	tuple val(meta), path(lreads),path(rreads)
	path(bed)
	path(samplesheet)

	output:
	tuple val(meta),path("${outdir}/*filtered.vcf.gz"), emit: vcf
	tuple val(meta),path(bam),path(bai), emit: bam
	tuple val(meta),path("${outdir}/*"), emit: results
	tuple path(dragen_start),path(dragen_end), emit: log
        path("${outdir}/*.csv"), emit: qc
	tuple val(meta),path("${outdir}/*.sv.vcf.gz"), optional: true, emit: sv
	tuple val(meta),path("${outdir}/*.cnv.vcf.gz"), optional: true, emit: cnv

	script:
	def prefix = meta.sample_id
	vcf = prefix + ".hard-filtered.vcf.gz"
	vcf_tbi = vcf + ".tbi"
	bam = prefix + "." + params.out_format
	bai = bam + "." + params.out_index
	outdir = prefix + "_results"
	dragen_start = prefix + ".dragen_log.vcf.start.log"
	dragen_end = prefix + ".dragen_log.vcf.end.log"
			
	def options = ""
	def post = ""
	def mv_options = ""

	if (params.ml_dir) {
                options = options.concat(" --vc-ml-dir ${params.ml_dir} --vc-ml-enable-recalibration=true ")
        }
	if (params.exome) {
		mv_options = "mkdir -p $outdir/wgs && mv $outdir/*wgs*.csv $outdir/wgs"
		options = options.concat("--vc-target-bed $bed ")
		if (params.cnv) {
                	options = options.concat("--cnv-target-bed $bed ")
			if (params.cnv_panel) {
				options = options.concat("--cnv-normals-list ${params.cnv_panel} ")
			} else {
				options = options.concat("--cnv-enable-self-normalization true ")
			} 
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
		post = "manta2alissa.pl -i ${outdir}/${meta.sample_id}.sv.vcf.gz -o ${outdir}/${meta.sample_id}.sv2alissa.vcf"
        }
                  
        """

		/opt/edico/bin/dragen_lic -f genome &> $dragen_start

		mkdir -p $outdir
		
		samplesheet2dragen.pl --samples $samplesheet > files.csv

                /opt/edico/bin/dragen -f \
                        -r ${params.dragen_ref_dir} \
			--fastq-list files.csv \
                        --fastq-list-sample-id ${meta.sample_id} \
                        --read-trimmers none \
                        --enable-variant-caller true \
                        --enable-map-align-output true \
                        --enable-map-align true \
                        --enable-duplicate-marking true \
			--dbsnp $params.dbsnp \
			${options} \
                        --intermediate-results-dir ${params.dragen_tmp} \
                        --output-directory $outdir \
                        --output-file-prefix ${prefix} \
                        --output-format $params.out_format
                	
			mv $outdir/$bam $bam
			mv $outdir/$bai $bai

		$mv_options	
		$post

		/opt/edico/bin/dragen_lic -f genome &> $dragen_end
	"""
}
