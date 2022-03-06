#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-09-02
# License: MIT
#
# Part of https://github.com/jaclu/spd
#
# See explaination in the top of extras/utils.sh
# for some recomendations on how to set up your modules!
#

#
# This should only be sourced...
#
_this_script="script_base.sh"
if [ "$(basename "$0")" = ${_this_script} ]; then
    echo "ERROR: ${_this_script} is not meant to be run stand-alone!"
    exit 1
fi
unset _this_script


# Param/env check
: "${script_tasks:?Variable script_tasks not set}"





_display_help() {
    echo "$(basename "$0") [-h] [-c] [-x] [-v]"
    echo "  -h  - Displays help about this task."
    echo "  -c  - reads config files for params"
    echo "  -x  - Run this task, otherwise just display what would be done"
    echo "  -v  - verbose, display more progress info"
    echo
    echo "Tasks included:"

    # loop over lines in $script_tasks
    set -f; IFS='
'
    # shellcheck disable=SC2086
    # next line can not use quotes
    set -- $script_tasks
    while [ -n "$1" ]; do
        # print first line
        echo "  $1"
        shift
    done
    set +f; unset IFS
    echo

    if [ -n "$script_description" ]; then
        echo "$script_description"
        echo
    fi

    echo "Env paramas"
    echo "-----------"
    #
    # This executes help_local_params if defined, otherwise makes a
    # dummy assignment
    #
    {
        # Only do extra LF if help_local_params existed...
        2> /dev/null help_local_paramas && echo
    } || _=0 # generic dummy statement

    echo "SPD_TASK_DISPLAY$(
        test -z "$SPD_TASK_DISPLAY" \
        && echo '      - if 1 will only display what will be done' \
        || echo "=$SPD_TASK_DISPLAY")"
    echo "SPD_DISPLAY_NON_TASKS$(
        test -z "$SPD_DISPLAY_NON_TASKS" \
        && echo ' - if 1 will show what will NOT happen' \
        || echo "=$SPD_DISPLAY_NON_TASKS")"
    echo
}



#=====================================================================
#
#     main
#
#=====================================================================

if [ -z "$SPD_INITIAL_SCRIPT" ]; then
    if test -z "$DEPLOY_PATH" ; then
        #
        # This was most likely not sourced, define DEPLOY_PATH based
        # on location of this script. This variable is used to find config
        # files etc, so should always be set!
        #
        # First define it relative based on this scripts location
        DEPLOY_PATH="$(dirname "$0")/.."
        # Make it absolutized and normalized
        DEPLOY_PATH="$( cd "$DEPLOY_PATH" && pwd )"
    fi

    #
    #  Since sourced mode cant be detected in a practical way under a
    #  posix shell, I use this workaround.
    #  First script is expected to set it, if set all other modules
    #  can assume to be sourced.
    #
    SPD_INITIAL_SCRIPT=1

    # shellcheck disable=SC1091
    . "$DEPLOY_PATH/scripts/extras/utils.sh"

    run_task
fi
