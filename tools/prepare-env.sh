#!/bin/sh

relative_path() { # Needed here due to: prepare_menu() - set_menu_env_variables()
    # remove D_TM_BASE_PATH prefix
    # log_it "relative_path($1) - removing prefix: $D_TM_BASE_PATH"
    printf '%s\n' "${1#"$D_REPO"/}"
}

populate_config() {
    SPD_DEPENDENCY_ISSUE=0 # set default to no issue
    # If config/ is empty populate it with config_templates as a default
    _pc_d_conf="$D_REPO"/configs
    [ -n "$(ls -A "$_pc_d_conf" 2>/dev/null)" ] || {
        _pc_d_templates="$D_REPO"/config_templates
        lbl_1 "No configs found, populating $_pc_d_conf from templates"
        mkdir -p "$_pc_d_conf"
        cp -a "$_pc_d_templates"/* "$_pc_d_conf" || {
            error_msg "Failed to copy templates"
        }
    }
}

ensure_spd_var_defined() {
    # Expands variable, then displays it if current_dbg_lvl>=1
    # otherwise print dependency warning and set SPD_DEPENDENCY_ISSUE=1
    # to inicate dependency issue for caller
    _esvd_variable="$1"

    expand_config_var "$_esvd_variable"
    eval "_esvd_value=\"\${$_esvd_variable}\""
    if [ -n "$_esvd_value" ]; then
        dbg_msg "$_esvd_variable: $_esvd_value" 1
    else
        lbl_2 "${module_name:-}: Dependency issue - no content/undefined: $_esvd_variable"
        # shellcheck disable=SC2034 # SPD_DEPENDENCY_ISSUE used by caller
        SPD_DEPENDENCY_ISSUE=1
    fi
}

display_list_content() {
    # Displays content of list variable, with each item on a new line
    _dlc_variable="$1"

    expand_config_var "$_dlc_variable"
    eval "_dlc_value=\"\${$_dlc_variable}\""
    [ "$2" = "no_label" ] || lbl_3 "$_dlc_variable:"
    if [ -n "$_dlc_value" ]; then
        for _item in $_dlc_value; do
            lbl_4 "  $_item"
        done
    else
        lbl_4 "  *empty*"
    fi
}

indicate_unset() {
    case "$1" in
        '') echo "*unset*" ;;
        *) echo "$1" ;;
    esac
}

cmd_line_param_list() {
    _lbl="${1:-Listing of cmd line options}"
    lbl_2 "$_lbl"
    lbl_4 "  opt_task    $(indicate_unset "$opt_task")"
}

cmd_line_param_error() {
    lbl_1 "Invalid command-line param"
    # cmd_line_param_list "Processed options"
    err_msg "$1"
}

cmd_line_param_parse() {
    while [ -n "$1" ]; do
        case "$1" in
            install) opt_task=install ;;
            remove) opt_task=remove ;;
            *) err_msg "Unrecognized major option: $1" ;;
        esac
        shift
    done

    cmd_line_param_list
}

check_for_abort() {
    _cfa_max="${1:-0}"
    _cfa_lbl="${2:- current task}"

    expand_config_var SPD_ABORT
    [ -n "$SPD_ABORT" ] || err_msg "SPD_ABORT undefined"
    {
        dbg_msg "check_for_abort() ${SPD_ABORT:-0}  max: $_cfa_max" 1
        # log_it "SPD_ABORT: $SPD_ABORT"
        [ "$SPD_ABORT" -gt "$_cfa_max" ] && {
            err_msg "$module_name: SPD_ABORT=$SPD_ABORT prevents running $_cfa_lbl"
        }
    }

    case "$opt_task" in
        install) [ "$SPD_DEPENDENCY_ISSUE" != 0 ] && {
            err_msg "$module_name: Dependency issue - Aborting $opt_task"
        } ;;

        remove) [ "$SPD_DEPENDENCY_ISSUE" = 1 ] && {
            err_msg "$module_name: Dependency issue - Aborting $opt_task"
        } ;;
        *) ;;
    esac
}

get_config() {
    #
    # To ensure no previous task's config spills over, we process the entire config
    # hierarchy for each task
    #
    _gc_config_file="${1:-}"
    [ -n "$_gc_config_file" ] && {
        [ -f "$_gc_config_file" ] || {
            err_msg "Config file not found: $_gc_config_file"
        }
    }
    # current_dbg_lvl=5
    read_config_file "$D_REPO"/configs/defaults.yml

    # file system related
    fs_is_alpine && read_config_file "$D_REPO"/configs/file_systems/alpine.yml
    fs_is_debian && read_config_file "$D_REPO"/configs/file_systems/debian.yml
    fs_is_devuan && read_config_file "$D_REPO"/configs/file_systems/devuan.yml
    fs_is_ubuntu && read_config_file "$D_REPO"/configs/file_systems/ubuntu.yml

    # platform related
    is_linux && read_config_file "$D_REPO"/configs/platform/linux.yml
    is_macos && read_config_file "$D_REPO"/configs/platform/macos.yml
    if is_ish; then
        read_config_file "$D_REPO"/configs/platform/ish.yml
        # subcategory for iSH, to allow overrides for AOK vs non-AOK
        is_ish_aok && read_config_file "$D_REPO"/configs/platform/ish_aok.yml
    elif is_chrooted_ish; then
        # When testing/preparing an iSH FS chrooted
        read_config_file "$D_REPO"/configs/platform/ish.yml
    fi

    [ -n "$_gc_config_file" ] && {
        # task specific config file, comes after platform and fs specifics, to allow overrides
        read_config_file "$_gc_config_file"
    }

    # user overrides
    read_config_file "$D_REPO"/configs/global_overrides.yml

    # hostname specific overrides comes last, to allow per device overrides
    read_config_file "$D_REPO/configs/hostname/$(hostname -s | tr '[:upper:]' '[:lower:]').yml"
}

load_utils() {
    _lu_f_utils="$D_REPO"/tools/script-utils.sh
    [ -f "$_lu_f_utils" ] || {
        printf '\n%s[%s] ERROR: source file not found: %s\n' \
            "$module_name" "$$" "$_lu_f_utils" >&2
        exit 1
    }
    # shellcheck source=tools/script-utils.sh
    . "$_lu_f_utils"
    [ -n "$t_start" ] || {
        # guaranteed variable undefined, sourcing must have failed
        printf '\n%s[%s] ERROR: Sourcing %s failed to define: t_start\n' \
            "$0" "$$" "$_lu_f_utils" >&2
        exit 1
    }
}

#=====================================================================
#
#   Main
#
#=====================================================================

# echo "><> processing prepare_env"

[ -n "$D_REPO" ] || {
    printf '\n%s[%s] ERROR: This can not be run directly.\n' "$0" "$$" >&2
    exit 1
}

module_name="${module_name:-$0}"

load_utils
populate_config

lbl_1 "Module: $module_name"

cmd_line_param_parse "$@"
source_it "$D_REPO"/tools/process-config_file.sh
get_config
