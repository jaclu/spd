#!/bin/sh

#
# Variable naming strategy
#
# All config related variables are all upper case starting with SPD_
#
# All local per function variables are _ prefixed, typically followed by an
# acronym based on the function name
# global variables are lower case without _ prefix
#

package_install() {
    # Attempts to install one or more packages, if it can guess the package handler
    _pi_pkg="$*"
    [ -z "$_pi_pkg" ] && err_msg "package_install() - no param"
    lbl_2 "package_install() attempting to install: $_pi_pkg" 1
    if fs_is_alpine; then
        cmd_wrapper_t sh -c 'apk update && apk add '"$_pi_pkg"
    elif fs_is_debian || fs_is_devuan; then
        cmd_wrapper_t sh -c 'apt update && apt install -y '"$_pi_pkg"
    else
        lbl_2 "package_install() - Failed to recognize platform - unable to install $_pi_pkg"
        return 1
    fi
}

copy_items() {
    _ci_d_src="$1"
    _ci_d_dst="$2"
    _ci_selected_items="$3" # if $_fu_all_files, assume all
    _ci_all_files="-all-"   # when copying folders indicates all should be copied
    _ci_no_files="-none-"   # when copying folders indicates nothing should be copied
    expand_yaml_config_var SPD_NO_FILE_COPY_REPLACEMENTS

    [ -d "$_ci_d_src" ] || err_msg "copy_items() - source not a folder: $_ci_d_src"
    [ "$_ci_selected_items" = "$_ci_no_files" ] && {
        lbl_3 "Nothing from $_ci_d_src copied, selection: $_ci_no_files"
        return
    }

    mkdir -p "$_ci_d_dst" || err_msg "Failed: mkdir -p $_ci_d_dst"

    _ci_files_found=0
    if [ "$_ci_selected_items" = "$_ci_all_files" ]; then
        lbl_3 "Copying $_ci_d_src/ -> $_ci_d_dst" 1
        for _ci_f_src in "$_ci_d_src"/*; do
            [ -f "$_ci_f_src" ] || continue
            _ci_f_name_rel="${_ci_f_src##*/}"
            _ci_f_dst="$_ci_d_dst/$_ci_f_name_rel"
            # shellcheck disable=SC2154 # SPD_NO_FILE_COPY_REPLACEMENTS defined in config
            [ -e "$_ci_f_dst" ] && is_yaml_true "$SPD_NO_FILE_COPY_REPLACEMENTS" && {
                err_msg "copy_items() - file already exists: $_ci_f_dst"
            }
            cp -a "$_ci_f_src" "$_ci_f_dst" || {
                err_msg "copy_items() - Failed to copy $_ci_f_src"
            }
            _ci_files_found=1
        done
    else
        lbl_3 "Copying subset of $_ci_d_src/ to $_ci_d_dst" 1
        # lbl_4 "  $_ci_selected_items" 1
        for _ci_f_name_rel in $_ci_selected_items; do
            _ci_f_src="$_ci_d_src/$_ci_f_name_rel"
            _ci_f_dst="$_ci_d_dst/$_ci_f_name_rel"
            [ -f "$_ci_f_src" ] || {
                err_msg "copy_items() - Source not found: $_ci_f_src"
            }
            [ -e "$_ci_f_dst" ] && {
                err_msg "copy_items() - file already exists: $_ci_f_dst"
            }
            lbl_4 "  $_ci_f_src -> $_ci_f_dst" 1
            cp -a "$_ci_f_src" "$_ci_f_dst" || {
                err_msg "copy_items() - Failed to copy $_ci_f_src"
            }
            _ci_files_found=1
        done
    fi
    [ "$_ci_files_found" -eq 0 ] && lbl_4 "No files found"
}

#---------------------------------------------------------------------
#
#   Internals / only used here
#
#---------------------------------------------------------------------

pe_inform_about_debug_levels() {
    _pe_f_user_warned="$D_REPO"/.user_warned
    [ -f "$_pe_f_user_warned" ] || {
        printf '\n%s %s\n%s %s\n%s\n' \
            "Unless SPD_DEBUG_LEVEL is at least 1," \
            "these tools will be completely silent." \
            "Only displaying any error messages." \
            "(This is only shown first time this is run)" \
            "For more info see the README.md"
        touch "$_pe_f_user_warned" || {
            # ignore this error
            :
        }
    }
}

pe_source_script_utils() {
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

pe_get_basic_config() {
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

    parse_yaml_config_file "$D_REPO"/configs/defaults.yml

    # file system related
    fs_is_alpine && parse_yaml_config_file "$D_REPO"/configs/file_systems/alpine.yml
    fs_is_debian && parse_yaml_config_file "$D_REPO"/configs/file_systems/debian.yml
    fs_is_devuan && parse_yaml_config_file "$D_REPO"/configs/file_systems/devuan.yml
    # fs_is_ubuntu && parse_yaml_config_file "$D_REPO"/configs/file_systems/ubuntu.yml

    # platform related
    is_linux && parse_yaml_config_file "$D_REPO"/configs/platform/linux.yml
    is_macos && parse_yaml_config_file "$D_REPO"/configs/platform/macos.yml
    if is_ish_abstract; then
        parse_yaml_config_file "$D_REPO"/configs/platform/ish.yml
        # subcategory for iSH, to allow overrides for AOK vs non-AOK
        is_ish_aok && parse_yaml_config_file "$D_REPO"/configs/platform/ish_aok.yml
    fi

    # [ -n "$_gc_config_file" ] && {
    #     # task specific config file, comes after platform and fs specifics, to allow overrides
    #     parse_yaml_config_file "$_gc_config_file"
    # }

    # user overrides
    parse_yaml_config_file "$D_REPO"/configs/global_overrides.yml

    # hostname specific overrides comes last, to allow per device overrides
    parse_yaml_config_file "$D_REPO/configs/hostname/$(hostname -s \
        | tr '[:upper:]' '[:lower:]').yml"

    # always do this last, after any other config files parsed!
    parse_yaml_config_file "$D_REPO"/configs/global_overrides.yml
}

pe_populate_config() {
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

#---------------------------------------------------------------------
#
#   Option parsing
#
#---------------------------------------------------------------------

pe_indicate_unset() {
    case "$1" in
        '') echo "*unset*" ;;
        *) echo "$1" ;;
    esac
}

pe_cmd_line_param_list() {
    is_debug_lvl 1 || return
    _pclpl_lbl="${1:-Listing of cmd line options}"
    lbl_2 "$_pclpl_lbl"
    lbl_4 "  opt_task    $(pe_indicate_unset "$opt_task")"
}

pe_cmd_line_param_parse() {
    opt_task=install # defaults to install
    while [ -n "$1" ]; do
        case "$1" in
            install) opt_task=install ;; # handling tasks sending it as a param
            remove) opt_task=remove ;;   # Remove service etc, not accepted by all tasks
            force | force-install)
                # Used to force an install in cases where the task displays a warning
                # and aborts on install, example a service not properly working on
                # the used platform
                opt_task=force-install
                ;;
            *)
                pe_cmd_line_param_list
                err_msg "Unrecognized major option: $1"
                ;;
        esac
        shift
    done
    pe_cmd_line_param_list
}

cmd_line_param_error() {
    lbl_1 "Invalid command-line param"
    # pe_cmd_line_param_list "Processed options"
    err_msg "$1"
}

#---------------------------------------------------------------------
#
#   Dependency handling
#
# SPD_ABORT is a global typically set per host config that limits what tasks can be done
# on a host
#
# SPD_ABORT=0 host can be investigated and things can be deployed
#
# SPD_ABORT=1 pending task can be investigated to check for dependency issues, nothing
#             can be installed/configured etc, essentially no changes, inspect at will
#
# SPD_ABORT>1 spd should not run on this host in any capacity
#
#---------------------------------------------------------------------

check_for_abort() {
    _cfa_max="${1:-0}"
    _cfa_lbl="${2:- current task}"

    expand_yaml_config_var SPD_ABORT
    lbl_4 "check_for_abort() SPD_ABORT: $SPD_ABORT" 4
    [ -n "$SPD_ABORT" ] || err_msg "required config variable SPD_ABORT undefined"
    {
        dbg_msg "check_for_abort() ${SPD_ABORT:-0}  max: $_cfa_max" 9
        [ "$SPD_ABORT" -gt "$_cfa_max" ] && {
            err_msg "SPD_ABORT=$SPD_ABORT prevents running $_cfa_lbl"
        }
    }

    case "$opt_task" in
        install) [ "$spd_dependency_issue" != 0 ] && {
            err_msg "Dependency issue - Aborting $opt_task"
        } ;;

        remove) [ "$spd_dependency_issue" = 1 ] && {
            err_msg "Dependency issue - Aborting $opt_task"
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
    # Expands variable, then displays it if is_debug_lvl >= 3
    # otherwise print dependency warning and set spd_dependency_issue=1
    # to inicate dependency issue for caller
    _esvd_variable="$1"

    expand_yaml_config_var "$_esvd_variable"
    eval "_esvd_value=\"\${$_esvd_variable}\""
    if [ -n "$_esvd_value" ]; then
        lbl_4 "$_esvd_variable:   $_esvd_value" 3
        return 0
    else
        lbl_3 "${module_name:-}: Dependency issue - $_esvd_variable no content/undefined"
        # shellcheck disable=SC2034 # spd_dependency_issue used by caller
        spd_dependency_issue=1
        return 1
    fi
}

expand_show_spd_var() {
    _essv_variable="$1"
    _essv_value="" # used when retrieving content

    expand_yaml_config_var "$_essv_variable"
    eval "_essv_value=\"\${$_essv_variable}\""
    is_debug_lvl 1 || return
    if [ -n "$_essv_value" ]; then
        # printf '%s\t\t%s\n' "$_essv_variable" "$_essv_value"
        lbl_4 "$_essv_variable:   $_essv_value"
    else
        [ -n "$_esvf_empy_ok" ]
        lbl_4 "$_essv_variable:   -unset-"
    fi
}

display_list_content() {
    # Displays content of list variable, with each item on a new line
    # set param 2 to no_label if the name of the listed variables should not be printed
    _dlc_variable="$1"

    is_debug_lvl 1 || return
    expand_yaml_config_var "$_dlc_variable" # ensure it has been expanded
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
#   General utils
#
#---------------------------------------------------------------------

relative_path_repo() {
    # For files in this repo, returns path relative to D_REPO
    printf '%s\n' "${1#"$D_REPO"/}"
}

cleanup_custom() {
    #
    # Called at the very end of script_utils_cleanup, so all cleanup has been completed
    #
    # The exit code is mostly informational, if this returns to script_utils_cleanup
    # it will exit with this code.
    # It might still be good to know if this is a successful or an error exit
    #
    #
    _cc_ex_code="$1"

    is_debug_lvl 1 && display_app_run_time
}

#---------------------------------------------------------------------
#
#   FS Specific
#
#---------------------------------------------------------------------

alpine_release_ge() {
    # usage: alpine_release_ge MAIN.MIN   (e.g., alpine_release_ge 3.20)
    # returns: 0 (true) if running Alpine >= MAIN.MIN, else 1
    _arg_req=$1

    # parse running version
    _arg_ver=$(cat /etc/alpine-release 2>/dev/null) || return 1
    _arg_cur_maj=${_arg_ver%%.*}
    _arg_rest=${_arg_ver#*.}
    _arg_cur_min=${_arg_rest%%.*}

    # parse required version
    _arg_reqM=${_arg_req%%.*}
    _arg_rest=${_arg_req#*.}
    _arg_rreqm=${_arg_rest%%.*}

    # numeric compare
    [ "$_arg_cur_maj" -gt "$_arg_reqM" ] \
        || { [ "$_arg_cur_maj" -eq "$_arg_reqM" ] && [ "$_arg_cur_min" -ge "$_arg_rreqm" ]; }
}

#---------------------------------------------------------------------
#
#  Command wrapping, filtering out command output unless debugging is active
#  or command failed.
#
#  When current_dbg_lvl=0 cnd output is saved to tmpfile, only displayed if it failed
#  If debugging is active cmd output is always displayed directly to stdout
#
# Typical workflows:
#
#   cmd_wrapper_t - displays time elapsed if >= 2s otherwise the same
#
#   Case 1 - Will exit showing failed cmd output and failed command used
#
#       cmd_wrapper apt update
#
#     By pre-creating the output file once, overhead is reduced for a sequence
#     of commands, remember to purge it!
#
#       cmd_create_output_file
#       cmd_wrapper apt update
#       cmd_wrapper apt upgrade
#       cmd_wrapper apt install vim
#       cmd_purge_output_file
#
#     Normally you would just run one cmd with cmd_wrapper, if you really need to chain cmds
#     use this workaround that wraps cmd separators like ; or &&
#     The actual commands are executed insied cmd_wrapper,
#     so output display is still controllable
#       cmd_wrapper sh -c 'apt update && apt install vim'
#
#   Case 2 - will not display failed cmd or output, just exit the program with error
#     cmd_wrapper --silent apt install vim
#
#   Case 3 - will continue returning false if cmd fails after reporting error.
#     cmd_wrapper --continue no content/undefinedstall vim ||
#       ... custom error handling
#     }
#
#   Case 4 - will continue, not displaying failed cmd output or error msg
#     cmd_wrapper --silent --continue no content/undefinedstall vim ||
#       ... custom error handling
#     }
#
#---------------------------------------------------------------------

cmd_wrapper_t() {
    pe_cmd_start="$(date +%s)" # is checked in cmd_wrapper()
    cmd_wrapper "$@"
    _cwt_elapsed="$(($(date +%s) - pe_cmd_start))"
    [ "$_cwt_elapsed" -ge 2 ] && {
        lbl_5 "  took: $(display_time_elapsed "$_cwt_elapsed")" 1
    }
    is_debug_lvl 2 && {
        # spacer after cmd if cmd output was displayed
        echo
    }
    pe_cmd_start=""
}

cmd_wrapper() {
    _cw_ex_code=0
    _cw_self_created_output_file=0

    #
    # Option parsing
    #
    _cw_silent=0
    _cw_continue=0
    while [ -n "$1" ]; do
        case "$1" in
            -s | --silent) _cw_silent=1 ;;     # dont report error, juest exit
            -c | --continue) _cw_continue=1 ;; # dont abort on error just return false
            -*) err_msg "cmd_wrapper() - Unknown option: [$1]" ;;
            *) break ;; # no more options
        esac
        shift
    done
    _cw_cmd="$*" # only used for presentation, cmd is executed as "$@"
    _cw_err_msg="Command failed: $_cw_cmd"

    [ -z "$pe_f_cmd_output" ] && {
        cmd_create_output_file
        _cw_self_created_output_file=1
    }
    [ -f "$pe_f_cmd_output" ] || printf '\n%s\n' "$_cw_cmd" # show cmd if not using file
    if "$@" >"$pe_f_cmd_output" 2>&1; then
        [ ! -f "$pe_f_cmd_output" ] && [ -z "$pe_cmd_start" ] && {
            # spacer after cmd in not using output file and displaying time
            echo
        }
    else
        pe_cmd_err "$_cw_err_msg" "$_cw_silent" "$_cw_continue"
        _cw_ex_code=1 # in case continue has been requested
    fi
    # only purge if the cmd output file was created here
    [ "$_cw_self_created_output_file" -eq 1 ] && cmd_purge_output_file
    return "$_cw_ex_code"
}

cmd_create_output_file() {
    if is_debug_lvl 2; then
        pe_f_cmd_output=/dev/stdout
    else
        tmp_file_create pe_f_cmd_output
    fi
    dbg_msg "cmd_create_output_file() filtered commd output is now: $pe_f_cmd_output" 5
}

cmd_purge_output_file() {
    [ -n "$pe_f_cmd_output" ] && [ -f "$pe_f_cmd_output" ] && tmp_file_remove "$pe_f_cmd_output"
    pe_f_cmd_output="" # indicate inactive
}

pe_cmd_err() {
    _pce_msg="${1:-Command failed}"
    _pce_silent="${2:-0}"
    _pce_continue="${3:-0}"

    if [ "$_pce_silent" -eq 1 ]; then
        if [ "$_cw_continue" -eq 1 ]; then
            return
        else
            cmd_purge_output_file
            script_utils_cleanup 1
        fi
    fi

    [ -f "$pe_f_cmd_output" ] && {
        # Only display if saved to file - spacer and actual command
        printf '\n\n%s\n' "$_cw_cmd"

        cat "$pe_f_cmd_output"
        echo
    }

    if [ "$_pce_continue" -eq 1 ]; then
        echo # spacer after command output
        lbl_2 "ISSUE: $_pce_msg"
        return
    else
        cmd_purge_output_file
        err_msg "$_pce_msg"
    fi
}

#=====================================================================
#
#   Main
#
#=====================================================================

[ -n "$D_REPO" ] || {
    printf '\n%s[%s] ERROR: This can not be run directly, should be sourced.\n' "$0" "$$" >&2
    exit 1
}

pe_inform_about_debug_levels

module_name="${module_name:-$(basename "$0")}"
app_name="$module_name"

# if set in the env save it before sourcing script-utils
pe_initial_dbg_lvl="$current_dbg_lvl"
# shellcheck disable=SC2034 # d_files_base used by caller
d_files_base="$D_REPO"/files

#
# iSH-specific initialization guard for core /dev I/O stability.
# Only relevant on iSH; has no effect on other platforms.
#
[ -d /proc/ish ] && {
    "$D_REPO"/tools/validate-core-io.sh || {
        printf '%s\n' "validate-core-io failed (iSH environment)" >&2
        exit 1
    }
}

pe_source_script_utils
pe_populate_config

lbl_1 "Module: $module_name" 1

pe_cmd_line_param_parse "$@"

# Provides parse_yaml_config_file & expand_yaml_config_var
source_it "$D_REPO"/tools/process-yaml-config_file.sh

pe_get_basic_config

[ -z "$pe_initial_dbg_lvl" ] && {
    #
    # In case current_dbg_lvl has been exported to the env, do not override it
    # otherwise default to 1 in order to display progress for cmd_wrapper
    # since sctipt-utils.sh hasn't been sourced yet and thus set_debug_lvl is not
    # yet available. In addition that script would default it to 0 if undefined.
    # All this results in that we have to manually set the variable directly
    # at this point to both have an opinion and respect current env preferences
    #

    # shellcheck disable=SC2218 # defined in process-yaml-config_file.sh sourced above
    expand_yaml_config_var SPD_DEBUG_LEVEL         # dont nag if it is empty
    [ -z "$SPD_DEBUG_LEVEL" ] && SPD_DEBUG_LEVEL=1 # global default
    set_debug_lvl "$SPD_DEBUG_LEVEL"
}

# err_msg "current_dbg_lvl [$current_dbg_lvl]"
