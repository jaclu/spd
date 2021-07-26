#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-07-25
# License: MIT
#
# Part of https://github.com/jaclu/spd
#
# See explaination in the top of extras/utils.sh
# for some recomendations on how to set up your modules!
#

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

# Param/env check
: "${script_tasks:?Variable script_tasks not set}"



#=====================================================================
#
# _run_this() & _display_help()
# are only run in standalone mode, so no risk for wrong same named function
# being called...
#
# In standlone mode, this will be run from See "main" part at end of
# extras/utils.sh, it first expands parameters,
# then either displays help or runs the task(-s)
#

_run_this() {
    #
    # Perform the task / tasks independently, convenient for testing
    # and debugging.
    #
    # loop over lines in $script_tasks
    #
    set -f; IFS='
'
    # shellcheck disable=SC2086
    # next line can not use quotes
    set -- $script_tasks
    while [ -n "$1" ]; do
        # execute first word from line
        IFS=' '
        $1
        # pop first line from lines
        IFS='
'
        shift
    done
    set +f; unset IFS
}


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
        # removing stderr prevents printing error if undefined
        2> /dev/null help_local_paramas
        # Only do extra LF if help_local_params existed...
        [ $? = 0 ]  && echo
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
    . "$DEPLOY_PATH/scripts/extras/utils.sh"

    #
    # Since sourced mode cant be detected in a practical way under a
    # posix shell, I use this workaround.
    # First script is expected to set it, if set all other modules
    # can assume to be sourced.
    #
    SPD_INITIAL_SCRIPT=1
fi
