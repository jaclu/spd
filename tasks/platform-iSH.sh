#!/bin/sh

early_start_runbg() {
    # to allow for backgrounding on ish during deploy this is a manual
    # runbg equivalent
    is_ish || return 1
    [ -c /dev/location ] || {
        lbl_2 "Can't activate backgrounding feature - no valid /dev/location" 1
        return 1
    }
    pgrep -f "cat /dev/location" >/dev/null && {
        lbl_2 "Backgrounding feature already active" 1
        return 1
    }
    cat /dev/location >/dev/null &
    lbl_2 "iSH can now run in the background" 1
    return 0
}

reactivate_busybox_uptime() {
    #
    # iSH can't use /proc/uptime, simplest fix is to replace any bin uptime
    # with a symbolic link to busybox
    # iSH-AOK doesn't have this issue
    #
    is_ish_aok && return
    ! alpine_release_ge 3.19 && return # not an issue before 3.19

    if [ ! -L /usr/bin/uptime ] \
        || [ "$(readlink -f /usr/bin/uptime)" != "/bin/busybox" ]; then
        lbl_3 "Linking /usr/bin/uptime to /bin/busybox" 1
        if [ -e /usr/bin/uptime ]; then
            rm -f /usr/bin/uptime.ORG # only remove .ORG if it will be replaced
            mv -f /usr/bin/uptime /usr/bin/uptime.ORG || {
                err_msg "Failed to move /usr/bin/uptime -> /usr/bin/uptime.ORG"
            }
        fi
        ln -sf /bin/busybox /usr/bin/uptime || {
            err_msg "Failed to link /bin/busybox to /usr/bin/uptime"
        }
    fi
}

alpine_use_old_mtr() {
    _auom_mtr_found=0
    if command -v mtr >/dev/null; then
        _auom_mtr_found=1
        [ "$(mtr -v)" = "mtr 0.91.1-4c982" ] && {
            # lbl_4 "Correct old mtr version already installed, skipping" 1
            return 0 # correct "old" version installed
        }
    fi

    lbl_3 "Alpine >= 3.20 detected, installing older mtr, able to run with IP# in iSH" 1

    [ "$_auom_mtr_found" -eq 1 ] && {
        lbl_4 "Removing current mtr version: $(mtr -v)" 1
        # Remove incorrect version
        cmd_wrapper_t apk del mtr
    }
    #
    #  Download and install specific older mtr
    #
    # Create temporary directory for downloaded mtr files
    tmp_file_create -d d_downloads
    # shellcheck disable=SC2154 # d_downloads created via tmp_file_create
    cd "$d_downloads" || err_msg "Failed to cd to temporary directory $d_downloads"
    url_prefix="https://dl-cdn.alpinelinux.org/alpine/v3.10/main/x86"

    lbl_4 "Downloading older mtr-0.92-r0.apk" 1
    cmd_wrapper_t wget "$url_prefix"/mtr-0.92-r0.apk
    lbl_4 "Installing downloaded mtr-0.92-r0.apk" 1
    cmd_wrapper_t apk add mtr-0.92-r0.apk
    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    is_yaml_true "$SPD_PKGS_MAN" && {
        lbl_4 "Downloading mtr-doc-0.92-r0.apk" 1
        cmd_wrapper_t wget "$url_prefix"/mtr-doc-0.92-r0.apk
        lbl_4 "Installing downloaded mtr-doc-0.92-r0.apk" 1
        cmd_wrapper_t apk add mtr-doc-0.92-r0.apk
    }
    tmp_file_remove "$d_downloads"
    return 0
}

ish_alpine_tasks() {
    # iSH using Alpine FS
    fs_is_alpine || return 1

    [ -d /ish ] && {
        lbl_3 "Removing iSH Alpine auto repository updater" 1
        safe_remove /ish
        # rm -rf /ish || {
        #     err_msg "Failed to remove /ish directory"
        # }
    }
    # alpine_release_ge 3.20 && alpine_use_old_mtr # not used ATM
    is_ish_aok || reactivate_busybox_uptime

    # shellcheck disable=SC2154 # SPD_FILES_ISH_ALPINE_ULB vars via config files
    copy_items "$D_REPO"/files/platform/ish/FS/Alpine/usr_local_bin /usr/local/bin \
        "$SPD_FILES_ISH_ALPINE_ULB"
}

ish_debian_tasks() {
    # iSH using Debian FS
    fs_is_debian || return 1

    # shellcheck disable=SC2154 # SPD_FILES_ISH_* vars via config files
    {
        copy_items "$D_REPO"/files/platform/ish/FS/Debian/usr_local_bin \
            /usr/local/bin "$SPD_FILES_ISH_DEBIAN_ULB"

        copy_items "$D_REPO"/files/platform/ish/FS/Debian/usr_local_sbin \
            /usr/local/sbin "$SPD_FILES_ISH_DEBIAN_ULSB"
    }
}

ish_devuan_tasks() {
    # iSH using Devuan FS
    fs_is_devuan || return 1

    # shellcheck disable=SC2154 # SPD_FILES_ISH_* vars via config files
    {
        # Since Devuan can be seen as equiv of Debian in this context,
        # the same source folder is used, but file selection can be modified
        copy_items "$D_REPO"/files/platform/ish/FS/Debian/usr_local_bin \
            /usr/local/bin "$SPD_FILES_ISH_DEVUAN_ULB"
        copy_items "$D_REPO"/files/platform/ish/FS/Debian/usr_local_sbin \
            /usr/local/sbin "$SPD_FILES_ISH_DEVUAN_ULSB"
    }
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task" 1

    if fs_is_alpine; then
        ish_alpine_tasks
    elif fs_is_debian; then
        ish_debian_tasks
    elif fs_is_devuan; then
        ish_devuan_tasks
    fi

    # shellcheck disable=SC2154 # SPD_FILES_ variables retrieved via config
    {
        copy_items "$D_REPO"/files/universal/usr_local_bin /usr/local/bin \
            "$SPD_FILES_UNIVERSAL_ULB"
        copy_items "$D_REPO"/files/platform/ish/usr_local_bin /usr/local/bin \
            "$SPD_FILES_ISH_ULB"
        copy_items "$D_REPO"/files/platform/ish/usr_local_sbin /usr/local/sbin \
            "$SPD_FILES_ISH_ULSB"
        if is_ish_aok; then
            copy_items "$D_REPO"/files/platform/ish/AOK/usr_local_bin /usr/local/bin \
                "$SPD_FILES_ISH_AOK_ULB"
        else
            copy_items "$D_REPO"/files/platform/ish/not-AOK/usr_local_bin /usr/local/bin \
                "$SPD_FILES_ISH_NOT_AOK_ULB"
        fi
    }
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
#     # otherwise default to 1 in order to display progress for cmd_wrapper
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

# Can it run here?
is_linux || err_msg "This can't run on non-Linux platforms"
if ! is_ish_abstract; then
    err_msg "Not running on iSH related platform"
fi
check_for_abort 0 "$0"
case "$opt_task" in # Ensure options are valid
    force | force-install)
        lbl_1 "WARNING this task runs other tasks, they will all use force-install - be warned!" 1
        ;;
    install) ;;
    *) cmd_line_param_error "opt_task must be install / force-install" ;;
esac

early_start_runbg # this allows iSH to continue in the background during this deploy

#
# Expand any variables that need to be expanded
#
expand_yaml_config_var SPD_PKGS_MAN

cmd_create_output_file # Create it once to reduce overhead
if fs_is_alpine; then
    "$D_REPO"/tasks/fileSystem-Alpine.sh "$opt_task" || script_utils_cleanup 1
elif fs_is_devuan; then
    "$D_REPO"/tasks/fileSystem-Devuan.sh "$opt_task" || script_utils_cleanup 1
elif fs_is_debian; then
    "$D_REPO"/tasks/fileSystem-Debian.sh "$opt_task" || script_utils_cleanup 1
else
    "$D_REPO"/tasks/files-universal.sh "$opt_task" || script_utils_cleanup 1
fi
cmd_purge_output_file # Clear it to avoid having

#
# Services
#
"$D_REPO"/tasks/service-runbg.sh "$opt_task" || script_utils_cleanup 1
# command -v autossh >/dev/null && {
#     "$D_REPO"/tasks/service-autossh.sh "$opt_task" || script_utils_cleanup 1
# }

lbl_1 "Back to Module: $module_name" 1

#
# Expand any variables that need to be expanded
#
lbl_2 "Config variables used" 1

# To avoid unintended copying, all used file variables must be defined
fs_is_alpine && expand_show_spd_var SPD_FILES_ISH_ALPINE_ULB
fs_is_debian && {
    expand_show_spd_var SPD_FILES_ISH_DEBIAN_ULB
    expand_show_spd_var SPD_FILES_ISH_DEBIAN_ULSB
}
fs_is_devuan && {
    expand_show_spd_var SPD_FILES_ISH_DEVUAN_ULB
    expand_show_spd_var SPD_FILES_ISH_DEVUAN_ULSB

}
expand_show_spd_var SPD_FILES_UNIVERSAL_ULB
expand_show_spd_var SPD_FILES_ISH_ULB
expand_show_spd_var SPD_FILES_ISH_ULSB
if is_ish_aok; then
    expand_show_spd_var SPD_FILES_ISH_AOK_ULB
else
    expand_show_spd_var SPD_FILES_ISH_NOT_AOK_ULB
fi

task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
