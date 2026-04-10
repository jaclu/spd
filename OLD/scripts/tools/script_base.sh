#!/bin/sh
# shellcheck disable=SC2154
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-09-02
# License: MIT
#
# Part of https://github.com/jaclu/spd
#
# See explanation in the top of extras/utils.sh
# for some recommendations on how to set up your modules!
#

_display_help() {
    echo "$(basename "$0") [-h] [-c] [-x] [-v]"
    echo "  -h  - Displays help about this task."
    echo "  -c  - reads config files for params"
    echo "  -x  - Run this task, otherwise just display what would be done"
    echo "  -v  - verbose, display more progress info"
    echo
    echo "Tasks included:"

    # loop over lines in $script_tasks
    set -f
    IFS='
'
    # shellcheck disable=SC2086
    # next line can not use quotes
    set -- $script_tasks
    while [ -n "$1" ]; do
        # print first line
        echo "  $1"
        shift
    done
    set +f
    unset IFS
    echo

    if [ -n "$script_description" ]; then
        echo "$script_description"
        echo
    fi

    echo "Env parameters"
    echo "-----------"
    #
    # This executes help_local_params if defined, otherwise makes a
    # dummy assignment
    #
    {
        # Only do extra LF if help_local_params existed...
        help_local_parameters 2>/dev/null && echo
    } || _=0 # generic dummy statement

    echo "SPD_TASK_DISPLAY$(
        test -z "$SPD_TASK_DISPLAY" &&
            echo '      - if 1 will only display what will be done' ||
            echo "=$SPD_TASK_DISPLAY"
    )"
    echo "SPD_DISPLAY_NON_TASKS$(
        test -z "$SPD_DISPLAY_NON_TASKS" &&
            echo ' - if 1 will show what will NOT happen' ||
            echo "=$SPD_DISPLAY_NON_TASKS"
    )"
    echo
}

#=====================================================================
#
#     main
#
#=====================================================================

if test -z "$DEPLOY_PATH"; then
    error_msg "ERROR: script_base.sh MUST be sourced!"
fi

# shellcheck disable=SC1091
. "${DEPLOY_PATH}/scripts/tools/utils.sh"

run_as_root "$@"

# Param/env check
: "${script_tasks:?Variable script_tasks not set}"

#
#  Identify filesystem, some operations depend on it
# SPD_FILE_SYSTEM -> SPD_ISH_KERNEL
# if grep 2>/dev/null -q ish-AOK /proc/version; then
#     SPD_ISH_KERNEL='AOK'
# else
#     # shellcheck disable=SC2034
#     SPD_ISH_KERNEL='iSH'
# fi

parse_command_line "$@"

if [ "$p_help" = 1 ]; then
    _display_help
else
    #
    # Limit in what conditions script can be executed
    # Displaying what will happen is harmless and can run at any
    # time.
    #
    if [ "$SPD_TASK_DISPLAY" != "1" ]; then
        if [ "$SPD_ABORT" = "1" ]; then
            error_msg "Detected SPD_ABORT=1  Your settings prevent this device to be modified"
        fi
        [ "$(uname)" != "Linux" ] && error_msg "This only runs on Linux!"
        [ "$(whoami)" != "root" ] && error_msg "Need to be root to run this"
    fi
    _run_this
    #
    # Always display this final message  in standalone,
    # to indicate process terminated successfully.
    # And did not die in the middle of things...
    #
    echo "Task Completed."
    echo
fi
