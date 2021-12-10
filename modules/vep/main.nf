process vep {

	label 'vep'

	publishDir "${params.outdir}/VEP", mode: 'copy'

	input:
	path(vcf)

	output:
	path(vcf_annotated)

	script:
	vcf_annotated = vcf.getBaseName() + ".vep.vcf.gz"

        """
	        vep --offline \
                --cache \
                --dir ${params.vep_cache_dir} \
                --species homo_sapiens \
                --assembly $params.assembly \
                -i $vcf \
                --format vcf \
                -o $vcf_annotated --dir_plugins ${params.vep_plugin_dir} \
                --plugin dbNSFP,${params.dbnsfp_db},${params.dbnsfp_fields} \
                --plugin dbscSNV,${params.dbscsnv_db} \
                --plugin CADD,${params.cadd_snps},${params.cadd_indels} \
                --plugin ExACpLI \
                --plugin UTRannotator \
                --fasta $params.ref \
                --fork ${task.cpus} \
                --vcf \
                --per_gene \
                --sift p \
                --polyphen p \
                --check_existing \
                --canonical

                sed -i.bak 's/CADD_PHRED/CADD_phred/g' $vcf_annotated

        """
}

process vep2alissa {

	publishDir "${params.outdir}/VEP", mode: 'copy'

	input:
	path(vcf)

	output:
	path(alissa_vcf)

	script:
	alissa_vcf = vcf.getBaseName() + ".alissa2vep.vcf"

	"""
		vep2alissa.pl --infile $vcf > $alissa_vcf
	"""
}
