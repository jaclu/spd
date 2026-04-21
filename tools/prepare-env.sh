#!/bin/sh

#---------------------------------------------------------------------
#
#   Internals / only used here
#
#---------------------------------------------------------------------

source_script_utils() {
    #
    #  Manually sourcing script-utils.sh
    #  Once loaded it offers tons of convenience functions
    #
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

get_basic_config() {
    #
    # To ensure no previous task's config spills over, we process the entire config
    # hierarchy for each task
    #
    # _gc_config_file="${1:-}"
    # [ -n "$_gc_config_file" ] && {
    #     [ -f "$_gc_config_file" ] || {
    #         err_msg "Config file not found: $_gc_config_file"
    #     }
    # }

    # current_dbg_lvl=5
    parse_yaml_config_file "$D_REPO"/configs/defaults.yml

    # file system related
    fs_is_alpine && parse_yaml_config_file "$D_REPO"/configs/file_systems/alpine.yml
    fs_is_debian && parse_yaml_config_file "$D_REPO"/configs/file_systems/debian.yml
    fs_is_devuan && parse_yaml_config_file "$D_REPO"/configs/file_systems/devuan.yml
    fs_is_ubuntu && parse_yaml_config_file "$D_REPO"/configs/file_systems/ubuntu.yml

    # platform related
    is_linux && parse_yaml_config_file "$D_REPO"/configs/platform/linux.yml
    is_macos && parse_yaml_config_file "$D_REPO"/configs/platform/macos.yml
    if is_ish; then
        parse_yaml_config_file "$D_REPO"/configs/platform/ish.yml
        # subcategory for iSH, to allow overrides for AOK vs non-AOK
        is_ish_aok && parse_yaml_config_file "$D_REPO"/configs/platform/ish_aok.yml
    elif is_chrooted_ish; then
        # When testing/preparing an iSH FS chrooted
        parse_yaml_config_file "$D_REPO"/configs/platform/ish.yml
    fi

    # [ -n "$_gc_config_file" ] && {
    #     # task specific config file, comes after platform and fs specifics, to allow overrides
    #     parse_yaml_config_file "$_gc_config_file"
    # }

    # user overrides
    parse_yaml_config_file "$D_REPO"/configs/global_overrides.yml

    # hostname specific overrides comes last, to allow per device overrides
    parse_yaml_config_file "$D_REPO/configs/hostname/$(hostname -s | tr '[:upper:]' '[:lower:]').yml"
}

populate_config() {
    # if configs is empty copy from config_templates
    spd_dependency_issue=0 # set default to no issue
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

cmd_line_param_parse() {
    while [ -n "$1" ]; do
        case "$1" in
            install) opt_task=install ;;
            remove) opt_task=remove ;;
            *)
                cmd_line_param_list
                err_msg "Unrecognized major option: $1"
                ;;
        esac
        shift
    done

    cmd_line_param_list
}

#---------------------------------------------------------------------
#
#   Dependency handling
#
#---------------------------------------------------------------------

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
        install) [ "$spd_dependency_issue" != 0 ] && {
            err_msg "$module_name: Dependency issue - Aborting $opt_task"
        } ;;

        remove) [ "$spd_dependency_issue" = 1 ] && {
            err_msg "$module_name: Dependency issue - Aborting $opt_task"
        } ;;
        *) ;;
    esac
}

#---------------------------------------------------------------------
#
#   Handling Config files
#
#---------------------------------------------------------------------

ensure_spd_var_defined() {
    # Expands variable, then displays it if current_dbg_lvl>=1
    # otherwise print dependency warning and set spd_dependency_issue=1
    # to inicate dependency issue for caller
    _esvd_variable="$1"

    expand_config_var "$_esvd_variable"
    eval "_esvd_value=\"\${$_esvd_variable}\""
    if [ -n "$_esvd_value" ]; then
        dbg_msg "$_esvd_variable: $_esvd_value" 1
    else
        lbl_2 "${module_name:-}: Dependency issue - no content/undefined: $_esvd_variable"
        # shellcheck disable=SC2034 # spd_dependency_issue used by caller
        spd_dependency_issue=1
    fi
}

#---------------------------------------------------------------------
#
#   General utils
#
#---------------------------------------------------------------------

relative_path() {
    # For files in this repo, returns path relative to D_REPO
    printf '%s\n' "${1#"$D_REPO"/}"
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

#---------------------------------------------------------------------
#
#   FS Specific
#
#---------------------------------------------------------------------

alpine_release_ge() {
    # usage: alpine_release_ge MAIN.MIN   (e.g., alpine_release_ge 3.20)
    # returns: 0 (true) if running Alpine >= MAIN.MIN, else 1
    req=$1

    # parse running version
    ver=$(cat /etc/alpine-release 2>/dev/null) || return 1
    curM=${ver%%.*}
    rest=${ver#*.}
    curm=${rest%%.*}

    # parse required version
    reqM=${req%%.*}
    rest=${req#*.}
    reqm=${rest%%.*}

    # numeric compare
    [ "$curM" -gt "$reqM" ] \
        || { [ "$curM" -eq "$reqM" ] && [ "$curm" -ge "$reqm" ]; }
}

#---------------------------------------------------------------------
#
#   Option parsing
#
#---------------------------------------------------------------------

cmd_line_param_error() {
    lbl_1 "Invalid command-line param"
    # cmd_line_param_list "Processed options"
    err_msg "$1"
}

#---------------------------------------------------------------------
#
#   Handling commmad output via tmp file f_cmd_output or /dev/stdout in case
#   current_dbg_lvl > 0
#
# Typical workflow:
#   create_cmd_output_file
#   apk update >"$f_cmd_output" 2>&1 || {
#       err_cmd "Failed to run apk update"
#  }
#   purge_cmd_output_file
#
#---------------------------------------------------------------------

create_cmd_output_file() {
    if [ "$current_dbg_lvl" -gt 0 ]; then
        f_cmd_output=/dev/stdout
    else
        tmp_file_create f_cmd_output
    fi
}

purge_cmd_output_file() {
    tmp_file_remove "$f_cmd_output"
}

err_cmd() {
    _ec_msg="${1:-Command failed}"
    [ "$f_cmd_output" != /dev/stdout ] && {
        cat "$f_cmd_output"
    }
    err_msg "$_ec_msg"
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

source_script_utils
populate_config

lbl_1 "Module: $module_name"

cmd_line_param_parse "$@"

# Provides parse_yaml_config_file & expand_config_var
source_it "$D_REPO"/tools/process-yaml-config_file.sh

get_basic_config
