#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    lbl_2 "$module_name: Preparing task" 1
    check_for_abort 1 task_prepare

    fs_is_devuan || {
        lbl_3 "$module_name: Dependency issue - This is not running on an Devuan FS"
        spd_dependency_issue=1
    }

    [ -n "$SPD_DEVUAN_APT_PURGE" ] && {
        lbl_3 "Will remove items in SPD_DEVUAN_APT_PURGE" 1
        display_list_content SPD_DEVUAN_APT_PURGE no_label
    }
    lbl_3 "Will install items in SPD_DEVUAN_APT_INSTALL" 1
    display_list_content SPD_DEVUAN_APT_INSTALL no_label

    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    if is_yaml_true "$SPD_PKGS_MAN"; then
        lbl_4 "Will install man pages" 1
        SPD_DEVUAN_APT_INSTALL="$SPD_DEVUAN_APT_INSTALL man-db"
    elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
        lbl_4 "Will purge man pages" 1
        SPD_DEVUAN_APT_PURGE="$SPD_DEVUAN_APT_PURGE man-db"
    fi
    [ -n "$SPD_DEVUAN_APT_DEVEL" ] && {
        # shellcheck disable=SC2154 # SPD_PKGS_DEVEL vars via config files
        if is_yaml_true "$SPD_PKGS_DEVEL"; then
            lbl_3 "Will install devel packages" 1
            SPD_DEVUAN_APT_INSTALL="$SPD_DEVUAN_APT_INSTALL $SPD_DEVUAN_APT_DEVEL"
            display_list_content SPD_DEVUAN_APT_DEVEL no_label
            is_debug_lvl 1 && echo
        elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
            lbl_3 "Will purge devel packages" 1
            SPD_DEVUAN_APT_PURGE="$SPD_DEVUAN_APT_PURGE $SPD_DEVUAN_APT_DEVEL"
            display_list_content SPD_DEVUAN_APT_DEVEL no_label
            is_debug_lvl 1 && echo
        fi
    }
    # shellcheck disable=SC2154 # SPD_PKGS_LINTING vars via config files
    [ -n "$SPD_DEVUAN_APT_LINTING" ] && {
        if is_yaml_true "$SPD_PKGS_LINTING"; then
            lbl_3 "Will install linting packages" 1
            SPD_DEVUAN_APT_INSTALL="$SPD_DEVUAN_APT_INSTALL $SPD_DEVUAN_APT_LINTING"
            display_list_content SPD_DEVUAN_APT_DEVEL no_label
            is_debug_lvl 1 && echo
        elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
            lbl_3 "Will purge linting packages" 1
            SPD_DEVUAN_APT_PURGE="$SPD_DEVUAN_APT_PURGE $SPD_DEVUAN_APT_LINTING"
            display_list_content SPD_DEVUAN_APT_DEVEL no_label
            is_debug_lvl 1 && echo
        fi
    }
    return "$spd_dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task" 1
    # cmd_create_output_file

    # needed to prevemt for example tzdata to pause the apt install with config
    # questions during a scripted deploy
    lbl_3 "Setting DEBIAN_FRONTEND=noninteractive" 1
    export DEBIAN_FRONTEND=noninteractive

    lbl_3 "Updating environment" 1
    lbl_4 "First doing apt-get update" 1
    cmd_wrapper_t apt-get update
    lbl_4 "Then apt-get -y upgrade" 1
    cmd_wrapper_t apt-get -y upgrade

    [ -n "$SPD_DEVUAN_APT_PURGE" ] && {
        lbl_3 "Will purge items in SPD_DEVUAN_APT_PURGE" 1
        # shellcheck disable=SC2086 # expansion intended here
        cmd_wrapper_t apt-get -y purge $SPD_DEVUAN_APT_PURGE
    }

    [ -n "$SPD_DEVUAN_APT_INSTALL" ] && {
        lbl_3 "Installing Devuan packages from SPD_DEVUAN_APT_INSTALL" 1
        # shellcheck disable=SC2086 # expansion intended here
        cmd_wrapper_t apt-get -y install $SPD_DEVUAN_APT_INSTALL
    }
    # cmd_purge_output_file
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="FileSystem-Devuan"

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

fs_is_devuan || err_msg "Rejected, not running on a Devuan FS"

# Ensure options are valid
case "$opt_task" in
    install | force | force-install) ;;
    *)
        cmd_line_param_error "opt_task must be install / force-install"
        ;;
esac

#
# Expand any variables that need to be expanded
#
lbl_2 "Config variables used" 2

expand_show_spd_var SPD_ACTIVE_PURGE_DISABLED_PACKAGES
expand_show_spd_var SPD_PKGS_MAN
expand_show_spd_var SPD_PKGS_DEVEL
expand_show_spd_var SPD_PKGS_LINTING

expand_show_spd_var SPD_DEVUAN_APT_INSTALL
expand_show_spd_var SPD_DEVUAN_APT_PURGE
expand_show_spd_var SPD_DEVUAN_APT_DEVEL
expand_show_spd_var SPD_DEVUAN_APT_LINTING

task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
