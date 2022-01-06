include { dragen_version ; software_versions } from "./../../modules/logging/main.nf" params(params)

workflow SOFTWARE_VERSIONS {

	main:
		dragen_version()
		software_versions(dragen_version.out.collect())	

	emit:
		yaml = software_versions.out[0]
}
