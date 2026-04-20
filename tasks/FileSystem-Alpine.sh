#!/bin/sh

task_prepare() {
    # setting up any environmental dependencies in order for task_execute to be executed,
    # such as installing dependencies if need be etc
    # is_linux || err_msg "Will not run apt on non-Linux"
    dependency_issue=0

    lbl_2 "$module_name: Preparing task"
    check_for_abort 1 task_prepare

    fs_is_alpine || {
        lbl_3 "$module_name: Dependency issue - This is not running on an Alpine FS"
        dependency_issue=1
    }

    [ -n "$SPD_APK_REMOVE" ] && {
        lbl_3 "Will remove items in SPD_APK_REMOVE"
        display_list_content SPD_APK_REMOVE no_label
    }
    lbl_3 "Installing selected Alpine packages"
    display_list_content SPD_APK_INSTALL no_label

    # shellcheck disable=SC2154 # SPD_PKGS_MAN vars via config files
    yaml_true "$SPD_PKGS_MAN" && {
        lbl_4 "Will install man pages"
        SPD_APK_INSTALL="$SPD_APK_INSTALL docs"
    }
    # shellcheck disable=SC2154 # SPD_PKGS_DEVEL vars via config files
    yaml_true "$SPD_PKGS_DEVEL" && {
        lbl_4 "Will install devel packages"
        display_list_content SPD_APK_DEVEL no_label
        SPD_APK_INSTALL="$SPD_APK_INSTALL $SPD_APK_DEVEL"
    }
    # shellcheck disable=SC2154 # SPD_PKGS_LINTING vars via config files
    yaml_true "$SPD_PKGS_LINTING" && {
        lbl_4 "Will install linting packages"
        display_list_content SPD_APK_LINTING no_label
        SPD_APK_INSTALL="$SPD_APK_INSTALL $SPD_APK_LINTING"
    }
    return "$dependency_issue"
}

task_execute() {
    lbl_2 "$module_name: Executing task"
    check_for_abort 0 task_execute

    # current_dbg_lvl=2
    if [ "$current_dbg_lvl" -gt 0 ]; then
        f_tmp=/dev/stdout
    else
        tmp_file_create
    fi

    [ -n "$SPD_APK_REMOVE" ] && {
        lbl_3 "Will remove Alpine packages in SPD_APK_REMOVE"
        # shellcheck disable=SC2086 # SPD_APK_REMOVE should be expanded
        apk del $SPD_APK_REMOVE >"$f_tmp" 2>&1 || {
            [ "$f_tmp" != /dev/stdout ] && {
                cat "$f_tmp"
                safe_remove "$f_tmp"
            }
            err_msg "Failed to run apk del SPD_APK_REMOVE"
        }
    }
    [ -n "$SPD_APK_INSTALL" ] && {
        lbl_3 "Installing Alpine packages from SPD_APK_INSTALL"
        # shellcheck disable=SC2086 # SPD_APK_INSTALL should be expanded
        apk add $SPD_APK_INSTALL >"$f_tmp" 2>&1 || {
            [ "$f_tmp" != /dev/stdout ] && {
                cat "$f_tmp"
                safe_remove "$f_tmp"
            }
            err_msg "Failed to run apk add SPD_APK_INSTALL"
        }
    }
    #  - name: Generate sshd host keys
    #   command: ssh-keygen -A
    # when:
    #  - use_sshd | default(false)
    #  - ift_alpine_generate_sshd_host_keys | default(false) | bool

    tmp_file_remove "$f_tmp"
}

#=====================================================================
#
#   Main
#
#=====================================================================

module_name="FileSystem-Alpine"

[ -n "$D_REPO" ] || {
    std_alone="$module_name"
    #  Run this in stand-alone mode
    D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
    # shellcheck source=tools/prepare-env.sh
    . "$D_REPO"/tools/prepare-env.sh
}

get_config "$D_REPO"/configs/file_systems/alpine.yml

#
# Ensure required options have been set, and expand any variables that need to be expanded
#
ensure_spd_var_defined SPD_APK_INSTALL
ensure_spd_var_defined SPD_APK_DEVEL
ensure_spd_var_defined SPD_APK_LINTING
expand_config_var SPD_APK_REMOVE # dont nag if it is empty

ensure_spd_var_defined SPD_PKGS_MAN
ensure_spd_var_defined SPD_PKGS_DEVEL
ensure_spd_var_defined SPD_PKGS_LINTING

# Ensure options are valid
case "$opt_task" in
    install) ;;
    *)
        cmd_line_param_error "$module_name: opt_task must be install"
        ;;
esac

[ "$std_alone" = "$module_name" ] && {
    # In stand-alone mode, we want to run the entire task
    task_prepare
    task_execute
}
