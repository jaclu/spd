#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare
    check_service_env autossh
    command -v autossh >/dev/null 2>&1 || {
        lbl_2 "Dependency issue - autossh not found"
        # shell check disable=SC2034 # dependency_issue used by caller
        dependency_issue=1
    }
    # _cmd=/usr/local/bin/logger
    # [ -x "$_cmd" ] || {
    #     lbl_2 "Dependency issue - $_cmd not found"
    #     # shell check disable=SC2034 # dependency_issue used by caller
    #     [ "$dependency_issue" = 0 ] && dependency_issue=2
    # }

    return "$dependency_issue"
}

task_execute() {
    lbl_2 "$module_name: Executing task"
    check_for_abort 0 task_execute

    # shellcheck disable=SC2154 # SPD_SVC_AUTOSSH_RUNLVL defined via config
    process_service
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="service_auossh.sh"
# shellcheck disable=SC2034 # service_name used by caller
service_name=autossh

[ -n "$D_REPO" ] || {
    std_alone="$module_name"
    #  Run this in stand-alone mode
    D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck source=tools/prepare-env.sh
    . "$D_REPO"/tools/prepare-env.sh
}

# Ensure options are valid
case "$opt_task" in
    install | remove) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install/remove"
        ;;
esac

# Handling of service tasks
[ -z "$SPD_SOURCED_SVC_HANDLER_COMMON" ] && source_it "$D_REPO"/tools/svc_handler-common.sh

get_config "$D_REPO"/configs/task/service_autossh.yml

ensure_spd_var_defined SPD_SVC_AUTOSSH_KEY_FILE
ensure_spd_var_defined SPD_SVC_AUTOSSH_JUMP_HOST
ensure_spd_var_defined SPD_SVC_AUTOSSH_JUMP_PORT
ensure_spd_var_defined SPD_SVC_AUTOSSH_REVERSE_PORT

# Expand all variables before initiating service handler
source_it "$D_REPO"/tools/svc_handler-common.sh

[ "$std_alone" = "$module_name" ] && {
    task_prepare
    task_execute
}
