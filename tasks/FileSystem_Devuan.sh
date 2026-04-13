#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare

    fs_is_devuan || {
        lbl_3 "$module_name: Dependency issue - This is not running on an Devuan FS"
        dependency_issue=1
    }

    # Read related config files, before variables are expanded
    read_config_file "$D_REPO"/configs/files_systems/devuan.yml
    read_config_file "$D_REPO"/configs/task_overrides/filesystem_devuan.yml
    read_config_file "$D_REPO"/configs/global_overrides.yml # local user overrides

    ensure_spd_var_defined SPD_DEVUAN_APT_INSTALL
    ensure_spd_var_defined SPD_DEVUAN_APT_DEVEL
    ensure_spd_var_defined SPD_DEVUAN_APT_LINTING
    expand_config_var SPD_DEVUAN_APT_PURGE # dont nag if it is empty

    ensure_spd_var_defined SPD_PKGS_MAN
    ensure_spd_var_defined SPD_PKGS_DEVEL
    ensure_spd_var_defined SPD_PKGS_LINTING

    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    yaml_true "$SPD_PKGS_MAN" && {
        lbl_4 "Will install man pages"
        SPD_DEVUAN_APT_INSTALL="$SPD_DEVUAN_APT_INSTALL man-db"
    }
    # shellcheck disable=SC2154 # SPD_PKGS_DEVEL vars via config files
    yaml_true "$SPD_PKGS_DEVEL" && [ -n "$SPD_DEVUAN_APT_DEVEL" ] && {
        lbl_4 "Will install devel packages"
        display_list_content SPD_DEVUAN_APT_DEVEL no_label
        SPD_DEVUAN_APT_INSTALL="$SPD_DEVUAN_APT_INSTALL $SPD_DEVUAN_APT_DEVEL"
    }
    # shellcheck disable=SC2154 # SPD_PKGS_LINTING vars via config files
    yaml_true "$SPD_PKGS_LINTING" && [ -n "$SPD_DEVUAN_APT_LINTING" ] && {
        lbl_4 "Will install linting packages"
        display_list_content SPD_DEVUAN_APT_LINTING no_label
        SPD_DEVUAN_APT_INSTALL="$SPD_DEVUAN_APT_INSTALL $SPD_DEVUAN_APT_LINTING"
    }
    return "$dependency_issue"
}

task_execute() {
    lbl_2 "$module_name: Executing task"
    check_for_abort 0 task_execute

    # current_dbg_lvl=2
    [ -n "$SPD_DEVUAN_APT_PURGE" ] && {
        lbl_3 "Will remove items in SPD_DEVUAN_APT_PURGE"
        display_list_content SPD_DEVUAN_APT_PURGE no_label
        # shellcheck disable=SC2086 # SPD_DEVUAN_APT_PURGE should be expanded
        apt-get purge -y $SPD_DEVUAN_APT_PURGE || {
            err_msg "Failed to run apt-get purge SPD_DEVUAN_APT_PURGE"
        }
    }
    lbl_3 "Installing seleted Devuan packages"
    display_list_content SPD_DEVUAN_APT_INSTALL no_label
    # shellcheck disable=SC2086 # SPD_DEVUAN_APT_INSTALL should be expanded
    apt-get install -y $SPD_DEVUAN_APT_INSTALL || {
        err_msg "Failed to run apt-get install SPD_DEVUAN_APT_INSTALL"
    }
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="FileSystem_Devuan"

[ -n "$D_REPO" ] || {
    #  Run this in stand-alone mode
    D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck source=tools/prepare_env.sh
    . "$D_REPO"/tools/prepare_env.sh
}

# Ensure opions are valid
# shellcheck disable=SC2154 # opt_task defined in prepare_env.sh
case "$opt_task" in
    install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install"
        ;;
esac

task_prepare && task_execute
