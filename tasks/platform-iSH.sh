#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare

    return "$dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task"

    # copy files/platform/ish/usr_local_bin/* to /usr/local/bin
    # Generate required locales

    # ish-AOK
    # copy files/platform/ish-aok/usr_local_bin/* to /usr/local/bin

    # FS Alpine
    # Remove iSH Alpine auto repository updater
    # Install old IP# able mtr 0.92-a
    # Ensure /usr/bin/uptime is symlink to /bin/busybox
    # Install etc/inittab-alpine
    # Install extras to /usr/local/bin
    # Generate sshd host keys
    # Link the fake init to /sbin/init

    # FS Devuan
    # Install custom /etc/init.d/rc
    # Generate required locales
    # Install etc/inittab-devuan

    # FS Debian, old version 10
    # Deploy custom_openssh {{ ift_openssh_tgz }}
    # Install custom /etc/init.d/rc
    # Link the fake init to /sbin/init
}

#=====================================================================
#
#   Main
#
#=====================================================================

#
#  Also handles sub-cattegory ish-aok
#
module_name="platform-iSH"

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

if ! is_ish && ! is_ish_aok && ! is_chrooted_ish; then
    err_msg "$module_name: Rejected, not running on iSH related platform"
fi

# Ensure options are valid
case "$opt_task" in
    install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install"
        ;;
esac

if fs_is_alpine; then
    "$D_REPO"/tasks/FileSystem-Alpine.sh "$opt_task"
elif fs_is_devuan; then
    "$D_REPO"/tasks/FileSystem-Devuan.sh "$opt_task"
elif fs_is_debian; then
    "$D_REPO"/tasks/FileSystem-Debian.sh "$opt_task"
else
    err_msg "$module_name: Unsupported filesystem, cannot continue"
fi

"$D_REPO"/tasks/service-runbg.sh "$opt_task"
"$D_REPO"/tasks/service-autossh.sh "$opt_task"

echo # Spacer before this task begins
task_prepare
task_execute
