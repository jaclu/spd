#!/bin/sh

old_mtr_cleanup() {
    # Since a tmp folder
    _omc_msg="$1"
    dbg_msg "old_mtr_cleanup() $_omc_msg" 1
    [ -n "$d_tmp" ] && [ -d "$d_tmp" ] && {
        safe_remove --silent --remove-dir "$d_tmp" || {
            err_msg "$module_name: Failed to remove temporary directory $d_tmp"
        }
    }
    [ "$f_tmp" != /dev/stdout ] && {
        [ -n "$_omc_msg" ] && {
            # Only display content if there is an error message to display
            cat "$f_tmp"
        }
        dbg_msg "Removing temporary file: $f_tmp" 1
        tmp_file_remove
    }
    # if a param is provided, treat it as an error message and exit
    [ -n "$_omc_msg" ] && err_msg "$_omc_msg"
    dbg_msg "old_mtr_cleanup() completed successfully" 1
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
    if [ "$current_dbg_lvl" -gt 0 ]; then
        f_tmp=/dev/stdout
    else
        tmp_file_create
        dbg_msg "Created temporary file for command output: $f_tmp" 1
    fi

    # Create temporary directory for downloaded mtr files
    d_tmp="$(mktemp -d "${TMPDIR:-/tmp}"/old-mtr.XXXXXX)" || {
        err_msg "Failed to create temporary directory for old mtr"
    }
    dbg_msg "Created temporary directory for old mtr: $d_tmp" 1

    [ "$_auom_mtr_found" -eq 1 ] && {
        lbl_4 "Removing current mtr version: $(mtr -v)"
        # Remove incorrect version
        apk del mtr >"$f_tmp" 2>&1 || old_mtr_cleanup "Failed to remove current mtr"
    }

    #
    #  Download and install specific older mtr
    #
    cd "$d_tmp" || old_mtr_cleanup "Failed to cd to temporary directory $d_tmp"
    url_prefix="https://dl-cdn.alpinelinux.org/alpine/v3.10/main/x86"

    lbl_4 "Installing older mtr-0.92-r0.apk"
    wget "$url_prefix"/mtr-0.92-r0.apk >"$f_tmp" 2>&1 || {
        old_mtr_cleanup "Failed to download mtr-0.92-r0.apk"
    }
    apk add mtr-0.92-r0.apk >"$f_tmp" 2>&1 || {
        old_mtr_cleanup "Failed to install mtr-0.92-r0.apk"
    }
    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    yaml_true "$SPD_PKGS_MAN" && {
        lbl_4 "Installing mtr-doc-0.92-r0.apk"
        wget "$url_prefix"/mtr-doc-0.92-r0.apk >"$f_tmp" 2>&1 || {
            old_mtr_cleanup "Failed to download mtr-doc-0.92-r0.apk"
        }
        apk add mtr-doc-0.92-r0.apk >"$f_tmp" 2>&1 || {
            old_mtr_cleanup "Failed to install mtr-doc-0.92-r0.apk"
        }
    }
    old_mtr_cleanup
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
    alpine_release_ge 3.20 && {
        alpine_use_old_mtr || {
            err_msg "$module_name: Failed to install old mtr for Alpine < 3.20"
        }
    }
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

    return "$SPD_DEPENDENCY_ISSUE"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task"

    is_musl_lib || {
        # musl doesn't need locale-gen, and it doesn't even have it, so skip this step if musl is used

        # Generate required locales
        # shellcheck disable=SC2154 # defined in config
        lbl_3 "Generating required locales: $SPD_LOCALES"
        # shellcheck disable=SC2086 # should be expanded
        locale-gen $SPD_LOCALES || {
            err_msg "$module_name: Failed to generate required locales"
        }
    }

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

ensure_spd_var_defined SPD_PKGS_MAN
is_musl_lib || ensure_spd_var_defined SPD_LOCALES

if fs_is_alpine; then
    "$D_REPO"/tasks/FileSystem-Alpine.sh "$opt_task"
elif fs_is_devuan; then
    "$D_REPO"/tasks/FileSystem-Devuan.sh "$opt_task"
elif fs_is_debian; then
    "$D_REPO"/tasks/FileSystem-Debian.sh "$opt_task"
else
    err_msg "$module_name: Unsupported filesystem, cannot continue"
fi

# "$D_REPO"/tasks/service-runbg.sh "$opt_task"
# "$D_REPO"/tasks/service-autossh.sh "$opt_task"

echo # Spacer before this task begins
task_prepare
task_execute
