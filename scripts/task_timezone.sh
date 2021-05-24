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

task_timezone() { 
    tz_file=/usr/share/zoneinfo/$SPD_TIME_ZONE
    
    msg_txt="Setting timezone"
    if [ "$SPD_TIME_ZONE" != "" ]; then
        msg_2 "$msg_txt"
        echo "$SPD_TIME_ZONE"
        if [ ! "$SPD_TASK_DISPLAY" = "1" ]; then
            ensure_installed tzdata
            if [ "$tz_file" != "" ] && test -f $tz_file ; then
                cp "$tz_file" /etc/localtime
                # remove obsolete file
                2> /dev/null rm /etc/timezone
                msg_3 "displaying time"
                date
            else
                error_msg "BAD TIMEZONE: $SPD_TIME_ZONE" 1
            fi
        fi
        echo
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ $SPD_DISPLAY_NON_TASKS = "1" ]; then
        msg_2 "$msg_txt"
        echo "Timezone ill NOT be changed"
        echo
    fi
}



#==========================================================
#
#   Internals
#
#==========================================================

_run_this() {
    task_timezone
    echo "Task Completed."
}

_display_help() {
    echo "task_timezone.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Sets time-zone baesed on SPD_TIME_ZONE"
    echo "Content should be in tz database format, so typically Continent/Major_City"
    echo "or a two/three letter acronymn like UTC."
    echo "If undefined/empty timezone will not be altered."
    echo "If time_zone is not recgonized this will abort with an error."
    echo
    echo "Env paramas"
    echo "-----------"
    echo "SPD_TIME_ZONE$(test -z "$SPD_TIME_ZONE" && echo ' - set time-zone' || echo =$SPD_TIME_ZONE )"
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
