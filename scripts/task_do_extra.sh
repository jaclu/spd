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


if test -z "$DEPLOY_PATH" ; then
    # Most likely not sourced...
    DEPLOY_PATH="$(dirname "$0")/.."               # relative
    DEPLOY_PATH="$( cd "$DEPLOY_PATH" && pwd )"  # absolutized and normalized
fi



#==========================================================
#
#   Public functions
#
#==========================================================

task_do_extra_task() {
    msg_txt="Running custom task"
    if [ "$SPD_EXTRA_TASK" != "" ]; then
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_2 "$msg_txt"
            echo "$SPD_EXTRA_TASK"
        else
            msg_1 "$msg_txt"
        fi
        test -f "$SPD_EXTRA_TASK" || error_msg "$SPD_EXTRA_TASK not found" 1
        test -x "$SPD_EXTRA_TASK" || error_msg "$SPD_EXTRA_TASK not executable" 1
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            echo "Running:   $SPD_EXTRA_TASK"
            echo
            . "$SPD_EXTRA_TASK"
            echo "Completed: $SPD_EXTRA_TASK"
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "NO custom task will be run"
    fi
    echo
}



#==========================================================
#
#   Internals
#
#==========================================================

_run_this() {
    task_do_extra_task
    echo "Task Completed."
}


_display_help() {
    echo "task_do_extra.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Runs additional script defined by SPD_EXTRA_TASK"
    echo "Intended as part of ish-restore, not realy that meaningful"
    echo "to run standalone."
    echo "This is mostly for describing and testing the script"
    echo
    echo "Env paramas"
    echo "-----------"
    echo "SPD_EXTRA_TASK$(test -z "$SPD_EXTRA_TASK" && echo ' - script with additional task(-s) Will be sourced, so can use existing functions and variables' || echo =$SPD_EXTRA_TASK )"
    echo
    echo "SPD_TASK_DISPLAY$(test -z "$SPD_TASK_DISPLAY" && echo ' -  if 1 will only display what will be done' || echo =$SPD_TASK_DISPLAY)"
    echo "SPD_DISPLAY_NON_TASKS$(test -z "$SPD_DISPLAY_NON_TASKS" && echo ' -  if 1 will show what will NOT happen' || echo =$SPD_DISPLAY_NON_TASKS)"
}



#==========================================================
#
#     main
#
#==========================================================

if [ "$SPD_INITIAL_SCRIPT" = "" ]; then

    . "$DEPLOY_PATH/scripts/extras/utils.sh"
    
    #
    # Since sourced mode cant be detected in a practiacl way under ash,
    # I use this workaround, first script is expected to set it, if set
    # script can assume to be sourced
    #
    SPD_INITIAL_SCRIPT=1
fi
