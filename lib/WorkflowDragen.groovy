//
// This file holds several functions specific to the workflow/esga.nf in the nf-core/esga pipeline
//

class WorkflowDragen {

    //
    // Check and validate parameters
    //
    public static void initialise(params, log) {

        if (!params.run_name) {
            log.info "Must provide a --run_name!"
            System.exit(1)
        }

        if (params.joint_calling && params.trio) {
            log.info "Cannot specify joint-calling and trio analysis simultaneously"
            System.exit(1)
        }
        
        if (params.kit && !params.exome || params.exome && !params.kit) {
            log.info "Exome analysis requires both --kit and --exome"
            System.exit(1)
        }

        if (params.exome && !params.kit && !params.targets) {
            log.info "Exome analysis requires either a pre-configured --kit or --targets and --baits"
            System.exit(1)
        }

        if (params.targets && !params.baits || !params.targets && params.baits) {
            log.info "If you provide custom calling regions, you have to specify both --targets and --baits!"
            System.exit(1)
        }
        
        if (!params.assembly) {
            log.info "Must provide an assembly name (--assembly)"
            System.exit(1)
        }

        if (params.exome && params.clingen) {
            log.info "Cannot run the clinical gene sub-pipeline on exome data!"
            System.exit(1)
        }

    }

}
