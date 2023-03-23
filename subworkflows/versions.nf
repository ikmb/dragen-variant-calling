include { DRAGEN_VERSION ; SOFTWARE_VERSIONS } from "./../modules/logging/main.nf"

workflow VERSIONS {

	main:
		DRAGEN_VERSION()
		SOFTWARE_VERSIONS(
            DRAGEN_VERSION.out.collect()
        )	

	emit:
		yaml = SOFTWARE_VERSIONS.out.yaml
}
