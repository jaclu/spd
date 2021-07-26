#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-07-25
# License: MIT
#
# Part of https://github.com/jaclu/spd
#

#=====================================================================
#
#  All task scripts must define the following two variables:
#  script_tasks:
#    List tasks provided by this script. If multilple one per line single
#    multi-line string first word is task name, rest is optional
#    description of task
#  script_description
#    Short summary what this script does (for the help display)
#    Single multiline string.
#
#=====================================================================

script_tasks='task_timezone'
script_description="Sets time-zone baesed on SPD_TIME_ZONE
Content should be in tz database format, so typically Continent/Major_City
or a two/three letter acronymn like EST.
If undefined/empty timezone will not be altered.
If time_zone is not recgonized this will abort with an error."



#=====================================================================
#
#   Describe additional paramas, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_paramas() {
    echo "SPD_TIME_ZONE$(test -z "$SPD_TIME_ZONE" && echo ' - set time-zone' || echo "=$SPD_TIME_ZONE" )"
}



#==========================================================
#
#  Task (public) functions
#
#  Assumed to start with task_ and then describe the task in a suficiently
#  unique way to give an idea of what this task does,
#  and not collide with other modules.
#  Use a short prefix unique for your module.
#
#==========================================================

task_timezone() { 
    tz_file=/usr/share/zoneinfo/$SPD_TIME_ZONE
    
    msg_txt="Setting timezone"
    if [ "$SPD_TIME_ZONE" != "" ]; then
        msg_2 "$msg_txt"
        echo "$SPD_TIME_ZONE"
        if [ ! "$SPD_TASK_DISPLAY" = "1" ]; then
            check_abort
            ensure_installed tzdata
            if [ "$tz_file" != "" ] && test -f "$tz_file" ; then
                cp "$tz_file" /etc/localtime
                # remove obsolete file
                2> /dev/null rm /etc/timezone
                msg_3 "displaying time"
                date
            else
                error_msg "BAD TIMEZONE: $SPD_TIME_ZONE" 1
            fi
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "$msg_txt"
        echo "Timezone ill NOT be changed"
    fi
    echo

    unset tz_file
    unset msg_txt
}



#=====================================================================
#
#   Run this script via extras/script_base.sh
#
#=====================================================================

[ -z "$SPD_INITIAL_SCRIPT" ] && . extras/script_base.sh
