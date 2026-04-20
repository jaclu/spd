#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0

    # Handling of service tasks
    [ -z "$SPD_SOURCED_SERVICE_HANDLER" ] && {
        source_it "$D_REPO"/tools/service-handler.sh
    }

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare
    check_service_env runbg

    # is_ish || { # disabled during deubgging, re-enable once done
    #     lbl_2 "Dependency issue - Can only be used on iSH"
    #     # shell check disable=SC2034 # dependency_issue used by caller
    #     [ "$dependency_issue" = 0 ] && dependency_issue=2
    # }
    return "$dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task"
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
# shell check source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

# Ensure options are valid
case "$opt_task" in
    install | remove) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install/remove"
        ;;
esac

get_config "$D_REPO"/configs/task/service_runbg.yml

task_prepare
task_execute
