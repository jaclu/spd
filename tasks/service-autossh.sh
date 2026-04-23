#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    # Handling of service tasks
    [ -z "$SPD_SOURCED_SERVICE_HANDLER" ] && {
        source_it "$D_REPO"/tools/service-handler.sh
    }

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare
    check_service_env autossh
    command -v autossh >/dev/null 2>&1 || {
        lbl_2 "Dependency issue - autossh not found"
        spd_dependency_issue=1
    }
    # _cmd=/usr/local/bin/logger
    # [ -x "$_cmd" ] || {
    #     lbl_2 "Dependency issue - $_cmd not found"
    #     [ "$spd_dependency_issue" = 0 ] && spd_dependency_issue=2
    # }

    return "$spd_dependency_issue"
}

replace_line_ending_in_tag() {
    _rleik_replacement_line="$1"
    _rleik_tag="$2"
    _rleik_file="$3"

    # tmp_file_create
    # sed "s|.*# ${_rleik_tag}\$|${_rleik_replacement_line}|" "$_rleik_file" >"$f_tmp" \
    #     && mv "$f_tmp" "$_rleik_file"
    # tmp_file_remove
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task"

    # shellcheck disable=SC2154 # SPD_SVC_AUTOSSH_RUNLVL defined via config
    process_service

    # replace_line_ending_in_tag \
    #     "${SPD_SVC_AUTOSSH_REVERSE_PORT}:localhost:${SPD_SVC_SSHD_PORT}" \
    #     "# LOOPBACK_DIRECIVE" \
    #     /etc/init.d/autossh

}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="service_auossh.sh"
# shellcheck disable=SC2034 # service_name used by caller
service_name=autossh

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

# Ensure options are valid
case "$opt_task" in
    install | remove) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install/remove"
        ;;
esac

parse_yaml_config_file "$D_REPO"/configs/task/service_autossh.yml

ensure_spd_var_defined SPD_SVC_AUTOSSH_REVERSE_PORT # LOOPBACK_DIRECIVE
ensure_spd_var_defined SPD_SVC_SSHD_PORT            # LOOPBACK_DIRECIVE
ensure_spd_var_defined SPD_SVC_AUTOSSH_KEY_FILE
ensure_spd_var_defined SPD_SVC_AUTOSSH_JUMP_PORT
ensure_spd_var_defined SPD_SVC_AUTOSSH_JUMP_HOST

task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
