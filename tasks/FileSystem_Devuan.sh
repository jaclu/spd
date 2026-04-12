#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0

    check_for_abort 1 task_prepare

    return "$dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
}

#=====================================================================
#
#   Main
#
#=====================================================================

[ -n "$DEPLOY_PATH" ] || {
    #  Run this in stand-alone mode
    DEPLOY_PATH=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck source=tools/prepare_env.sh
    . "$DEPLOY_PATH"/tools/prepare_env.sh
}
module_name="file_systems/Devuan"

# Ensure opions are valid
# shellcheck disable=SC2154 # opt_task defined in prepare_env.sh
case "$opt_task" in
    install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install"
        ;;
esac

# task overrides
source_it "$DEPLOY_PATH"/configs/tasks/filesystem_devuan.sh

task_prepare && task_execute
