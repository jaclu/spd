#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0

    check_for_abort 1 task_prepare

    fs_is_alpine || {
        lbl_2 "$module_name: Dependency issue - This is not running on an Alpine FS"
        dependency_issue=1
    }

    ensure_spd_var_defined SPD_APK_DEVEL
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
    # shellcheck source=/dev/null
    . "$DEPLOY_PATH"/tools/prepare_env.sh
}
module_name="file_systems/Alpine"

# Ensure opions are valid
# shellcheck disable=SC2154 # opt_task defined in prepare_env.sh
case "$opt_task" in
    install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install"
        ;;
esac


read_config_file "$DEPLOY_PATH"/configs/files_systems/alpine.yml

# current_dbg_lvl=2
# msg_dbg "before task_overrides"
ensure_spd_var_defined SPD_APK_INSTALL

# current_dbg_lvl=0
# # task overrides
read_config_file "$DEPLOY_PATH"/configs/task_overrides/filesystem_alpine.yml

# current_dbg_lvl=2
# msg_dbg "after task_overrides"
ensure_spd_var_defined SPD_APK_INSTALL

task_prepare && task_execute
