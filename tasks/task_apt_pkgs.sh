#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    dependency_issue=0

    check_for_abort 1 task_prepare

    command -v apt >/dev/null 2>&1 || {
        lbl_2 "$module_name: Dependency issue - apt not found"
        dependency_issue=1
    }
    # is_linux || err_msg "Will not run apt on non-Linux"

    read_config_file "$DEPLOY_PATH"/configs/PktHandlers/pkg_apt.yml
    #
    #. Expand all SPD_ variables before being used, order doesn't matter
    #
    expand_config_var SPD_APT_INSTALL
    expand_config_var SPD_APT_PURGE

    # shellcheck disable=SC2154 # SPD_ABORT defined in sourced config
    {
        echo "SPD_APT_INSTALL: $SPD_APT_INSTALL"
        echo "SPD_APT_PURGE: $SPD_APT_PURGE"
    }
    return "$dependency_issue"
}

task_execute() {
    check_for_abort
    # perform the actual task

    [ -n "$SPD_APT_PURGE" ] && {
        lbl_2 "Will purge apt packages: $SPD_APT_PURGE"
        # shellcheck disable=SC2086
        apt -y purge "$SPD_APT_PURGE"
    }

    [ -n "$SPD_APT_INSTALL" ] && {
        lbl_2 "Will install apt packages: $SPD_APT_INSTALL"
        # shellcheck disable=SC2086
        apt -y install $SPD_APT_INSTALL
    }
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
    DEPLOY_PATH=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck source=/dev/null
    . "$DEPLOY_PATH"/tools/prepare_env.sh
}
module_name="task_apt_pkgs.sh"

task_prepare || return 1
task_execute
