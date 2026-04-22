#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare

    fs_is_devuan || {
        lbl_3 "$module_name: Dependency issue - This is not running on an Devuan FS"
        spd_dependency_issue=1
    }

    [ -n "$SPD_DEVUAN_APT_PURGE" ] && {
        lbl_3 "Will remove items in SPD_DEVUAN_APT_PURGE"
        display_list_content SPD_DEVUAN_APT_PURGE no_label
    }
    lbl_3 "Will install items in SPD_DEVUAN_APT_INSTALL"
    display_list_content SPD_DEVUAN_APT_INSTALL no_label

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
    return "$spd_dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task"
    # cmd_create_output_file

    # needed to prevemt for example tzdata to pause the apt install with config
    # questions during a scripted deploy
    lbl_3 "Setting DEBIAN_FRONTEND=noninteractive"
    export DEBIAN_FRONTEND=noninteractive

    lbl_3 "Updating environment"
    lbl_4 "First doing apt-get update"
    cmd_filtered apt-get update
    lbl_4 "Then apt-get -y upgrade"
    cmd_filtered apt-get -y upgrade

    [ -n "$SPD_DEVUAN_APT_PURGE" ] && {
        lbl_3 "Will purge items in SPD_DEVUAN_APT_PURGE"
        # shellcheck disable=SC2086 # expansion intended here
        cmd_filtered apt-get -y purge $SPD_DEVUAN_APT_PURGE
    }

    [ -n "$SPD_DEVUAN_APT_INSTALL" ] && {
        lbl_3 "Installing Devuan packages from SPD_DEVUAN_APT_INSTALL"
        # shellcheck disable=SC2086 # expansion intended here
        cmd_filtered apt-get -y install $SPD_DEVUAN_APT_INSTALL
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

fs_is_devuan || err_msg "$module_name: Rejected, not running on a Devuan FS"

# Ensure options are valid
case "$opt_task" in
    install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install"
        ;;
esac

#
# Ensure required options have been set, and expand any variables that need to be expanded
#
ensure_spd_var_defined SPD_DEVUAN_APT_INSTALL
ensure_spd_var_defined SPD_DEVUAN_APT_DEVEL
ensure_spd_var_defined SPD_DEVUAN_APT_LINTING
expand_config_var SPD_DEVUAN_APT_PURGE # dont nag if it is empty

ensure_spd_var_defined SPD_PKGS_MAN
ensure_spd_var_defined SPD_PKGS_DEVEL
ensure_spd_var_defined SPD_PKGS_LINTING

task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
