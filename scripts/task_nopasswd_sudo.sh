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


task_nopasswd_sudo() {
    msg_2 "no-pw sudo for group wheel"
    if [ "$SPD_TASK_DISPLAY" != "1" ]; then
        ensure_installed sudo
        grep restore-ish /etc/sudoers > /dev/null
        if [ $? -eq 1 ]; then
            msg_3 "adding %wheel NOPASSWD to /etc/sudoers"
            echo "%wheel ALL=(ALL) NOPASSWD: ALL # added by restore-ish" >> /etc/sudoers
        else
            msg_3 "pressent"
        fi
    elif [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        echo "Will NOT be set"
    else
        echo "will be set if not done already"
    fi
    echo
}


#==========================================================
#
#   Internals
#
#==========================================================

_run_this() {
    task_nopasswd_sudo
    echo "Task Completed."
}

_display_help() {
    echo "task_nopasswd_sudo.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Installs sudo and creates a no password sudo group wheel, if it does not allready exist."
    echo "This task has no direct params, running this will create the group."
    echo
    echo "Env paramas"
    echo "-----------"
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
