#!/bin/sh

early_start_runbg() {
    # to allow for backgrounding on ish during deploy this is a manual
    # runbg equivalent
    is_ish || return 1
    [ -c /dev/location ] || {
        lbl_2 "Can't activate backgrounding feature - no valid /dev/location"
        return 1
    }
    pgrep -f "cat /dev/location" >/dev/null && {
        lbl_2 "Backgrounding feature already active"
        return 1
    }
    cat /dev/location >/dev/null &
    lbl_2 "iSH can now run in the background"
    return 0
}

reactivate_busybox_uptime() {
    if [ ! -L /usr/bin/uptime ] \
        || [ "$(readlink -f /usr/bin/uptime)" != "/bin/busybox" ]; then
        lbl_3 "Linking /usr/bin/uptime to /bin/busybox"
        if [ -e /usr/bin/uptime ]; then
            rm -f /usr/bin/uptime.ORG # only remove .ORG if it will be replaced
            mv -f /usr/bin/uptime /usr/bin/uptime.ORG || exit 30
        fi
        ln -sf /bin/busybox /usr/bin/uptime || exit 31
    fi
}

alpine_use_old_mtr() {
    _auom_mtr_found=0
    if command -v mtr >/dev/null; then
        _auom_mtr_found=1
        [ "$(mtr -v)" = "mtr 0.91.1-4c982" ] && {
            # lbl_4 "Correct old mtr version already installed, skipping"
            return 0 # correct "old" version installed
        }
    fi

    lbl_3 "Alpine >= 3.20 detected, installing older mtr, able to run with IP# in iSH"

    [ "$_auom_mtr_found" -eq 1 ] && {
        lbl_4 "Removing current mtr version: $(mtr -v)"
        # Remove incorrect version
        cmd_filtered apk del mtr
    }
    #
    #  Download and install specific older mtr
    #
    # Create temporary directory for downloaded mtr files
    tmp_file_create -d d_downloads
    # shellcheck disable=SC2154 # d_downloads created via tmp_file_create
    cd "$d_downloads" || err_msg "Failed to cd to temporary directory $d_downloads"
    url_prefix="https://dl-cdn.alpinelinux.org/alpine/v3.10/main/x86"

    lbl_4 "Downloading older mtr-0.92-r0.apk"
    cmd_filtered wget "$url_prefix"/mtr-0.92-r0.apk
    lbl_4 "Installing downloaded mtr-0.92-r0.apk"
    cmd_filtered apk add mtr-0.92-r0.apk
    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    yaml_true "$SPD_PKGS_MAN" && {
        lbl_4 "Downloading mtr-doc-0.92-r0.apk"
        cmd_filtered wget "$url_prefix"/mtr-doc-0.92-r0.apk
        lbl_4 "Installing downloaded mtr-doc-0.92-r0.apk"
        cmd_filtered apk add mtr-doc-0.92-r0.apk
    }
    tmp_file_remove "$d_downloads"
    return 0
}

ish_alpine_tasks() {
    # iSH using Alpine FS
    fs_is_alpine || return 1

    [ -d /ish ] && {
        lbl_3 "Removing iSH Alpine auto repository updater"
        rm -rf /ish || {
            err_msg "$module_name: Failed to remove /ish directory"
        }
    }
    alpine_release_ge 93.20 && alpine_use_old_mtr
    reactivate_busybox_uptime
}

ish_aok_tasks() {
    # iSH-AOK specific tasks
    is_ish_aok || return 1
    lbl_3 "Copying iSH-AOK bins to /usr/local/bin"

    # Install iSH AOK specific files
    cp -a "$D_REPO"/files/platform/ish/AOK/usr_local_bin/* /usr/local/bin/ || {
        err_msg "$module_name: Failed to copy iSH AOK files to /usr/local/bin"
    }
}

ish_not_aok_tasks() {
    # Should only be done when kernel is not iSH-AOK
    is_ish_aok && return 1

    lbl_3 "Only if kernel is not iSH-AOK"
    lbl_4 "Copying custom uptime to /usr/local/bin"
    cp -a "$D_REPO"/files/platform/ish/not-AOK/usr_local_bin/uptime /usr/local/bin/ || {
        err_msg "$module_name: Failed to copy custom uptime to /usr/local/bin"
    }
}

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare

    return "$spd_dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task"

    lbl_3 "Copying iSH bins to /usr/local/bin"
    cp -a "$D_REPO"/files/platform/ish/usr_local_bin/* /usr/local/bin/ || {
        err_msg "$module_name: Failed to copy iSH files to /usr/local/bin"
    }

    fs_is_alpine && ish_alpine_tasks

    if is_ish_aok; then
        ish_aok_tasks
    else
        ish_not_aok_tasks
    fi

    # FS Alpine

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

# [ -z "$current_dbg_lvl" ] && {
#     #
#     # In case current_dbg_lvl has been exported to the env, do not override it
#     # otherwise default to 1 in order to display progress for cmd_filtered
#     # since sctipt-utils.sh hasn't been sourced yet and thus set_debug_lvl is not
#     # yet available. In addition that script would default it to 0 if undefined.
#     # All this results in that we have to manually set the variable directly
#     # at this point to both have an opinion and respect current env preferences
#     #
#     export current_dbg_lvl=0
# }

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

if ! is_ish && ! is_ish_aok && ! is_chrooted_ish; then
    err_msg "$module_name: Rejected, not running on iSH related platform"
fi

# Ensure options are valid
case "$opt_task" in
    force | force-install)
        lbl_1 "WARNING this task runs other tasks, they will all use force-install - be warned!"
        ;;
    install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install / force-install"
        ;;
esac

early_start_runbg

#
# Ensure required options have been set, and expand any variables that need to be expanded
#
ensure_spd_var_defined SPD_PKGS_MAN

if fs_is_alpine; then
    "$D_REPO"/tasks/FileSystem-Alpine.sh "$opt_task" || script_utils_cleanup 1
elif fs_is_devuan; then
    "$D_REPO"/tasks/FileSystem-Devuan.sh "$opt_task" || script_utils_cleanup 1
elif fs_is_debian; then
    "$D_REPO"/tasks/FileSystem-Debian.sh "$opt_task" || script_utils_cleanup 1
else
    err_msg "$module_name: Unrecognized filesystem, cannot continue"
fi

# Services
"$D_REPO"/tasks/service-runbg.sh "$opt_task" || script_utils_cleanup 1
command -v autossh >/dev/null && {
    "$D_REPO"/tasks/service-autossh.sh "$opt_task" || script_utils_cleanup 1
}

# "$D_REPO"/tasks/service-runbg.sh "$opt_task"
# "$D_REPO"/tasks/service-autossh.sh "$opt_task"

echo # Spacer before this task begins
task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
