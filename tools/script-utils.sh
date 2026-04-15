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

yaml_true() {
    _s="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    [ -z "$_s" ] && err_msg "yaml_true() - no param"
    case "$_s" in
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
    _sc_ex_code="$1"

    [ -n "$f_tmp" ] && {
        [ -s "$f_tmp" ] && {
            # Only display if file has content
            printf '=====   [%s]-%s f_tmp file was used, displaying content   =====\n' \
                "$(show_timestamp)" "$(hostname -s)" >&2
            cat "$f_tmp" >&2
            printf '\n-----   end of tmp file, will remove it now   -----\n' >&2
        }
        [ -f "$f_tmp" ] && {
            # Remove even if tmp file is empty
            rm -f "$f_tmp" || printf '\nERROR: failed to remove: %s\n' "$f_tmp"
        }
    }
    [ -n "$_sc_ex_code" ] && exit "$_sc_ex_code"
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
    _sr_use_time_stamp=0
    _sr_use_lf=1
    while [ -n "$1" ]; do
        case "$1" in
            ---*) break ;; # dont parse any further opts
            -p | --pre-lf) printf '\n' ;;
            -n | --no-lf) _sr_use_lf=0 ;;
            -t | --timestamp) _sr_use_time_stamp=1 ;;
            -*) err_msg "log_it() - Unknown option: [$1]" ;;
            *) break ;; # no more options
        esac
        shift
    done

    _s="$1"
    _t=""
    [ -z "$_s" ] && err_msg "log_it() - no param"
    if [ "$_sr_use_time_stamp" = 1 ] || [ "$script_utils_always_use_time_stamps" = 1 ]; then
        _t="[$(show_timestamp)] $_s"
        _s="$_t"
    fi
    if [ "$_sr_use_lf" = 1 ]; then
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
    #
    # set debug lvl with param 2, if not given, will always be displayed,
    # otherwise displayed if debug lvl <= current_dbg_lvl
    # msg_dbg() does not support the log_it options --no-lf
    # timestamp will be printed if param 3 is -t or always_use_time_stamp() has
    # been called
    #
    [ -n "$1" ] || err_msg "msg_dbg() no param"
    if [ -n "$2" ]; then
        _md_this_dbg_lvl="$2"
    else
        _md_this_dbg_lvl=0
    fi
    [ "$_md_this_dbg_lvl" -le "$current_dbg_lvl" ] && log_it "DBG  $1" "$3"
}

lbl_1() {
    [ -z "$1" ] && err_msg "lbl_1() no param"
    _s="$1"
    shift
    echo >&2
    log_it "===  $_s  ===" "${@}"
    echo >&2
}

lbl_2() {
    [ -n "$1" ] || err_msg "lbl_2() no param"
    _s="$1"
    shift
    log_it "---  $_s" "${@}"
}

lbl_3() {
    [ -n "$1" ] || err_msg "lbl_3() no param"
    _s="$1"
    shift
    log_it " --  $_s" "${@}"
}

lbl_4() {
    [ -n "$1" ] || err_msg "lbl_4() no param"
    _s="$1"
    shift
    log_it "  -  $_s" "${@}"
}

lbl_5() {
    [ -n "$1" ] || err_msg "lbl_5() no param"
    _s="$1"
    shift
    log_it "  .  $_s" "${@}"
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
    dte_duration="$1"
    # dte_t_start="$1"
    # dte_duration=$(($(date +%s) - dte_t_start))

    if [ "$dte_duration" -gt 59 ]; then
        dte_hours=$((dte_duration / 3600))
        dte_minutes=$(((dte_duration % 3600) / 60))
        dte_seconds=$((dte_duration - dte_hours * 3600 - dte_minutes * 60))
        printf '%02d:%02d:%02d' "$dte_hours" "$dte_minutes" "$dte_seconds"
    else
        printf '%ss' "$dte_duration"
    fi
}

display_app_run_time() {
    # additional notices can be added in $1
    _msg="${1:-}" # linting safe way to handle "optional" parameters...
    app_run_time=$(($(date +%s) - t_start))
    echo
    log_it "Time elapsed: $(display_time_elapsed "$app_run_time") - $app_name $_msg"
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
    _sr_item=$1
    msg_dbg "_do_safe_remove($_sr_item)" 1

    _sr_err_ex_code=1 # "${2:-1}"
    [ -z "$_sr_item" ] && err_msg "safe_remove() - missing path" "$_sr_err_ex_code"

    $_sr_check_sys_path && was_sys_path "$_sr_item" && {
        err_msg "Refusing to remove a sys-path: $_sr_item" "$_sr_err_ex_code"
    }

    if [ -d "$_sr_item" ]; then
        mount | grep "$_sr_item" && {
            err_msg "safe_remove() - this is a mount point: $_sr_item" "$_sr_err_ex_code"
        }
        if $_sr_remove_dir; then
            rm -rf -- "$_sr_item" || {
                err_msg "Failed to remove directory: $_sr_item" "$_sr_err_ex_code"
            }
            $_sr_display_removal && lbl_3 "Removed directory: $_sr_item"
        else
            # shellcheck disable=SC2115 # _sr_item is already checked for being empty
            rm -rf -- "$_sr_item"/* "$_sr_item"/.??* 2>/dev/null || {
                err_msg "Failed to clear directory: $_sr_item" "$_sr_err_ex_code"
            }
            $_sr_display_removal && lbl_4 "Cleared directory: $_sr_item"
        fi
        return
    fi

    if [ -f "$_sr_item" ] || [ -L "$_sr_item" ]; then
        rm -- "$_sr_item" || {
            err_msg "Failed to remove file: $_sr_item" "$_sr_err_ex_code"
        }
        $_sr_display_removal && lbl_4 "Removed file: $_sr_item"
    else
        err_msg "Refusing to remove non-file: $_sr_item" "$_sr_err_ex_code"
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

    # Option Parsing
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
                msg_dbg "safe_remove - Will process dead symlink: $f" 1
            else
                msg_dbg "safe_remove - Warning ignored missing file [$f]" 1
                continue
            fi
        }
        _do_safe_remove "$f"
    done
}

source_it() {
    # Fails if $2 was provided and that variable was not defined as non-empty
    _f="$1"
    _si_inspect_variable="$2"

    # msg_dbg "[$0] source_it($_f)"
    [ "$app_name_full_path" = "$_f" ] && {
        echo
        echo "WARNING: Attempt at self sourcing ignored: $_f"
        echo
    }

    # shellcheck source=/dev/null # filename is dynamic
    . "$_f"
    [ -n "$_si_inspect_variable" ] && {
        # if variable name provided verify that it has content
        eval "_v2=\"\${$_si_inspect_variable}\""
        [ -n "$_v2" ] || {
            err_msg "Sourcing $_f didn't define variable: $_si_inspect_variable"
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
    #
    # Generic tmp file that can be used by scripts.
    #
    # Any calls to err_msg() will display current content of and then remove it.
    # It will also be autoremoved once script exits, unless some of the signals
    # monitored are overridden
    #
    f_tmp=$(mktemp -t "${app_name:-script-utils.sh}"-f_tmp.XXXXXX) || {
        err_msg "mktemp failed"
    }
    trap 'rm -f "$f_tmp"' EXIT HUP INT TERM
}

use_log_file() {
    #
    # provide a log_file and if defined all msgs and errors will be appended there
    # after being printed to stderr. It is up to the caller to remove this logfile!
    #
    [ -z "$1" ] && err_msg "Call to use_log_file() - no param given"
    f_script_utils_log_file="$1"
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
    # 0 means only msg_dbg without dbg_lvl 2nd param will be displayed
    current_dbg_lvl=0
}

return 0 # ensures the above doesn't indicate sourcing failed
