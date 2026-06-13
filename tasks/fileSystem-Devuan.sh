#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    [ -n "$SPD_APT_PURGE" ] && {
        lbl_3 "Will remove items in SPD_APT_PURGE" 1
        display_list_content SPD_APT_PURGE no_label
    }
    lbl_3 "Will install items in SPD_APT_INSTALL" 1
    display_list_content SPD_APT_INSTALL no_label

    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    if is_yaml_true "$SPD_PKGS_MAN"; then
        lbl_4 "Will install man pages" 1
        SPD_APT_INSTALL="$SPD_APT_INSTALL man-db"
    elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
        lbl_4 "Will purge man pages" 1
        SPD_APT_PURGE="$SPD_APT_PURGE man-db"
    fi
    [ -n "$SPD_APT_DEVEL" ] && {
        # shellcheck disable=SC2154 # SPD_PKGS_DEVEL vars via config files
        if is_yaml_true "$SPD_PKGS_DEVEL"; then
            lbl_3 "Will install devel packages" 1
            SPD_APT_INSTALL="$SPD_APT_INSTALL $SPD_APT_DEVEL"
            display_list_content SPD_APT_DEVEL no_label
            is_debug_lvl 1 && echo
        elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
            lbl_3 "Will purge devel packages" 1
            SPD_APT_PURGE="$SPD_APT_PURGE $SPD_APT_DEVEL"
            display_list_content SPD_APT_DEVEL no_label
            is_debug_lvl 1 && echo
        fi
    }
    # shellcheck disable=SC2154 # SPD_PKGS_LINTING vars via config files
    [ -n "$SPD_APT_LINTING" ] && {
        if is_yaml_true "$SPD_PKGS_LINTING"; then
            lbl_3 "Will install linting packages" 1
            SPD_APT_INSTALL="$SPD_APT_INSTALL $SPD_APT_LINTING"
            display_list_content SPD_APT_DEVEL no_label
            is_debug_lvl 1 && echo
        elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
            lbl_3 "Will purge linting packages" 1
            SPD_APT_PURGE="$SPD_APT_PURGE $SPD_APT_LINTING"
            display_list_content SPD_APT_DEVEL no_label
            is_debug_lvl 1 && echo
        fi
    }
    return "$spd_dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task" 1
    _te_installs="SPD_APT_INSTALL"
    _te_purges="SPD_APT_PURGE"

    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    if is_yaml_true "$SPD_PKGS_MAN"; then
        lbl_3 "Will install man pages: $SPD_APT_MAN_PAGES" 1
        SPD_APT_INSTALL="$SPD_APT_INSTALL $SPD_APT_MAN_PAGES"
        _te_installs="$_te_installs SPD_APT_MAN_PAGES"
    elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
        lbl_3 "Will remove man pages: $SPD_APT_MAN_PAGES" 1
        SPD_APT_PURGE="$SPD_APT_PURGE $SPD_APT_MAN_PAGES"
        _te_purges="$_te_purges SPD_APT_MAN_PAGES"
    fi
    # shellcheck disable=SC2154 # SPD_PKGS_DEVEL vars via config files
    if is_yaml_true "$SPD_PKGS_DEVEL"; then
        lbl_3 "Will install devel packages: $SPD_APT_DEVEL" 1
        SPD_APT_INSTALL="$SPD_APT_INSTALL $SPD_APT_DEVEL"
        _te_installs="$_te_installs SPD_APT_DEVEL"
    elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
        lbl_3 "Will remove devel packages: $SPD_APT_DEVEL" 1
        SPD_APT_PURGE="$SPD_APT_PURGE $SPD_APT_DEVEL"
        _te_purges="$_te_purges SPD_APT_DEVEL"
    fi
    # shellcheck disable=SC2154 # SPD_PKGS_DEVEL vars via config files
    if is_yaml_true "$SPD_PKGS_LINTING"; then
        lbl_3 "Will install linting packages: $SPD_APT_LINTING" 1
        SPD_APT_INSTALL="$SPD_APT_INSTALL $SPD_APT_LINTING"
        _te_installs="$_te_installs SPD_APT_LINTING"
    elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
        lbl_3 "Will remove linting packages: $SPD_APT_LINTING" 1
        SPD_APT_PURGE="$SPD_APT_PURGE $SPD_APT_LINTING"
        _te_purges="$_te_purges SPD_APT_LINTING"
    fi

    # needed to prevemt for example tzdata to pause the apt install with config
    # questions during a scripted deploy
    lbl_3 "Setting DEBIAN_FRONTEND=noninteractive" 1
    export DEBIAN_FRONTEND=noninteractive

    lbl_3 "Updating environment" 1
    lbl_4 "First doing apt-get update" 1
    cmd_wrapper_t apt-get update
    lbl_4 "Then apt-get -y upgrade" 1
    cmd_wrapper_t apt-get -y upgrade

    [ -n "$SPD_APT_PURGE" ] && {
        lbl_3 "Will purge Debian packages based on: $_te_purges" 1
        display_list_content SPD_APT_PURGE no_label
        # shellcheck disable=SC2086 # expansion intended here
        cmd_wrapper_t apt-get purge -y $SPD_APT_PURGE
    }

    [ -n "$SPD_APT_INSTALL" ] && {
        lbl_3 "Installing Debian packages based on: $_te_installs" 1
        display_list_content SPD_APT_INSTALL no_label
        # shellcheck disable=SC2086 # expansion intended here
        cmd_wrapper_t apt-get install -y $SPD_APT_INSTALL
    }

    # Since Devuan can be seen as equiv of Devuan in this context, the same source
    # folder is used, but file selection can be modified
    # shellcheck disable=SC2154 # SPD_FILES_DEVUAN_ULB vars via config files
    copy_items "$D_REPO"/files/FS/Debian/usr_local_bin /usr/local/bin \
        "$SPD_FILES_DEVUAN_ULB"
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="fileSystem-Devuan"

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

# Can it run here?
fs_is_devuan || err_msg "Rejected, not running on a Devuan FS"
check_for_abort 0 "$0"
case "$opt_task" in # Ensure options are valid
    install | force | force-install) ;;
    *) err_msg "Valid options: install / force-install" ;;
esac

#
# Expand any variables that need to be expanded
#
lbl_2 "Config variables used" 2

expand_show_spd_var SPD_APT_INSTALL
expand_show_spd_var SPD_APT_PURGE

expand_show_spd_var SPD_ACTIVE_PURGE_DISABLED_PACKAGES
expand_show_spd_var SPD_PKGS_MAN
expand_show_spd_var SPD_PKGS_DEVEL
expand_show_spd_var SPD_PKGS_LINTING
ensure_spd_var_defined SPD_FILES_DEVUAN_ULB

expand_yaml_config_var SPD_APT_DEVEL
expand_yaml_config_var SPD_APT_LINTING
expand_yaml_config_var SPD_APT_MAN_PAGES

task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
