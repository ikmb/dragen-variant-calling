include { expansion_hunter; expansion2xlsx } from "./../../modules/expansionhunter/main.nf" params(params)

workflow EXPANSION_HUNTER {

	take:
		bam
		catalog

	main:
		expansion_hunter(bam,catalog.collect())
		expansion2xlsx(expansion_hunter.out[0])

	emit:
		expansions = expansion2xlsx.out

}
	
