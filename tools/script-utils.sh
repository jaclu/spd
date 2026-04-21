#!/bin/sh
# shellcheck disable=SC2292 # needed when this is imported into bash script
#
# Copyright (c) 2026: Jacob.Lundqvist@gmail.com
#
# License: MIT
#
# Part of https://github.com/jaclu/helpful-scripts
#
#  Deploys the apps in this reop
#
# If caller is a POSIX script, use this, changing path to this if need-be:
#
# load_utils() {
#     _lu_f_utils="$D_REPO"/tools/script-utils.sh
#     [ -f "$_lu_f_utils" ] || {
#         printf '\n%s[%s] ERROR: source file not found: %s\n' \
#             "$0" "$$" "$_lu_f_utils" >&2
#         exit 1
#     }
#     # shellcheck source=/dev/null
#     . "$_lu_f_utils"
#     [ -n "$t_start" ] || {
#         # guaranteed variable undefined, sourcing must have failed
#         printf '\n%s[%s] ERROR: Sourcing %s failed to define: t_start\n' \
#             "$0" "$$" "$_lu_f_utils" >&2
#         exit 1
#     }
# }
#
#  If it is a bash script, use this, changing path to this if need-be:
#
# load_utils() {
#     local d_base="${1:-$d_repo}"
#     local f_utils="$d_base"/utils/script-utils.sh
#
#     # source a POSIX file
#     # shellcheck source=utils/script-utils.sh disable=SC1091,SC2317
#     source "$f_utils" || {
#         printf '\nERROR: Failed to source: %s\n' "$f_utils" >&2
#     exit 1
#     }
# }
#
# In scripts using this, first set the following if relevant
#   app_name - will be set to basename "$0" if unset
#   current_dbg_lvl - will be set to 0 if unset
#   d_repo - no default, helper where the base path of the current proj is
#
#   then do: load_utils
#

#---------------------------------------------------------------
#
#   boolean checks
#
#---------------------------------------------------------------

is_int() {
    case $1 in
        '') return 1 ;;        # reject empty string
        -) return 1 ;;         # reject lone '-'
        -*) set -- "${1#-}" ;; # strip leading '-'
        *) : ;;                # default no-op
    esac

    case $1 in
        *[!0-9]*) return 1 ;; # reject any non-digit chars
        *) return 0 ;;        # accept pure digits
    esac
}

#
# Platform type identifiers
#
is_linux() { # returns true if kernel is Linux, very broad check
    [ "$(uname -s)" = "Linux" ]
}

is_linux_native() { # Filters out chrooted and various Linux based derivates
    is_linux || return 1
    if is_ish || is_termux || is_android || is_chrooted; then
        return 1
    fi
    return 0
}

is_macos() {
    [ "$(uname -s)" = "Darwin" ]
}

is_android() {
    #  Only used to verify this_is_linux_native
    is_termux && return 1
    [ "$(uname -o)" = "Android" ]
}

is_termux() {
    [ "$HOME" = /data/data/com.termux/files/home ]
}

is_ish() {
    [ -d /proc/ish ]
}

is_ish_aok() {
    is_ish && grep -qi ish-AOK /proc/version
    # return 0 # for devel fake aok
}

is_chrooted() {
    # this quick and simple check doesn't work on ish
    # so lets pretend for now chroot does not happen on ish
    is_linux || return 1
    [ ! -f /proc/self/mountinfo ] && return 1
    ! grep -q " / / " /proc/self/mountinfo
}

is_chrooted_ish() {
    # Relies on /opt/AOK/tools/do_chroot.sh or similar creating/removing this
    # file inside the chrooted env when entering/leaving the chroot
    is_chrooted && [ -f /etc/opt/chrooted_ish ]
}

#
# File System type identifiers
#
fs_is_alpine() {
    [ -f /etc/alpine-release ]
}

fs_is_debian() {
    [ -f /etc/debian_version ] && ! fs_is_devuan
}

fs_is_devuan() {
    test -f /etc/devuan_version
}

fs_is_ubuntu() {
    grep -qs '^ID=ubuntu$' /etc/os-release
}

is_musl_lib() {
    ldd /bin/sh 2>&1 | grep -qi musl
}

yaml_true() {
    _yt_s="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    [ -z "$_yt_s" ] && err_msg "yaml_true() - no param"
    case "$_yt_s" in
        1 | yes | true) return 0 ;;
        *) ;;
    esac
    return 1
}
# ---  not currently used

fs_is_gentoo() {
    [ -f /etc/gentoo-release ]
}

#---------------------------------------------------------------
#
#   Display msgs and errors
#
#---------------------------------------------------------------

script_utils_cleanup() {
    _suc_ex_code="$1"
    _suc_no_custom="${2:-}" # if not empty, cleanup_custom() will not be called

    # Remove all tmp files created by this script,
    # and display content if any, before removing them
    for _sc_f in $tmp_file_list; do
        [ -s "$_sc_f" ] && {
            # Only display if file has content
            printf '\n=====   [%s]%s tmp-file %s still remains, displaying content   =====\n' \
                "$$" "$app_name" "$_sc_f" >&2
            cat "$_sc_f" >&2
            printf '\n-----   end of tmp file, will remove it now   -----\n' >&2
        }
        [ -f "$_sc_f" ] && {
            was_sys_path "$_sc_f" && {
                printf '\nWARNING: tmp file: is in a sys path, not removing: %s\n' \
                    "$_sc_f" >&2
                continue
            }
            # Remove even if tmp file is empty
            rm -f "$_sc_f" || printf '\nERROR: failed to remove: %s\n' "$_sc_f"
        }
    done

    [ -z "$_suc_no_custom" ] && {
        if command -v cleanup_custom >/dev/null 2>&1; then
            cleanup_custom "$_suc_ex_code"
        fi
    }
    [ -n "$_suc_ex_code" ] && exit "$_suc_ex_code"
}

show_timestamp() {
    printf "%s" "$(date +'%y-%m-%d %T')"
}

log_it() {
    #
    #  prefix msg to display with any of the supported options
    #    -p | --pre-lf
    #    -n | --no-lf
    #    -r | --timestamp
    #
    #  if f_script_utils_log_file is defined, msg will also be appended there,
    #  log file will always us timestamp prefix
    #

    # option parsing
    _li_use_time_stamp=0
    _li_use_lf=1
    while [ -n "$1" ]; do
        case "$1" in
            ---*) break ;; # dont parse any further opts
            -p | --pre-lf) printf '\n' ;;
            -n | --no-lf) _li_use_lf=0 ;;
            -t | --timestamp) _li_use_time_stamp=1 ;;
            -*) err_msg "log_it() - Unknown option: [$1]" ;;
            *) break ;; # no more options
        esac
        shift
    done

    _s="$1"
    _t=""
    [ -z "$_s" ] && err_msg "log_it() - no param"
    if [ "$_li_use_time_stamp" = 1 ] || [ "$script_utils_always_use_time_stamps" = 1 ]; then
        _t="[$(show_timestamp)] $_s"
        _s="$_t"
    fi
    if [ "$_li_use_lf" = 1 ]; then
        printf -- '%s\n' "$_s" >&2
    else
        printf -- '%s' "$_s" >&2
    fi

    [ -z "$f_script_utils_log_file" ] && return 0 # logfile not used
    case "$_s" in
        *[![:space:]]*) ;; # more than white space - log it to file
        *) return 0 ;;     # only whitespace - skip logging it to file
    esac
    # Always use timestamp if printing to logfile
    [ -z "$_t" ] && _t="[$(show_timestamp)] $_s"
    printf -- '%s\n' "$_t" >>"$f_script_utils_log_file"
}

err_msg() {
    #
    #  Display an error message, second optional param is exit code,
    #  defaulting to 1. If exit code is -1 this will not exit, just display
    #  the error message and continue.
    #  This will always display timestamp
    #
    _em_msg="$1"
    _em_exit_code="${2:-1}"
    _em_label="${3:-ERROR}"

    case "$_em_in_progress" in
        1)
            # recursion during err_msg, display msg and abort
            _em_in_progress=2
            printf '\nRECURSION-ERROR in err_msg(): %s\n' "$1" >&2
            script_utils_cleanup 30
            ;;
        2)
            # script_utils_cleanup is recursing back again, just abort
            printf '\nDOUBLE RECURSION-ERROR in err_msg(): %s\n' "$1" >&2
            exit 39
            ;;
        *) ;;
    esac
    _em_in_progress=1

    if [ -z "$_em_msg" ]; then
        _em_msg="err_msg() - no param"
        _em_exit_code=31 # Ensure this is exited
    fi

    [ -z "$app_name" ] && app_name=$(basename "$0")

    echo >&2
    log_it "${app_name}[$$] ${_em_label}: $_em_msg" -t # should always have timestamps
    echo >&2

    [ "$_em_exit_code" -gt -1 ] && script_utils_cleanup "$_em_exit_code"
    unset _em_in_progress # in case exit code was < 0
}

msg_dbg() {
    # Deprecated, use dbg_msg instead
    dbg_msg "$@"
}

lbl_1() {
    [ -z "$1" ] && err_msg "lbl_1() no param"
    _l1_s="$1"
    shift
    echo >&2
    log_it "===  $_l1_s  ===" "${@}"
    echo >&2
}

lbl_2() {
    [ -n "$1" ] || err_msg "lbl_2() no param"
    _l2_s="$1"
    shift
    log_it "---  $_l2_s" "${@}"
}

lbl_3() {
    [ -n "$1" ] || err_msg "lbl_3() no param"
    _l3_s="$1"
    shift
    log_it " --  $_l3_s" "${@}"
}

lbl_4() {
    [ -n "$1" ] || err_msg "lbl_4() no param"
    _l4_s="$1"
    shift
    log_it "  -  $_l4_s" "${@}"
}

lbl_5() {
    [ -n "$1" ] || err_msg "lbl_5() no param"
    _l5_s="$1"
    shift
    log_it "  .  $_l5_s" "${@}"
}

#---------------------------------------------------------------
#
#   Debugging
#
#   current_dbg_lvl=0 means only dbg_msg without dbg_lvl 2nd param will be displayed
#
#---------------------------------------------------------------

dbg_msg() {
    #
    # set debug lvl with param 2, if not given, will always be displayed,
    # otherwise displayed if debug lvl <= current_dbg_lvl
    # dbg_msg() does not support the log_it options --no-lf
    # timestamp will be printed if param 3 is -t or always_use_time_stamp() has
    # been called
    #
    [ -n "$1" ] || err_msg "dbg_msg() no param"
    if [ -n "$2" ]; then
        _dm_this_dbg_lvl="$2"
    else
        _dm_this_dbg_lvl=0
    fi
    [ "$_dm_this_dbg_lvl" -le "$current_dbg_lvl" ] && log_it "DBG[$_dm_this_dbg_lvl]  $1" "$3"

}

set_debug_lvl() {
    _dl_new_lvl="$1"
    is_int "$_dl_new_lvl" || err_msg "set_debug_lvl - non int param: $_dl_new_lvl"
    # current_dbg_lvl="$_dl_new_lvl"
    export current_dbg_lvl="$_dl_new_lvl" # propagate it to any subshells
}

#---------------------------------------------------------------
#
#   Timings
#
#---------------------------------------------------------------

select_safe_now_method() { # local usage by safe_now()
    #
    # Select and save the time method for future use.
    # Using milliseconds when possible
    #
    # Provides: selected_safe_now_mthd
    #
    [ -n "$selected_safe_now_mthd" ] && {
        error_msg_safe "Recursive call to: select_safe_now_method"
    }
    # log_it "select_safe_now_method()"

    if [ -d /proc ] && [ -f /proc/version ]; then
        selected_safe_now_mthd="date" # Linux with sub-second precision
    elif [ "$(uname)" = "Linux" ]; then
        selected_safe_now_mthd="date" # Termux or other Linux variations
    elif command -v gdate >/dev/null; then
        selected_safe_now_mthd="gdate" # macOS, using GNU date if available
    elif command -v perl >/dev/null; then
        selected_safe_now_mthd="perl" # Use Perl if date is not available
    else
        selected_safe_now_mthd="date" # Fallback
    fi
}

safe_now() {
    #
    #  Sets t_now to the current timestamp. If a variable name is given,
    #  it will be assigned the same value directly (no subshell).
    #
    #  Provides:
    #      t_now - current unix time
    #
    _sn_var_name="$1"

    case "$selected_safe_now_mthd" in
        date) t_now="$(date +%s%3N)" ;;   # milliseconds
        gdate) t_now="$(gdate +%s%3N)" ;; # milliseconds
        perl) t_now="$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1000')" ;;
        *)
            select_safe_now_method

            # to prevent infinite recursion, eunsure a valid timing method is now selected
            case "$selected_safe_now_mthd" in
                date | gdate | perl) ;;
                *) error_msg "safe_now($_sn_var_name) - failed to select a timing method" ;;
            esac

            safe_now "$_sn_var_name"
            return
            ;;
    esac
    [ -n "$_sn_var_name" ] && {
        # if variable name provided set it to t_now
        eval "$_sn_var_name=\"\$t_now\""
    }
}

time_span() { # display_menu() / check_speed_cutoff()
    #
    # Calculates a time span in seconds compared to param 1
    #
    # Provides: t_time_span
    #
    _ts_start="$1"

    safe_now

    # assume timestamps are in ms
    ms=$((t_now - _ts_start))
    printf '%d.%03d\n' $((ms / 1000)) $((ms % 1000))
    # t_time_span=$()
}

display_time_elapsed() {
    _dte_duration="$1"

    if [ "$_dte_duration" -gt 59 ]; then
        dte_hours=$((_dte_duration / 3600))
        dte_minutes=$(((_dte_duration % 3600) / 60))
        dte_seconds=$((_dte_duration - dte_hours * 3600 - dte_minutes * 60))
        printf '%02d:%02d:%02d' "$dte_hours" "$dte_minutes" "$dte_seconds"
    else
        printf '%ss' "$_dte_duration"
    fi
}

display_app_run_time() {
    # additional notices can be added in $1
    _dart_msg="${1:-}" # linting safe way to handle "optional" parameters...
    _dart_app_run_time=$(($(date +%s) - t_start))
    echo
    log_it "Time elapsed: $(display_time_elapsed "$_dart_app_run_time") - $app_name $_dart_msg"
}

#---------------------------------------------------------------
#
#   File checks
#
#---------------------------------------------------------------

was_sys_path() {
    case "$1" in
        /tmp/* | /var/tmp/* | "$TMPDIR"/*) return 1 ;; # tmp files can always be removed

        /bin | /bin/* | /boot | /boot/* | /dev | /dev/* | /etc | /etc/* | /home | \
            "$HOME" | /lib | /lib/* | /lib64 | /lib64/* | /lost+found | /lost+found/* | \
            /media | /media/* | /mnt | /mnt/* | /opt | /opt/* | /proc | /proc/* | \
            /root | /run | /run/* | /sbin | /sbin/* | /sys | /sys/* | /tmp | \
            /usr | /usr/* | /var | /var/* | /Users) return 0 ;;
        *) ;;
    esac
    return 1
}

_do_safe_remove() {
    _dsr_item=$1
    dbg_msg "_do_safe_remove($_dsr_item)" 3

    _sr_err_ex_code=1 # "${2:-1}"
    [ -z "$_dsr_item" ] && err_msg "safe_remove() - missing path" "$_sr_err_ex_code"

    $_sr_check_sys_path && was_sys_path "$_dsr_item" && {
        err_msg "Refusing to remove a sys-path: $_dsr_item" "$_sr_err_ex_code"
    }

    if [ -d "$_dsr_item" ]; then
        mount | grep "$_dsr_item" && {
            err_msg "safe_remove() - this is a mount point: $_dsr_item" "$_sr_err_ex_code"
        }
        if $_sr_remove_dir; then
            rm -rf -- "$_dsr_item" || {
                err_msg "Failed to remove directory: $_dsr_item" "$_sr_err_ex_code"
            }
            $_sr_display_removal && lbl_3 "Removed directory: $_dsr_item"
        else
            # shellcheck disable=SC2115 # _dsr_item is already checked for being empty
            rm -rf -- "$_dsr_item"/* "$_dsr_item"/.??* 2>/dev/null || {
                err_msg "Failed to clear directory: $_dsr_item" "$_sr_err_ex_code"
            }
            $_sr_display_removal && lbl_4 "Cleared directory: $_dsr_item"
        fi
        return
    fi

    if [ -f "$_dsr_item" ] || [ -L "$_dsr_item" ]; then
        rm -- "$_dsr_item" || {
            err_msg "Failed to remove file: $_dsr_item" "$_sr_err_ex_code"
        }
        $_sr_display_removal && lbl_4 "Removed file: $_dsr_item"
    else
        err_msg "Refusing to remove non-file: $_dsr_item" "$_sr_err_ex_code"
    fi
}

safe_remove() {
    #
    # if item is a folder it is just cleared, unless it is prefixed with --remove-dir
    # then the entie folder is removed
    # Anything containing a sys path is rejected, unless --ignore-sys-path is supplied
    #
    # After options are parsed
    #   $1  File/folder name to be removed
    #   $2  exit code on error (default: 1)
    #

    #
    # Option parsing
    #
    _sr_check_sys_path=true
    _sr_display_removal=true
    _sr_remove_dir=false

    while [ -n "$1" ]; do
        case "$1" in
            --ignore-sys-path) _sr_check_sys_path=false ;;
            -s | --silent) _sr_display_removal=false ;;
            -r | --remove-dir) _sr_remove_dir=true ;;
            -*) err_msg "Unknown option: $1" ;;
            *) break ;;
        esac
        shift
    done

    for f; do
        [ -e "$f" ] || {
            if [ -L "$f" ]; then
                dbg_msg "safe_remove - Will process dead symlink: $f" 1
            else
                dbg_msg "safe_remove - Warning ignored missing file [$f]" 1
                continue
            fi
        }
        _do_safe_remove "$f"
    done
    return 0
}

source_it() {
    # Fails if $2 was provided and that variable was not defined as non-empty
    _si_f="$1"
    _si_inspect_variable="$2"

    # dbg_msg "[$0] source_it($_si_f)"
    [ "$app_name_full_path" = "$_si_f" ] && {
        echo
        echo "WARNING: Attempt at self sourcing ignored: $_si_f"
        echo
    }

    # shellcheck source=/dev/null # filename is dynamic
    . "$_si_f"
    [ -n "$_si_inspect_variable" ] && {
        # if variable name provided verify that it has content
        eval "_v2=\"\${$_si_inspect_variable}\""
        [ -n "$_v2" ] || {
            err_msg "Sourcing $_si_f didn't define variable: $_si_inspect_variable"
        }
    }
}

#---------------------------------------------------------------
#
#   Startup preferencess - Handling tmp / log files
#
#---------------------------------------------------------------

always_use_time_stamp() {
    script_utils_always_use_time_stamps=1
}

create_f_tmp() {
    # compatibility func name
    tmp_file_create
}

# shellcheck disable=SC2120 # param is optional, if not given f_tmp will be used
tmp_file_create() {
    #
    # Generic tmp file that can be used by scripts.
    #
    # if param is provided, tmp file name will be assigned to the variable name $1
    # otherwisse f_tmp will be used. This allows for multiple tmp files if needed,
    # just call this func multiple times with different variable names.
    #
    # Any calls to err_msg() will display current content of and then remove it.
    # It will also be autoremoved once script exits, unless some of the signals
    # monitored are overridden
    #
    # To ensure a file is removed unless other exit handlers is used:
    #   trap 'rm -f "$f_tmp"' EXIT HUP INT TERM
    #

    #
    # Option parsing
    #
    _tfc_is_dir=false

    while [ -n "$1" ]; do
        case "$1" in
            -d | --directory) _tfc_is_dir=true ;;
            -*) err_msg "Unknown option: $1" ;;
            *) break ;;
        esac
        shift
    done

    _tfc_tmp_file_variable="${1:-f_tmp}"

    [ -n "$f_tmp" ] && [ -e "$f_tmp" ] && {
        # err_msg "tmp_file_create() - variable f_tmp already assigned to existing file: $f_tmp"
        safe_remove "$f_tmp"
    }

    _tfc_template="${TMPDIR:-/tmp}/${app_name:-script-utils.sh}.XXXXXX"
    if $_tfc_is_dir; then
        _tfc_f_tmp=$(mktemp -d "$_tfc_template") || {
            err_msg "mktemp failed for: $_tfc_f_tmp"
        }
        dbg_msg "Created tmp directory: $_tfc_f_tmp" 3
    else
        _tfc_f_tmp=$(mktemp "$_tfc_template") || {
            err_msg "mktemp failed for: $_tfc_f_tmp"
        }
        dbg_msg "Created tmp file: $_tfc_f_tmp" 3
    fi


    # for tracking and cleanup in err_msg()
    tmp_file_list=$(printf '%s\n%s\n' "$tmp_file_list" "$_tfc_f_tmp")

    # assign tmpfile name to selected variable name
    eval "$_tfc_tmp_file_variable=\$_tfc_f_tmp"
}

tmp_file_remove() {
    # If tmp_file is a folder, delete it and it's content
    _tfr_tmp="${1:-$f_tmp}"

    [ -z "$_tfr_tmp" ] && err_msg "tmp_file_remove() called with no param"

    case "$_tfr_tmp" in
        /dev/stdout | /dev/stderr)
            err_msg "tmp_file_remove() called with invalid param: $_tfr_tmp"
            ;;
        *)
            dbg_msg "Will remove tmp file/directory: $_tfc_f_tmp" 3
            safe_remove --silent --remove-dir "$_tfr_tmp"
            ;;
    esac
    # update list of current tmp files, removing the one just removed
    tmp_file_list=$(
        printf '%s\n' "$tmp_file_list" \
            | grep -F -x -v -- "$_tfr_tmp"
    )
}

use_log_file() {
    #
    # provide a log_file and if defined all msgs and errors will be appended there
    # after being printed to stderr. It is up to the caller to remove this logfile!
    #
    [ -z "$1" ] && err_msg "Call to use_log_file() - no param given"
    f_script_utils_log_file="$1"
}

cancel_log_file() {
    [ -z "$f_script_utils_log_file" ] || return
    safe_remove -s "$f_script_utils_log_file"
    f_script_utils_log_file=""
}

#===============================================================
#
#   Main
#
#===============================================================

# these must be done before local variables assignments,
# since some of them depend on variables defined by them
# read_config
# check_if_host_or_dest_fs

#
#  Locations for various stuff
#

# echo "><> processing script_utils"

TMPDIR="${TMPDIR:-/tmp}"
TMPDIR="${TMPDIR%/}" # strip trailing slah, mostly for MacOS

app_name_full_path=$(realpath "$0")

[ -z "$app_name" ] && app_name=$(basename "$0")
t_start="$(date +%s)" # is used in display_app_run_time()

[ -z "$current_dbg_lvl" ] && {
    # In case current_dbg_lvl has been exported to the env, do not override it
    set_debug_lvl 0
}

return 0 # ensures the above doesn't indicate sourcing failed
