#!/bin/sh

locale_gen() {
    # Generate required locales
    command -v locale-gen >/dev/null 2>&1 || {
        lbl_3 "locale-gen command not found, skipping locale generation" 1
        return 0
    }
    [ -z "$SPD_LOCALES" ] && {
        lbl_3 "No locales specified in SPD_LOCALES, skipping locale generation" 1
        return 0
    }
    lbl_3 "Generating required locales: $SPD_LOCALES" 1
    # shellcheck disable=SC2086 # expansion intended here
    cmd_wrapper_t locale-gen $SPD_LOCALES
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task" 1
    _te_installs="SPD_APK_INSTALL"
    _te_purges="SPD_APK_REMOVE"

    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    if is_yaml_true "$SPD_PKGS_MAN"; then
        lbl_3 "Will install man pages: $SPD_APK_MAN_PAGES" 1
        SPD_APK_INSTALL="$SPD_APK_INSTALL $SPD_APK_MAN_PAGES"
        _te_installs="$_te_installs SPD_APK_MAN_PAGES"
    elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
        lbl_3 "Will remove man pages: $SPD_APK_MAN_PAGES" 1
        SPD_APK_REMOVE="$SPD_APK_REMOVE $SPD_APK_MAN_PAGES"
        _te_purges="$_te_purges SPD_APK_MAN_PAGES"
    fi
    # shellcheck disable=SC2154 # SPD_PKGS_DEVEL vars via config files
    if is_yaml_true "$SPD_PKGS_DEVEL"; then
        lbl_3 "Will install devel packages: $SPD_APK_DEVEL" 1
        SPD_APK_INSTALL="$SPD_APK_INSTALL $SPD_APK_DEVEL"
        _te_installs="$_te_installs SPD_APK_DEVEL"
    elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
        lbl_3 "Will remove devel packages: $SPD_APK_DEVEL" 1
        SPD_APK_REMOVE="$SPD_APK_REMOVE $SPD_APK_DEVEL"
        _te_purges="$_te_purges SPD_APK_DEVEL"
    fi
    # shellcheck disable=SC2154 # SPD_PKGS_LINTING vars via config files
    if is_yaml_true "$SPD_PKGS_LINTING"; then
        lbl_3 "Will install linting packages: $SPD_APK_LINTING" 1
        SPD_APK_INSTALL="$SPD_APK_INSTALL $SPD_APK_LINTING"
        _te_installs="$_te_installs SPD_APK_LINTING"
    elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
        lbl_3 "Will remove linting packages: $SPD_APK_LINTING" 1
        SPD_APK_REMOVE="$SPD_APK_REMOVE $SPD_APK_LINTING"
        _te_purges="$_te_purges SPD_APK_LINTING"
    fi

    lbl_3 "Updating environment" 1
    lbl_4 "First doing apk update" 1
    cmd_wrapper_t apk update
    lbl_4 "Then apk upgrade" 1
    cmd_wrapper_t apk upgrade

    [ -n "$SPD_APK_REMOVE" ] && {
        lbl_3 "Will remove Alpine packages based on: $_te_purges" 1
        display_list_content SPD_APK_REMOVE no_label
        # apk add automatically runs update, but apk del does not
        # shellcheck disable=SC2086 # expansion intended here
        cmd_wrapper_t apk del $SPD_APK_REMOVE
    }

    [ -n "$SPD_APK_INSTALL" ] && {
        lbl_3 "Installing Alpine packages based on: $_te_installs" 1
        display_list_content SPD_APK_INSTALL no_label
        # shellcheck disable=SC2086 # expansion intended here
        cmd_wrapper_t apk add $SPD_APK_INSTALL
    }

    # musl doesn't need locale-gen, and it doesn't even have it, so skip this step
    # if musl is used
    is_musl_lib || locale_gen

    #  - name: Generate sshd host keys
    #   command: ssh-keygen -A
    # when:
    #  - use_sshd | default(false)
    #  - ift_alpine_generate_sshd_host_keys | default(false) | bool

    # shellcheck disable=SC2154 # SPD_FILES_ALPINE_ULB vars via config files
    copy_items "$D_REPO"/files/FS/Alpine/usr_local_bin /usr/local/bin \
        "$SPD_FILES_ALPINE_ULB"
}

#=====================================================================
#
#   Main
#
#=====================================================================

# module_name="fileSystem-Alpine"

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

# Can it run here?
fs_is_alpine || err_msg "Rejected, not running on a Alpine FS"
check_for_abort 0 "$0"
case "$opt_task" in # Ensure options are valid
    install | force | force-install) ;;
    *) cmd_line_param_error "opt_task must be install / force-install" ;;
esac

#
# Expand any variables that need to be expanded
#
lbl_2 "Config variables used" 1

expand_show_spd_var SPD_APK_INSTALL
expand_show_spd_var SPD_APK_REMOVE

expand_show_spd_var SPD_ACTIVE_PURGE_DISABLED_PACKAGES
expand_show_spd_var SPD_PKGS_MAN
expand_show_spd_var SPD_PKGS_DEVEL
expand_show_spd_var SPD_PKGS_LINTING
expand_show_spd_var SPD_FILES_ALPINE_ULB

expand_yaml_config_var SPD_APK_DEVEL
expand_yaml_config_var SPD_APK_LINTING
expand_yaml_config_var SPD_APK_MAN_PAGES

is_musl_lib || expand_yaml_config_var SPD_LOCALES

task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
