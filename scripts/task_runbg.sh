#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-04-30
# License: MIT
#
# Version: 0.2.0 2021-05-xx
#    Created a propper openrc daemn service (files/bgrun)
# 0.1.0 2021-04-30
#    Initial release
#
# Part of ishTools
#


if test -z "$DEPLOY_PATH" ; then
    # Most likely not sourced...
    DEPLOY_PATH="$(dirname "$0")/.."               # relative
    DEPLOY_PATH="$( cd "$DEPLOY_PATH" && pwd )"  # absolutized and normalized
fi
. "$DEPLOY_PATH/scripts/extras/openrc.sh"


#
# Name of service
#
service_name=runbg

source_fname="$DEPLOY_PATH/files/services/$service_name"
service_fname="/etc/init.d/$service_name"


#==========================================================
#
#   Public functions
#
#==========================================================

task_runbg() {
    if [ "$1" != "" ]; then
        SPD_BG_RUN="$1"
    elif [ "$SPD_BG_RUN" = "" ]; then
        SPD_BG_RUN="0"
        warning_msg "SPD_BG_RUN not defined, asuming no action"
    fi
    verbose_msg "task_runbg($SPD_BG_RUN)"

    case "$SPD_BG_RUN" in
	"-1" | "0" | "1")
	    ;;
	*)
	    error_msg "task_runbg($SPD_BG_RUN) invalid option, must be one of -1, 0, 1" 1
	    ;;
    esac
    
    case "$SPD_BG_RUN" in
        -1 ) # disable
	    task_label	
            if [ "$SPD_TASK_DISPLAY" = "1" ]; then
	        msg_3 "Will be disabled"
	    else
                service_installed="$(rc-service -l |grep $service_name )"
                if [ "$service_installed"  != "" ]; then		    
                    disable_service $service_name default
                    msg_3 "was disabled"
                else
                    echo "Service $service_name was not active, no action needed"
                fi
                rm $service_fname -f
            fi
            ;;
    
        0 )  # unchanged
            if [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
	        task_label
                echo "Will NOT be changed"
            fi
            ;;
    
        1 )  # activate 
	    task_label
            if [ "$SPD_TASK_DISPLAY" = "1" ]; then
                msg_3 "Will be enabled"
            else
                msg_3 "Enabeling service"
                ensure_installed openrc
                ensure_runlevel_default
		
		diff "$source_fname" "$service_fname" > /dev/null 2>&1
		if [ $? -ne 0 ]; then
		    #
		    #  Ensure that the latest service is deployed
		    #
		    msg_3 "Deploying service file"
		    cp "$source_fname" "$service_fname"
                    chmod 755 "$service_fname"
		fi
                msg_3 "Activating service"
                ensure_service_is_added $service_name default restart
            fi
            ;;

    esac
    echo
}



#==========================================================
#
#   Internals
#
#==========================================================

task_label() {
    msg_2 "runbg service"
    echo "  Ensuring iSH continues to run in the background."
}


_run_this() {
    task_runbg
    echo "Task Completed."
}


_display_help() {
    echo "task_runbg.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Installs and Activates or Disables a service that monitors the iOS location"
    echo "this ensures that iSH will continue to run in the background."
    echo "defined by SPD_BG_RUN or command line param."
    echo
    echo "Env paramas"
    echo "-----------"
    echo "SPD_BG_RUN$(test -z "$SPD_BG_RUN" && echo ' -  location_tacker status (-1/0/1)' || echo =$SPD_BG_RUN)"
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
