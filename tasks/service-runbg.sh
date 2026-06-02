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

    is_ish_abstract || {
        lbl_2 "Dependency issue - Can only be used on iSH"
        [ "$spd_dependency_issue" = 0 ] && spd_dependency_issue=2
    }
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

# Can it run here?
is_linux || err_msg "This can't run on non-Linux platforms"
check_for_abort 0 "$0"
case "$opt_task" in # Ensure options are valid
    install | remove | force | force-install) ;;
    *) cmd_line_param_error "opt_task must be install / force-install / remove" ;;
esac

parse_yaml_config_file "$D_REPO"/configs/task/service_runbg.yml
# always do this last, after any other config files parsed!
parse_yaml_config_file "$D_REPO"/configs/global_overrides.yml

task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
