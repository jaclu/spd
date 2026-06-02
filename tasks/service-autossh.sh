#!/bin/sh
#
# Part of https://github.com/jaclu/spd
#
# Copyright (c) 2026 Jacob Lundqvist <jacob.lndqvist@gmail.com>
# License: MIT
#

replace_line_ending_in_tag() {
    _rleik_replacement_line="$1"
    _rleik_tag="$2"
    _rleik_file="$3"

    [ -f "$_rleik_file" ] || {
        err_msg "replace_line_ending_in_tag() - File not found: $_rleik_file"
    }
    _rleik_rp=$(realpath "$_rleik_file") || {
        err_msg "replace_line_ending_in_tag() - Failed to find realpath for: $_rleik_file"
    }
    _rleik_f_tmp=$(mktemp "${TMPDIR:-/tmp}/autossh-config.XXXXXX") || {
        err_msg "replace_line_ending_in_tag() - mktemp failed"
    }
    chmod 755 "$_rleik_f_tmp" || err_msg "replace_line_ending_in_tag() - failed to chmod"
    sed "s|.*# ${_rleik_tag}\$|${_rleik_replacement_line}|" "$_rleik_rp" >"$_rleik_f_tmp" \
        && mv "$_rleik_f_tmp" "$_rleik_rp"
    _ex_code="$?"
    [ "$_ex_code" -ne 0 ] && {
        rm -f "$_rleik_f_tmp" # ensure tmp file is removed
        err_msg "replace_line_ending_in_tag() - failed to process tag: $_rleik_tag"
    }
}

tweak_script_file() {
    # shellcheck disable=SC2154 # f_service_script defined in service-handler.sh
    lbl_3 "tweak_script_file() - $f_service_script" 1

    # shellcheck disable=SC2154 # SPD_ vars via config files
    replace_line_ending_in_tag \
        "loopback_directive=\"\$reverse_port:localhost:$SPD_SVC_SSHD_PORT\"" \
        "SPD_SVC_SSHD_PORT" \
        "$f_service_script"

    # shellcheck disable=SC2154 # SPD_ vars via config files
    replace_line_ending_in_tag \
        "key_file=\"$SPD_SVC_AUTOSSH_KEY_FILE\"" \
        "SPD_SVC_AUTOSSH_KEY_FILE" \
        "$f_service_script"

    # shellcheck disable=SC2154 # SPD_ vars via config files
    replace_line_ending_in_tag \
        "jump_port=$SPD_SVC_AUTOSSH_JUMP_PORT" \
        "SPD_SVC_AUTOSSH_JUMP_PORT" \
        "$f_service_script"

    # shellcheck disable=SC2154 # SPD_ vars via config files
    replace_line_ending_in_tag \
        "jump_account=\"${SPD_UNAME}@$SPD_SVC_AUTOSSH_JUMP_HOST\"" \
        "SPD_SVC_AUTOSSH_JUMP_HOST" \
        "$f_service_script"
}

task_prepare() {
    # In order to get a comprehensive listing of failed dependencies,
    # this pass just flags issues

    [ -z "$service_handler_is_sourced" ] && {
        # Load handler of service tasks
        source_it "$D_REPO"/tools/service-handler.sh
    }

    lbl_2 "Preparing task" 1
    check_for_abort 1 task_prepare

    ls -l /etc/init.d/sshd >/dev/null 2>&1 || {
        lbl_3 "Required service not in use: sshd" 1
        spd_dependency_issue=1
    }

    command -v "$service_name" >/dev/null 2>&1 || {
        package_install "$service_name" || spd_dependency_issue=1
    }

    check_service_env "$service_name"

    # _cmd=/usr/local/bin/logger
    # [ -x "$_cmd" ] || {
    #     lbl_2 "Dependency issue - $_cmd not found"
    #     [ "$spd_dependency_issue" = 0 ] && spd_dependency_issue=2
    # }
    return "$spd_dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "Executing task" 1

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

# Can it run here?
is_linux || err_msg "This can't run on non-Linux platforms"
check_for_abort 0 "$0"
case "$opt_task" in # Ensure options are valid
    install | remove | force | force-install) ;;
    *) cmd_line_param_error "opt_task must be install / force-install / remove" ;;
esac

parse_yaml_config_file "$D_REPO"/configs/task/service_autossh.yml
# always do this last, after any other config files parsed!
parse_yaml_config_file "$D_REPO"/configs/global_overrides.yml

#
# Expand any variables that need to be expanded
#
lbl_2 "Config variables used" 2

expand_show_spd_var SPD_SVC_SSHD_PORT
expand_show_spd_var SPD_SVC_AUTOSSH_KEY_FILE
expand_show_spd_var SPD_SVC_AUTOSSH_JUMP_PORT
expand_show_spd_var SPD_UNAME
expand_show_spd_var SPD_SVC_AUTOSSH_JUMP_HOST

task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
