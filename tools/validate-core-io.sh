#!/bin/sh

#
#  Part of https://github.com/jaclu/spd
#
#  Copyright (c) 2026: Jacob.Lundqvist@gmail.com
#
#  License: MIT
#
#  Some systems like iSH for example, occasionally boots up with broken/missing
#  core IO. This validates and attempts to fix any issues found.
#
#  If this does not exit 0, assume a broken environment.
#

err_msg() {
    printf '\n\n%s[%s] ERROR: %s\n' "$0" "$$" "$1" >&2
    exit 99
}

validate_dev_null() {
    # Structural check only
    [ -c /dev/null ] && return 0

    rm -f /dev/null
    mknod /dev/null c 1 3 || err_msg "/dev/null broken - failed to fix it."
    chmod 666 /dev/null
}

validate_dev_fd() {
    name=$1
    target=$2
    path=/dev/$name

    verify_fd "$name" "$path" && return 0

    tmp=/dev/.${name}.$$

    if ! ln -s "$target" "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        err_msg "$path broken - failed to fix it."
    fi

    # Re-check if fixed by something else during this (short) operation
    verify_fd "$name" "$path" && {
        rm -f "$tmp"
        return 0
    }
    mv -f "$tmp" "$path"
}

verify_fd() {
    _vf_name=$1
    _vf_path=$2
    case $_vf_name in
        stdin) : <"$_vf_path" 2>/dev/null && return 0 ;;
        stdout) : >"$_vf_path" 2>/dev/null && return 0 ;;
        stderr) : 2>"$_vf_path" : && return 0 ;;
        *) err_msg "verify_fd() called with invalid $_vf_name" ;;
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

# exit 0
