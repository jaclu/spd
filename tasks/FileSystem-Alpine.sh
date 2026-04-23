#!/bin/sh

locale_gen() {
    # Generate required locales
    command -v locale-gen >/dev/null 2>&1 || {
        lbl_3 "locale-gen command not found, skipping locale generation"
        return 0
    }
    [ -z "$SPD_LOCALES" ] && {
        lbl_3 "No locales specified in SPD_LOCALES, skipping locale generation"
        return 0
    }
    lbl_3 "Generating required locales: $SPD_LOCALES"
    # shellcheck disable=SC2086 # expansion intended here
    cmd_filtered locale-gen $SPD_LOCALES
}

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare

    fs_is_alpine || {
        lbl_3 "$module_name: Dependency issue - This is not running on an Alpine FS"
        spd_dependency_issue=1
    }

    [ -n "$SPD_APK_REMOVE" ] && {
        lbl_3 "Will remove items in SPD_APK_REMOVE"
        display_list_content SPD_APK_REMOVE no_label
    }
    lbl_3 "Will install items in SPD_APK_INSTALL"
    display_list_content SPD_APK_INSTALL no_label

    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    yaml_true "$SPD_PKGS_MAN" && {
        lbl_4 "Will install man pages"
        SPD_APK_INSTALL="$SPD_APK_INSTALL docs apk-tools-doc"
    }
    # shellcheck disable=SC2154 # SPD_PKGS_DEVEL vars via config files
    if yaml_true "$SPD_PKGS_DEVEL"; then
        lbl_4 "Will install devel packages"
        display_list_content SPD_APK_DEVEL no_label
        SPD_APK_INSTALL="$SPD_APK_INSTALL $SPD_APK_DEVEL"
    else
        lbl_4 "Will remove devel packages"
        display_list_content SPD_APK_DEVEL no_label
        SPD_APK_REMOVE="$SPD_APK_REMOVE $SPD_APK_DEVEL"
    fi
    # shellcheck disable=SC2154 # SPD_PKGS_LINTING vars via config files
    if yaml_true "$SPD_PKGS_LINTING"; then
        lbl_4 "Will install linting packages"
        display_list_content SPD_APK_LINTING no_label
        SPD_APK_INSTALL="$SPD_APK_INSTALL $SPD_APK_LINTING"
    else
        lbl_4 "Will remove linting packages"
        display_list_content SPD_APK_LINTING no_label
        SPD_APK_REMOVE="$SPD_APK_REMOVE $SPD_APK_LINTING"
    fi
    return "$spd_dependency_issue"
}

task_execute() {
    check_for_abort 0 task_execute
    lbl_2 "$module_name: Executing task"

    lbl_3 "Updating environment"
    lbl_4 "First doing apk update"
    cmd_filtered apk update
    lbl_4 "Then apk upgrade"
    cmd_filtered apk upgrade

    [ -n "$SPD_APK_REMOVE" ] && {
        lbl_3 "Will remove Alpine packages in SPD_APK_REMOVE"
        # apk add automatically runs update, but apk del does not
        # shellcheck disable=SC2086 # expansion intended here
        cmd_filtered apk del $SPD_APK_REMOVE
    }

    [ -n "$SPD_APK_INSTALL" ] && {
        lbl_3 "Installing Alpine packages from SPD_APK_INSTALL"
        # shellcheck disable=SC2086 # expansion intended here
        cmd_filtered apk add $SPD_APK_INSTALL
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

module_name="FileSystem-Alpine"

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

fs_is_alpine || err_msg "$module_name: Rejected, not running on a Alpine FS"

# Ensure options are valid
case "$opt_task" in
    install | force | force-install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install / force-install"
        ;;
esac

#
# Ensure required options have been set, and expand any variables that need to be expanded
#
ensure_spd_var_defined SPD_APK_INSTALL
ensure_spd_var_defined SPD_APK_DEVEL
ensure_spd_var_defined SPD_APK_LINTING
expand_yaml_config_var SPD_APK_REMOVE # dont nag if it is empty

ensure_spd_var_defined SPD_PKGS_MAN
ensure_spd_var_defined SPD_PKGS_DEVEL
ensure_spd_var_defined SPD_PKGS_LINTING

is_musl_lib || ensure_spd_var_defined SPD_LOCALES

task_prepare
task_execute

# Exit in a controlled manner, cleaning up temp files remaining etc
script_utils_cleanup 0
