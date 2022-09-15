include { DRAGEN_VERSION } from "./../../modules/logging/main.nf" params(params)

workflow SOFTWARE_VERSIONS {

	main:
		DRAGEN_VERSION
		software_versions(DRAGEN_VERSION.out)
	emit:
		yaml = software_versions.out

}
