#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-04-30
# License: MIT
#
# Version: 0.1.0 2021-04-30
#    Initial release
#
# Part of ishTools
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



#==========================================================
#
#   Public functions
#
#==========================================================

#
#  Assumed to start with task_ and then describe the task in a suficiently
#  unique way to give an idea of what this task does,
#  and not collide with other modules.
#  Use a short prefix unique for your module.
#

task_do_extra_task() {
    _expand_do_extra_all_deploy_paths
    msg_txt="Running custom task"
    if [ -n "$SPD_EXTRA_TASK" ]; then
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_2 "$msg_txt"
            echo "$SPD_EXTRA_TASK"
        else
            msg_1 "$msg_txt"
        fi
        test -f "$SPD_EXTRA_TASK" || error_msg "$SPD_EXTRA_TASK not found"
        test -x "$SPD_EXTRA_TASK" || error_msg "$SPD_EXTRA_TASK not executable"
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            check_abort
            echo "Running:   $SPD_EXTRA_TASK"
            echo
            # shellcheck disable=SC1090
            . "$SPD_EXTRA_TASK"
            echo "Completed: $SPD_EXTRA_TASK"
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "NO custom task will be run"
    fi
    echo

    unset msg_txt
}




#=====================================================================
#
#   Internals, start with _ to make it obvious they should not be
#   called by other modules.
#
#=====================================================================

_expand_do_extra_all_deploy_paths() {
    #
    # Expanding path variables that are either absolute or relative
    # related to the deploy-path
    #
    SPD_EXTRA_TASK=$(expand_deploy_path "$SPD_EXTRA_TASK")
}



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
    if [ -z "$SPD_EXTRA_TASK" ]; then
        warning_msg "SPD_EXTRA_TASK not set, cant test task_do_extra_task()"
    else
        task_do_extra_task
    fi
    #
    # Always display this final message  in standalone,
    # to indicate process terminated successfully.
    # And did not die in the middle of things...
    #
    echo "Task Completed."
}


_display_help() {
    _expand_do_extra_all_deploy_paths
    echo "task_do_extra.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Tasks included:"
    echo " task_do_extra_task        - Runs user supplied script"
    echo
    echo "Runs additional script defined by SPD_EXTRA_TASK"
    echo "Intended as part of ish-restore, not realy that meaningful"
    echo "to run standalone."
    echo "This is mostly for describing and testing the script"
    echo "Script will be sourced to exiting functions and variables can be used"
    echo
    echo "Env paramas"
    echo "-----------"
    echo "SPD_EXTRA_TASK$(
        test -z "$SPD_EXTRA_TASK" && echo ' - script with additional task' \
        || echo "=$SPD_EXTRA_TASK")"
    echo
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
    # Since sourced mode cant be detected in a practical way under ash,
    # I use this workaround, first script is expected to set it, if set
    # all other modules can assume to be sourced
    #
    SPD_INITIAL_SCRIPT=1
fi
