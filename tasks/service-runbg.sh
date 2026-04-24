#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    # Handling of service tasks
    [ -z "$SPD_SOURCED_SERVICE_HANDLER" ] && {
        source_it "$D_REPO"/tools/service-handler.sh
    }

    lbl_2 "$module_name: Preparing task" 1
    is_ish_aok && [ "$opt_task" = install ] && {
        lbl_1 "WARNING: this service tends to fail on iSH-AOK" 1
        _m="If you still want to use it, run this with force-install instead of install"
        lbl_2 "$_m" 1
        # exit ok in order not to abort scripts that runs multiple
        # tasks, hopefully this warning explains the issue
        script_utils_cleanup 0
    }
    check_for_abort 1 task_prepare
    check_service_env runbg

    # is_ish || { # disabled during deubgging, re-enable once done
    #     lbl_2 "Dependency issue - Can only be used on iSH"
    #     [ "$spd_dependency_issue" = 0 ] && spd_dependency_issue=2
    # }
    return "$spd_dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task" 1
    process_service
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="service_runbg.sh"
# shellcheck disable=SC2034 # service_name used by caller
service_name=runbg

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
. "$D_REPO"/tools/prepare-env.sh

# Ensure options are valid
case "$opt_task" in
    remove | force | force-install) ;;
    install) ;;
    *)
        cmd_line_param_error "opt_task must be install/force-install/remove"
        ;;
esac

parse_yaml_config_file "$D_REPO"/configs/task/service_runbg.yml

task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
