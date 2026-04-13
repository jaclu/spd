#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare
    check_service_env runbg
    return "$dependency_issue"
}

task_execute() {
    # current_dbg_lvl=2
    lbl_2 "$module_name: Executing task"
    check_for_abort 0 task_execute

    # shellcheck disable=SC2154 # SPD_SVC_RUNBG_RUNLVL defined via config
    process_service "$SPD_SVC_RUNBG_RUNLVL"
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="service_runbg.sh"
# shellcheck disable=SC2034 # service_name used by svc_handler_common.sh
service_name=runbg

[ -n "$D_REPO" ] || {
    #  Run this in stand-alone mode
    D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck source=tools/prepare_env.sh
    . "$D_REPO"/tools/prepare_env.sh
}

# Ensure opions are valid
case "$opt_task" in
    install | remove) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install/remove"
        ;;
esac

source_it "$D_REPO"/tools/svc_handler_common.sh

read_config_file "$D_REPO"/configs/services/runbg.yml
read_config_file "$D_REPO"/configs/task_overrides/service_runbg.yml
read_config_file "$D_REPO"/configs/global_overrides.yml # local user overrides

ensure_spd_var_defined SPD_SERVICE_HANDLER
# expand_config_var SPD_ABORT

task_prepare && task_execute
