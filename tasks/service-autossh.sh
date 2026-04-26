#!/bin/sh

replace_line_ending_in_tag() {
    _rleik_replacement_line="$1"
    _rleik_tag="$2"
    _rleik_file="$3"

    _rleik_f_tmp=$(mktemp "${TMPDIR:-/tmp}/autossh-config.XXXXXX") || {
        err_msg "replace_line_ending_in_tag() - mktemp failed"
    }
    chmod 755 "$_rleik_f_tmp" || err_msg "replace_line_ending_in_tag() - failed to chmod"
    sed "s|.*# ${_rleik_tag}\$|${_rleik_replacement_line}|" "$_rleik_file" >"$_rleik_f_tmp" \
        && mv "$_rleik_f_tmp" "$_rleik_file"
    _ex_code="$?"
    [ "$_ex_code" -ne 0 ] && {
        rm -f "$_rleik_f_tmp" # ensure tmp file is removed
        err_msg "replace_line_ending_in_tag() - failed to process tag: $_rleik_tag"
    }
}

tweak_script_file() {
    lbl_3 "tweak_script_file() - /etc/init.d/autossh" 1
    # shellcheck disable=SC2154 # SPD_ variables defined via config
    # shellcheck disable=SC2154 # SPD_ variables defined via config
    replace_line_ending_in_tag \
        "loopback_directive=\"${SPD_SVC_AUTOSSH_REVERSE_PORT}:localhost:$SPD_SVC_SSHD_PORT\"" \
        "LOOPBACK_DIRECTIVE" \
        /etc/init.d/autossh

    # shellcheck disable=SC2154 # SPD_ vars via config files
    replace_line_ending_in_tag \
        "key_file=\"$SPD_SVC_AUTOSSH_KEY_FILE\"" \
        "SPD_SVC_AUTOSSH_KEY_FILE" \
        /etc/init.d/autossh

    # shellcheck disable=SC2154 # SPD_ vars via config files
    replace_line_ending_in_tag \
        "jump_port=$SPD_SVC_AUTOSSH_JUMP_PORT" \
        "SPD_SVC_AUTOSSH_JUMP_PORT" \
        /etc/init.d/autossh

    # shellcheck disable=SC2154 # SPD_ vars via config files
    replace_line_ending_in_tag \
        "jump_account=\"${SPD_UNAME}@$SPD_SVC_AUTOSSH_JUMP_HOST\"" \
        "SPD_SVC_AUTOSSH_JUMP_HOST" \
        /etc/init.d/autossh
}

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    [ -z "$service_handler_is_sourced" ] && {
        # Load handler of service tasks
        source_it "$D_REPO"/tools/service-handler.sh
    }

    lbl_2 "$module_name: Preparing task" 1
    check_for_abort 1 task_prepare
    check_service_env autossh

    command -v autossh >/dev/null 2>&1 || {
        package_install autossh || spd_dependency_issue=1
    }

    # _cmd=/usr/local/bin/logger
    # [ -x "$_cmd" ] || {
    #     lbl_2 "Dependency issue - $_cmd not found"
    #     [ "$spd_dependency_issue" = 0 ] && spd_dependency_issue=2
    # }
    return "$spd_dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task" 1

    process_service

    case "$opt_task" in
        install | force | force-install) tweak_script_file ;;
        *) ;;
    esac
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="service-auossh"
# shellcheck disable=SC2034 # service_name used by caller
service_name=autossh

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

# Ensure options are valid
case "$opt_task" in
    install | remove | force | force-install) ;;
    *) cmd_line_param_error "opt_task must be install / force-install / remove" ;;
esac

parse_yaml_config_file "$D_REPO"/configs/task/service_autossh.yml
parse_yaml_config_file "$D_REPO"/configs/global_overrides.yml # always do this last!

#
# Expand any variables that need to be expanded
#
lbl_2 "Config variables used" 2

ensure_spd_var_defined SPD_SVC_AUTOSSH_REVERSE_PORT # LOOPBACK_DIRECTIVE
ensure_spd_var_defined SPD_SVC_SSHD_PORT            # LOOPBACK_DIRECTIVE
expand_show_spd_var SPD_SVC_AUTOSSH_KEY_FILE
expand_show_spd_var SPD_SVC_AUTOSSH_JUMP_PORT
ensure_spd_var_defined SPD_UNAME
ensure_spd_var_defined SPD_SVC_AUTOSSH_JUMP_HOST

task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
