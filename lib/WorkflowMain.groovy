//
// This file holds several functions specific to the workflow/esga.nf in the nf-core/esga pipeline
//

class WorkflowMain {

    //
    // Check and validate parameters
    //
    //
    // Validate parameters and print summary to screen
    //
    public static void initialise(workflow, params, log) {
        // Print help to screen if required
        if (params.help) {
            log.info help(workflow, params, log)
            System.exit(0)
        }
    }

    public static String help(workflow, params, log) {
        def command = "nextflow run ${workflow.manifest.name} --samples Samples.csv --assembly GRCh38 --kit xGen_v2 -profile diagnostic"
        def help_string = ''
        // Help message
        helpMessage = """
        ===============================================================================
        IKMB DRAGEN pipeline | version ${workflow.manifest.version}
        ===============================================================================
        Usage: nextflow run ikmb/XXX

        Required parameters:
        --samples			Samplesheet in CSV format (see online documentation)
        --assembly			Assembly version to use (GRCh38)
        --exome				This is an exome dataset
        --email                        	Email address to send reports to (enclosed in '')
        --run_name			Name of this run
        --trio				Run this as trio analysis

        Optional parameters:
        --kit				Exome kit to use (xGen_v2)
        --expansion_hunter		Run expansion hunter (default: true)
        --vep				Run Variant Effect Predictor (default: true)
        --interval_padding		Add this many bases to the calling intervals (default: 10)
        --cnv				Enable CNV calling (not recommended for exomes)
        --sv				Enable SV calling (not recommended for exomes)
        --hla 				Enable calling of class I HLA alleles
        --clingen			Enable high-precision calling of challening genes (CYP2D6, SMN, GBA) - WGS only. 

        Expert options (usually not necessary to change!):

        Output:
        --outdir                       Local directory to which all output is written (default: results)
        """
        return help_string
    }

}
