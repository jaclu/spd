#!/bin/sh
#
# Part of https://github.com/jaclu/spd
#
# Copyright (c) 2026 Jacob Lundqvist <jacob.lndqvist@gmail.com>
# License: MIT
#

task_prepare() {
    # In order to get a comprehensive listing of failed dependencies,
    # this pass just flags issues

    [ -z "$service_handler_is_sourced" ] && {
        # Load handler of service tasks
        source_it "$D_REPO"/tools/service-handler.sh
    }

    lbl_2 "$module_name: Preparing task" 1
    check_for_abort 1 task_prepare

    # lbl_2 "$module_name: Ensuring $service_name service is active" 1
    # ls -l /etc/init.d/sshd >/dev/null 2>&1 || spd_dependency_issue=1

    command -v "$service_name" >/dev/null 2>&1 || {
        if fs_is_alpine || fs_is_debian || fs_is_devuan; then
            package_install openssh-server || spd_dependency_issue=1
        fi
    }

    check_service_env sshd

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
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="service-sshd"
# shellcheck disable=SC2034 # service_name used by caller
service_name=sshd

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

parse_yaml_config_file "$D_REPO"/configs/task/service_sshd.yml
# always do this last, after any other config files parsed!
parse_yaml_config_file "$D_REPO"/configs/global_overrides.yml

#
# Expand any variables that need to be expanded
#
lbl_2 "Config variables used" 2

expand_show_spd_var SPD_SVC_SSHD_PORT

task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
