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

task_update() {
    msg_2 "update & fix apk index"
    if [ "$SPD_TASK_DISPLAY" = "1" ]; then
        msg_3 "Will happen"
    elif ! apk update && apk fix ; then
        error_msg "Failed to update repos - network issue?" 1
    fi
    echo
}


task_upgrade() {
    msg_2 "upgrade installed apks"
    if [ "$SPD_TASK_DISPLAY" = "1" ]; then
        msg_3 "Will happen"
    else
        apk upgrade ||  error_msg "Failed to upgrade apks - network issue?" 1
    fi
    echo
}


task_remove_software() {
    msg_txt="Removing unwanted software"
    
    if [ "$SPD_APKS_DEL" != "" ]; then
        msg_2 "$msg_txt"
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            echo "$SPD_APKS_DEL"
        else
            echo "$SPD_APKS_DEL"
            # TODO: fix
            # argh due to shellcheck complaining that
            #   apk del $SPD_APKS_DEL
            # should instead be:
            #   apk del "$SPD_APKS_DEL"
            # and that leads to apk not recognizing it as multiple apks
            # this seems to be a useable workarround
            #
            cmd="apk del $SPD_APKS_DEL"
            $cmd
        fi
        echo
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "$msg_txt"
        echo "Will NOT remove any listed software"
        echo
    fi
}


task_install_my_software() {
    msg_txt="Installing my selection of software"
    if [ "$SPD_APKS_ADD" != "" ]; then
        msg_2 "$msg_txt"
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            echo "$SPD_APKS_ADD"
        else
            # TODO: see in task_remove_software() for description
            # about why this seems needed ATM
            echo "$SPD_APKS_ADD"
            cmd="apk add $SPD_APKS_ADD"
            $cmd || error_msg "Failed to install requested software - network issue?" 1
        fi
        echo
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "$msg_txt"
        echo "Will NOT install any listed software"
        echo
    fi
}



#==========================================================
#
#   Internals
#
#==========================================================

_run_this() {
    task_update
    [ "$SPD_APKS_DEL" != "" ] && task_remove_software
    task_upgrade
    [ "$SPD_APKS_ADD" != "" ] && task_install_my_software
    echo "Task Completed."
}


_display_help() {
    echo "m_tasks_apk.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Tasks included:"
    echo " task_update              - updates repository"
    echo " task_upgrade             - upgrades all installed apks"
    echo " task_remove_software     -  deletes all apks listed in SPD_APKS_DEL"
    echo " task_install_my_software - adds all apks listed in SPD_APKS_ADD"
    echo
    echo "Env paramas"
    echo "-----------"
    echo "SPD_APKS_DEL$(test -z "$SPD_APKS_DEL" && echo ' - packages to remove, comma separated' || echo =$SPD_APKS_DEL )"
    echo "SPD_APKS_ADD$(test -z "$SPD_APKS_ADD" && echo ' - packages to add, comma separated' || echo =$SPD_APKS_ADD )"
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
