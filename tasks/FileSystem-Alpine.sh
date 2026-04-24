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

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    lbl_2 "$module_name: Preparing task" 1
    check_for_abort 1 task_prepare

    fs_is_alpine || {
        lbl_3 "$module_name: Dependency issue - This is not running on an Alpine FS"
        spd_dependency_issue=1
    }

    [ -n "$SPD_APK_REMOVE" ] && {
        lbl_3 "Will remove items in SPD_APK_REMOVE" 1
        display_list_content SPD_APK_REMOVE no_label
    }
    lbl_3 "Will install items in SPD_APK_INSTALL" 1
    display_list_content SPD_APK_INSTALL no_label
    is_debug_lvl 1 && echo

    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    if is_yaml_true "$SPD_PKGS_MAN"; then
        lbl_3 "Will install man pages" 1
        SPD_APK_INSTALL="$SPD_APK_INSTALL docs apk-tools-doc"
    elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
        lbl_3 "Will remove man pages" 1
        SPD_APK_REMOVE="$SPD_APK_REMOVE docs apk-tools-doc"
    fi
    # shellcheck disable=SC2154 # SPD_PKGS_DEVEL vars via config files
    [ -n "$SPD_APK_DEVEL" ] && {
        if is_yaml_true "$SPD_PKGS_DEVEL"; then
            lbl_3 "Will install devel packages" 1
            SPD_APK_INSTALL="$SPD_APK_INSTALL $SPD_APK_DEVEL"
            display_list_content SPD_APK_DEVEL no_label
            is_debug_lvl 1 && echo
        elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
            lbl_3 "Will remove devel packages" 1
            SPD_APK_REMOVE="$SPD_APK_REMOVE $SPD_APK_DEVEL"
            display_list_content SPD_APK_DEVEL no_label
            is_debug_lvl 1 && echo
        fi
    }
    [ -n "$SPD_APK_DEVEL" ] && {
        # shellcheck disable=SC2154 # SPD_PKGS_LINTING vars via config files
        if is_yaml_true "$SPD_PKGS_LINTING"; then
            lbl_3 "Will install linting packages" 1
            SPD_APK_INSTALL="$SPD_APK_INSTALL $SPD_APK_LINTING"
            display_list_content SPD_APK_LINTING no_label
            is_debug_lvl 1 && echo
        elif is_yaml_true "$SPD_ACTIVE_PURGE_DISABLED_PACKAGES"; then
            lbl_3 "Will remove linting packages" 1
            SPD_APK_REMOVE="$SPD_APK_REMOVE $SPD_APK_LINTING"
            display_list_content SPD_APK_LINTING no_label
            is_debug_lvl 1 && echo
        fi
    }
    return "$spd_dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task" 1

    lbl_3 "Updating environment" 1
    lbl_4 "First doing apk update" 1
    cmd_wrapper_t apk update
    lbl_4 "Then apk upgrade" 1
    cmd_wrapper_t apk upgrade

    [ -n "$SPD_APK_REMOVE" ] && {
        lbl_3 "Will remove Alpine packages in SPD_APK_REMOVE" 1
        # apk add automatically runs update, but apk del does not
        # shellcheck disable=SC2086 # expansion intended here
        cmd_wrapper_t apk del $SPD_APK_REMOVE
    }

    [ -n "$SPD_APK_INSTALL" ] && {
        lbl_3 "Installing Alpine packages from SPD_APK_INSTALL" 1
        # shellcheck disable=SC2086 # expansion intended here
        cmd_wrapper_t apk add $SPD_APK_INSTALL
    }

    # musl doesn't need locale-gen, and it doesn't even have it, so skip this step if musl is used
    is_musl_lib || locale_gen

    #  - name: Generate sshd host keys
    #   command: ssh-keygen -A
    # when:
    #  - use_sshd | default(false)
    #  - ift_alpine_generate_sshd_host_keys | default(false) | bool
}

#=====================================================================
#
#   Main
#
#=====================================================================

# module_name="FileSystem-Alpine"

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

fs_is_alpine || err_msg "Rejected, not running on a Alpine FS"

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

expand_show_spd_var SPD_APK_INSTALL
expand_show_spd_var SPD_APK_REMOVE
expand_show_spd_var SPD_APK_DEVEL
expand_show_spd_var SPD_APK_LINTING

is_musl_lib || expand_yaml_config_var SPD_LOCALES

task_prepare

# err_msg "debug abort"
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
