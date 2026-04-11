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

# echo "><> processing ask_apt_pkgs"

[ -n "$DEPLOY_PATH" ] || {
    #  Run this in stand-alone mode
    # echo "><> task_apt_pkgs.sh in standalone"
    DEPLOY_PATH=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck disable=SC2034
    current_dbg_lvl=2
    # shellcheck source=/dev/null
    . "$DEPLOY_PATH"/tools/prepare_env.sh
}

#
#. Expand all SPD_ variables before being used, order doesn't matter
#
expand_config_var SPD_ABORT
expand_config_var SPD_APT_INSTALL
expand_config_var SPD_APT_PURGE

# shellcheck disable=SC2154 # SPD_ABORT defined in sourced config
{
    echo "SPD_APT_INSTALL: $SPD_APT_INSTALL"
    echo "SPD_APT_PURGE: $SPD_APT_PURGE"
    echo "SPD_ABORT: $SPD_ABORT"
    [ "$SPD_ABORT" = 1 ] && err_msg "SPD_ABORT=1 prevents running on this host"
}

is_linux || err_msg "Will not run apt on non-Linux"

[ -n "$SPD_APT_PURGE" ] && {
    apt -y purge "$SPD_APT_PURGE"
}

[ -n "$SPD_APT_INSTALL" ] && {
    apt -y install "$SPD_APT_INSTALL"
}
