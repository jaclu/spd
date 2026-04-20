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
    lbl_2 "$module_name: Preparing task"

    check_for_abort 1 task_prepare

    d_files_base="$D_REPO"/files/all_distros
    return "$dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task"

    copy_items "$d_files_base"/usr_local_bin /usr/local/bin
    copy_items "$d_files_base"/usr_local_sbin /usr/local/sbin
    copy_items "$d_files_base"/etc/sudoers.d/sudo_no_passwd /etc/sudoers.d
    is_ish_aok && rm -f /usr/local/bin/uptime
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="All Distros"

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

# Ensure options are valid
case "$opt_task" in
    install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install"
        ;;
esac

task_prepare
task_execute
