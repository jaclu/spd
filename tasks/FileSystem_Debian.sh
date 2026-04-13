#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare

    fs_is_debian || {
        lbl_3 "$module_name: Dependency issue - This is not running on an Debian FS"
        dependency_issue=1
    }

    [ -n "$SPD_DEBIAN_APT_PURGE" ] && {
        lbl_3 "Will remove items in SPD_DEBIAN_APT_PURGE"
        display_list_content SPD_DEBIAN_APT_PURGE no_label
    }
    lbl_3 "Installing seleted Devuan packages"
    display_list_content SPD_DEBIAN_APT_INSTALL no_label

    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    yaml_true "$SPD_PKGS_MAN" && {
        lbl_4 "Will install man pages"
        SPD_DEBIAN_APT_INSTALL="$SPD_DEBIAN_APT_INSTALL man-db"
    }
    # shellcheck disable=SC2154 # SPD_PKGS_DEVEL vars via config files
    yaml_true "$SPD_PKGS_DEVEL" && [ -n "$SPD_DEBIAN_APT_DEVEL" ] && {
        lbl_4 "Will install devel packages"
        display_list_content SPD_DEBIAN_APT_DEVEL no_label
        SPD_DEBIAN_APT_INSTALL="$SPD_DEBIAN_APT_INSTALL $SPD_DEBIAN_APT_DEVEL"
    }
    # shellcheck disable=SC2154 # SPD_PKGS_LINTING vars via config files
    yaml_true "$SPD_PKGS_LINTING" && [ -n "$SPD_DEBIAN_APT_LINTING" ] && {
        lbl_4 "Will install linting packages"
        display_list_content SPD_DEBIAN_APT_LINTING no_label
        SPD_DEBIAN_APT_INSTALL="$SPD_DEBIAN_APT_INSTALL $SPD_DEBIAN_APT_LINTING"
    }
    return "$dependency_issue"
}

task_execute() {
    lbl_2 "$module_name: Executing task"
    check_for_abort 0 task_execute

    fs_is_ubuntu && err_msg "$module_name: Rejected, not allowed to run on Ubuntu"

    lbl_3 "Updating apt cache"
    apt-get update || {
        err_msg "Failed to run apt-get update"
    }

    # current_dbg_lvl=2
    [ -n "$SPD_DEBIAN_APT_PURGE" ] && {
        lbl_3 "Will remove items in SPD_DEBIAN_APT_PURGE"
        # shellcheck disable=SC2086 # SPD_DEBIAN_APT_PURGE should be expanded
        apt-get purge -y $SPD_DEBIAN_APT_PURGE || {
            err_msg "Failed to run apt-get purge SPD_DEBIAN_APT_PURGE"
        }
    }
    lbl_3 "Installing seleted Devuan packages"
    # shellcheck disable=SC2086 # SPD_DEBIAN_APT_INSTALL should be expanded
    apt-get install -y $SPD_DEBIAN_APT_INSTALL || {
        err_msg "Failed to run apt-get install SPD_DEBIAN_APT_INSTALL"
    }
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="FileSystem_Debian"

[ -n "$D_REPO" ] || {
    std_alone="$module_name"
    #  Run this in stand-alone mode
    D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck source=tools/prepare_env.sh
    . "$D_REPO"/tools/prepare_env.sh
}

# Read related config files, before variables are expanded
read_config_file "$D_REPO"/configs/file_systems/debian.yml
read_config_file "$D_REPO"/configs/task_overrides/filesystem_debian.yml
read_config_file "$D_REPO"/configs/global_overrides.yml # local user overrides

ensure_spd_var_defined SPD_DEBIAN_APT_INSTALL
ensure_spd_var_defined SPD_DEBIAN_APT_DEVEL
ensure_spd_var_defined SPD_DEBIAN_APT_LINTING
expand_config_var SPD_DEBIAN_APT_PURGE # dont nag if it is empty

ensure_spd_var_defined SPD_PKGS_MAN
ensure_spd_var_defined SPD_PKGS_DEVEL
ensure_spd_var_defined SPD_PKGS_LINTING

# Ensure opions are valid
# shellcheck disable=SC2154 # opt_task defined in prepare_env.sh
case "$opt_task" in
    install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install"
        ;;
esac

[ "$std_alone" = "$module_name" ] && {
    task_prepare
    task_execute
}
