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
. "$DEPLOY_PATH/scripts/extras/openrc.sh"


#
# Name of service
#
service_name=sshd
service_fname="/etc/init.d/$service_name"



#==========================================================
#
#   Public functions
#
#==========================================================

task_sshd() {
    msg_2 "sshd service"
    
    if [ "$1" != "" ]; then
        SPD_SSHD_SERVICE="$1"
    elif [ "$SPD_SSHD_SERVICE" = "" ]; then
        SPD_SSHD_SERVICE="0"
        warning_msg "SPD_SSHD_SERVICE not defined, asuming no action"
    fi
    verbose_msg "task_sshd($SPD_SSHD_SERVICE)"
    
    case "$SPD_SSHD_SERVICE" in
	"-1" | "0" | "1")
	    ;;
	*)
	    error_msg "task_sshd($SPD_SSHD_SERVICE) invalid option, must be one of -1, 0, 1" 1
	    ;;
    esac
        
    case "$SPD_SSHD_SERVICE" in
        "-1" ) # disable
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
            echo
            ;;
            
        "0" )  # unchanged
            if [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ $SPD_DISPLAY_NON_TASKS = "1" ]; then
                echo "Will NOT be changed"
            fi
            ;;
        
        "1" )  # activate 
            if [ "$SPD_SSHD_PORT" = "" ]; then
                error_msg "Invalid setting: SPD_SSHD_PORT must be specified" 1
            fi
	    if [ "$SPD_TASK_DISPLAY" = "1" ]; then
                msg_3 "Will be enabled"
                echo "port: $SPD_SSHD_PORT"
 	    else
                ensure_installed openrc
		ensure_installed openssh
                ensure_runlevel_default

	    	#
	    	#  Preparational steps
	    	#
	    	_unpack_ssh_host_keys
	    
                msg_3 "Ensuring hostkeys exist"
                ssh-keygen -A
                echo "hostkeys ready"
                echo
        
                # use requested port
                sed -i "s/.*Port .*/Port $SPD_SSHD_PORT/" /etc/ssh/sshd_config
                ensure_service_is_added sshd default restart
                msg_1 "sshd listening on port: $SPD_SSHD_PORT"
            fi
            ;;

        *)
            error_msg "Invalid setting: SPD_SSHD_SERVICE=$SPD_SSHD_SERVICE\nValid options: -1 0 1" 1
    esac
}




#==========================================================
#
#   Internals
#
#==========================================================

_unpack_ssh_host_keys() {
    msg_3 "Device specific ssh host keys"

    if [ "$SPD_SSH_HOST_KEYS" != "" ]; then
       	echo "$SPD_SSH_HOST_KEYS"
        if test -f "$SPD_SSH_HOST_KEYS" ; then
            msg_3 "Will be untared into /etc/ssh"
            if [ "$SPD_TASK_DISPLAY" != "1" ]; then
                cd /etc/ssh || error_msg "Failed to cd into /etc/ssh" 1
		# remove any previous host keys
                2>/dev/null rm /etc/ssh/ssh_host_*
		
                tar xvfz "$SPD_SSH_HOST_KEYS"
		[ $? -ne 0 ] && error_msg "Untar failed!" 1
            fi
        else
            msg_3 "Not found"
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        echo "Will NOT be used"
    fi
    echo
}


_run_this() {
    echo ">> cmdline param: $1"
    task_sshd
    echo "Task Completed."
}


_display_help() {
    echo "task_sshd.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Activates or Disables sshd."
    echo 
    echo "Env paramas"
    echo "-----------"
    echo "SPD_SSHD_SERVICE$(test -z "$SPD_SSHD_SERVICE" && echo '  - sshd status (-1/0/1)' || echo =$SPD_SSHD_SERVICE )"
    echo "SPD_SSHD_PORT$(test -z "$SPD_SSHD_PORT" && echo '     - what port sshd should use' || echo =$SPD_SSHD_PORT )"
    echo "SPD_SSH_HOST_KEYS$(test -z "$SPD_SSH_HOST_KEYS" && echo ' - tgz file with host_keys' || echo =$SPD_SSH_HOST_KEYS )"
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
