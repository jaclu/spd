#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    :
}

task_execute() {
    # perform the actual task
    :
}

task_cleanup() {
    # cleanup of any temp files etc created by the task
    :
}
# disable=SC2317
task_abort() {
    # restoration of all files/changes a task did, if unable to complete
    :
}

#=====================================================================
#
#   Main
#
#=====================================================================

echo "><> processing ask_apt_pkgs"

[ -n "$DEPLOY_PATH" ] || {
    #  Run this in stand-alone mode
    echo "><> task_apt_pkgs.sh in standalone"
    DEPLOY_PATH=$(cd -- "$(dirname -- "$0")/.." && pwd)
    . "$DEPLOY_PATH"/tools/prepare_env.sh
}

#
#. Expand all SPD_ variables before being used, order doesn't matter
#
expand_config_var SPD_ABORT

# shellcheck disable=SC2154 # SPD_ABORT defined in sourced config
[ "$SPD_ABORT" = 1 ] && err_msg "SPD_ABORT=1 prevents running on this host"
