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
    lbl_2 "$module_name: Executing task"
    check_for_abort 0 task_execute

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

[ -n "$D_REPO" ] || {
    std_alone="$module_name"
    #  Run this in stand-alone mode
    D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck source=tools/prepare-env.sh
    . "$D_REPO"/tools/prepare-env.sh
}

if ! is_ish && ! is_ish_aok && ! is_chrooted_ish; then
    err_msg "$module_name: Rejected, not running on iSH related platform"
fi

# by know we now this runs on some kind of iSH platform
get_config "$D_REPO"/configs/platform/ish.yml
is_ish_aok && get_config "$D_REPO"/configs/platform/ish_aok.yml

#
# Ensure required options have been set, and expand any variables that need to be expanded
#

# ensure_spd_var_defined SPD_APK_INSTALL

# Ensure options are valid
case "$opt_task" in
    install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install"
        ;;
esac

[ "$std_alone" = "$module_name" ] && {
    # In stand-alone mode, we want to run the entire task
    task_prepare
    task_execute
}
