#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    lbl_2 "$module_name: Preparing task" 1
    check_for_abort 1 task_prepare

    fs_is_debian || {
        lbl_3 "$module_name: Dependency issue - This is not running on an Debian FS" 1
        spd_dependency_issue=1
    }

    [ -n "$SPD_DEBIAN_APT_PURGE" ] && {
        lbl_3 "Will purge items in SPD_DEBIAN_APT_PURGE" 1
        display_list_content SPD_DEBIAN_APT_PURGE no_label
        is_debug_lvl 1 && echo
    }
    lbl_3 "Will install items in SPD_DEBIAN_APT_INSTALL" 1
    display_list_content SPD_DEBIAN_APT_INSTALL no_label
    is_debug_lvl 1 && echo

    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    if yaml_true "$SPD_PKGS_MAN"; then
        lbl_4 "Will install man pages" 1
        SPD_DEBIAN_APT_INSTALL="$SPD_DEBIAN_APT_INSTALL man-db"
    elif yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
        lbl_4 "Will purge man pages" 1
        SPD_DEBIAN_APT_PURGE="$SPD_DEBIAN_APT_PURGE man-db"
    fi

    [ -n "$SPD_DEBIAN_APT_DEVEL" ] && {
        # shellcheck disable=SC2154 # SPD_ vars via config files
        if yaml_true "$SPD_PKGS_DEVEL"; then
            lbl_3 "Will install devel packages" 1
            display_list_content SPD_DEBIAN_APT_DEVEL no_label
            SPD_DEBIAN_APT_INSTALL="$SPD_DEBIAN_APT_INSTALL $SPD_DEBIAN_APT_DEVEL"
            is_debug_lvl 1 && echo
        elif yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
            lbl_3 "Will purge devel packages" 1
            display_list_content SPD_DEBIAN_APT_DEVEL no_label
            SPD_DEBIAN_APT_PURGE="$SPD_DEBIAN_APT_PURGE $SPD_DEBIAN_APT_DEVEL"
            is_debug_lvl 1 && echo
        fi
    }
    [ -n "$SPD_DEBIAN_APT_LINTING" ] && {
        # shellcheck disable=SC2154 # SPD_ vars via config files
        if yaml_true "$SPD_PKGS_LINTING"; then
            lbl_3 "Will install linting packages" 1
            display_list_content SPD_DEBIAN_APT_LINTING no_label
            SPD_DEBIAN_APT_INSTALL="$SPD_DEBIAN_APT_INSTALL $SPD_DEBIAN_APT_LINTING"
            is_debug_lvl 1 && echo
        elif yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
            lbl_3 "Will purge linting packages" 1
            display_list_content SPD_DEBIAN_APT_LINTING no_label
            SPD_DEBIAN_APT_PURGE="$SPD_DEBIAN_APT_PURGE $SPD_DEBIAN_APT_LINTING"
            is_debug_lvl 1 && echo
        fi
    }
    return "$spd_dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task" 1
    # cmd_create_output_file

    fs_is_ubuntu && err_msg "Rejected, not allowed to run on Ubuntu"

    # needed to prevemt for example tzdata to pause the apt install with config
    # questions during a scripted deploy
    lbl_3 "Setting DEBIAN_FRONTEND=noninteractive" 1
    export DEBIAN_FRONTEND=noninteractive

    lbl_3 "Updating environment" 1
    lbl_4 "First doing apt-get update" 1
    cmd_wrapper_t apt-get update
    lbl_4 "Then apt-get -y upgrade" 1
    cmd_wrapper_t apt-get -y upgrade

    [ -n "$SPD_DEBIAN_APT_PURGE" ] && {
        lbl_3 "Will purge Debian packages in SPD_DEBIAN_APT_PURGE" 1
        # shellcheck disable=SC2086 # expansion intended here
        cmd_wrapper_t apt-get purge -y $SPD_DEBIAN_APT_PURGE
    }

    [ -n "$SPD_DEBIAN_APT_INSTALL" ] && {
        lbl_3 "Installing Debian packages from SPD_DEBIAN_APT_INSTALL" 1
        # shellcheck disable=SC2086 # expansion intended here
        cmd_wrapper_t apt-get install -y $SPD_DEBIAN_APT_INSTALL
    }
    # cmd_purge_output_file
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="FileSystem-Debian"

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

fs_is_debian || err_msg "Rejected, not running on a Debian FS"

# Ensure options are valid
case "$opt_task" in
    install) ;;
    *)
        cmd_line_param_error "opt_task must be install"
        ;;
esac

#
# Ensure required options have been set, and expand any variables that need to be expanded
#
expand_yaml_config_var SPD_ACTIVE_PURGE_DISABLED_PACKAGES # dont nag if it is empty

ensure_spd_var_defined SPD_DEBIAN_APT_INSTALL
ensure_spd_var_defined SPD_DEBIAN_APT_DEVEL
ensure_spd_var_defined SPD_DEBIAN_APT_LINTING
expand_yaml_config_var SPD_DEBIAN_APT_PURGE # dont nag if it is empty

ensure_spd_var_defined SPD_PKGS_MAN
ensure_spd_var_defined SPD_PKGS_DEVEL
ensure_spd_var_defined SPD_PKGS_LINTING

task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
