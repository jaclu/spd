#!/bin/sh

#
# Part of https://github.com/jaclu/spd
#
# Copyright (c) 2026 Jacob Lundqvist <jacob.lndqvist@gmail.com>
# License: MIT
#
# Solves an issue I have only noticed in iSH:
# At startup stdio devices are absent or occasionally garbled. The fixes are platform
# Neutral, but I doubt other platforms need this.
#
# Validates and repairs standard I/O device nodes when required:
#   /dev/null, /dev/stdin, /dev/stdout, /dev/stderr
#
# The fixes follow pure POSIX, so should be applicable on any system.
# So far I have only noted a recurring need for this on ISH
# No effect on other platforms. Minimal overhead when devices are healthy.
# Uses generic POSIX mechanisms where possible.
#

failed_to_fix_dev_err_msg() {
    dev_name=${1:-[missing stdio device argument]}

    printf '\n\n%s\n%s%s\n\n' \
        "$0[$$] ERROR: $dev_name check failed and could not be repaired." \
        "This affects basic I/O redirection and " \
        "may break standard shell operations." \
        >&2

    exit 1
}

dev_fixed_notification() {
    printf '%s: Device has been repaired: %s\n' "$0" "$1"
}

validate_dev_null() {
    # Structural check only
    [ -c /dev/null ] && return 0

    rm -f /dev/null
    mknod /dev/null c 1 3 || failed_to_fix_dev_err_msg /dev/null
    chmod 666 /dev/null
    dev_fixed_notification /dev/null
}

validate_dev_fd() {
    name=$1
    target=$2
    path=/dev/$name

    verify_fd "$name" "$path" && return 0

    tmp=/dev/.${name}.$$

    if ! ln -s "$target" "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        failed_to_fix_dev_err_msg "$path"
    fi

    # Re-check if fixed by something else during this (short) operation
    verify_fd "$name" "$path" && {
        rm -f "$tmp"
        return 0
    }
    mv -f "$tmp" "$path"
    dev_fixed_notification "$path"
}

verify_fd() {
    _vf_name=$1
    _vf_path=$2
    [ -e "$_vf_path" ] || return 1 # device entirely missing

    case $_vf_name in
        stdin) : <"$_vf_path" 2>/dev/null && return 0 ;;
        stdout) : >"$_vf_path" 2>/dev/null && return 0 ;;
        stderr) : 2>"$_vf_path" : && return 0 ;;
        *)
            printf 'ERROR: verify_fd() called with invalid parameter: %s\n' \
                "$_vf_name"
            exit 1
            ;;
    esac
    return 1
}

#=====================================================================
#
#   Main
#
#=====================================================================

validate_dev_null

validate_dev_fd stdin /proc/self/fd/0
validate_dev_fd stdout /proc/self/fd/1
validate_dev_fd stderr /proc/self/fd/2
