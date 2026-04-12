#!/bin/sh

copy_items() {
    f_src="$1"
    d_dst="$2"
    lbl_2 "copy from $f_src"
    lbl_2 "  to $d_dst"
    mkdir -p "$d_dst" || err_msg "Failed: mkdir -p $d_dst"

    if [ -d "$f_src" ]; then
        cp -a "$f_src"/* "$d_dst" || err_msg "$module_name: Failed to copy to $d_dst"
    else
        cp -a "$f_src" "$d_dst" || err_msg "$module_name: Failed to copy to $d_dst"
    fi
}

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0

    check_for_abort 1 task_prepare

    d_files_base="$DEPLOY_PATH"/files/all_distros
    return "$dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute

    copy_items "$d_files_base"/usr_local_bin /usr/local/bin
    copy_items "$d_files_base"/usr_local_sbin /usr/local/sbin
    copy_items "$d_files_base"/etc/sudoers.d/sudo_no_passwd /etc/sudoers.d
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
module_name="all_distros.sh"

task_prepare && task_execute
