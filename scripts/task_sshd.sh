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



#=====================================================================
#
#   Public functions
#
#=====================================================================

#
#  Assumed to start with task_ and then describe the task in a suficiently
#  unique way to give an idea of what this task does,
#  and not collide with other modules.
#  Use a short prefix unique for your module.
#

task_sshd() {
    _expand_all_sshd_deploy_paths
    
    verbose_msg "task_sshd($SPD_SSHD_SERVICE)"
    #
    # Name of service
    #
    service_name=sshd
    service_fname="/etc/init.d/$service_name"

    if [ -z "$SPD_SSHD_SERVICE" ]; then
        SPD_SSHD_SERVICE="0"
        warning_msg "SPD_SSHD_SERVICE not defined, service sshd will not be modified"
   fi
    
    case "$SPD_SSHD_SERVICE" in
	"-1" | "0" | "1")
	    ;;
	*)
	    error_msg "task_sshd($SPD_SSHD_SERVICE) invalid option, must be one of -1, 0, 1" 1
	    ;;
    esac
        
    case "$SPD_SSHD_SERVICE" in
        "-1" ) # disable
	    _sshd_label
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
            fi
	    echo
            ;;
            
        "0" )  # unchanged
            if [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ $SPD_DISPLAY_NON_TASKS = "1" ]; then
		_sshd_label
                echo "Will NOT be changed"
		echo
            fi
            ;;
        
        "1" )  # activate 
	    _sshd_label
            if [ "$SPD_SSHD_PORT" = "" ]; then
                error_msg "Invalid setting: SPD_SSHD_PORT must be specified" 1
            fi
	    if [ "$SPD_TASK_DISPLAY" = "1" ]; then
                msg_3 "Will be enabled"
                echo "port: $SPD_SSHD_PORT"
		echo
 	    else
                msg_3 "Enabeling service"
		
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
        
                #
		# use requested port
		#
                sed -i "s/.*Port .*/Port $SPD_SSHD_PORT/" /etc/ssh/sshd_config
		
                ensure_service_is_added sshd default restart
                msg_1 "sshd listening on port: $SPD_SSHD_PORT"
            fi
            ;;

        *)
            error_msg "Invalid setting: SPD_SSHD_SERVICE=$SPD_SSHD_SERVICE\nValid options: -1 0 1" 1
    esac
}



#=====================================================================
#
#   Internals, start with _ to make it obvious they should not be
#   called by other modules.
#
#=====================================================================

_expand_all_sshd_deploy_paths() {
    #
    # Expanding path variables that are either absolute or relative
    # related to the deploy-path
    #

    SPD_SSH_HOST_KEYS=$(expand_deploy_path "$SPD_SSH_HOST_KEYS")
}


_sshd_label() {
    msg_2 "sshd service"
}


_unpack_ssh_host_keys() {
    msg_3 "Device specific ssh host keys"

    if [ "$SPD_SSH_HOST_KEYS" != "" ]; then
        echo "$SPD_SSH_HOST_KEYS"
        if test -f "$SPD_SSH_HOST_KEYS" ; then
            msg_3 "Will be untared into /etc/ssh"
            if [ "$SPD_TASK_DISPLAY" != "1" ]; then
                cd /etc/ssh || error_msg "Failed to cd into /etc/ssh" 1
		          # remove any previous host keys
                2> /dev/null rm /etc/ssh/ssh_host_*
		
                if [ "$(tar xvfz "$SPD_SSH_HOST_KEYS")" != "0" ]; then
                    error_msg "Untar failed!" 1
                fi
            fi
        else
            msg_3 "Not found"
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        echo "Will NOT be used"
    fi
    echo
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
    task_sshd
    #
    # Always display this final message  in standalone,
    # to indicate process terminated successfully.
    # And did not die in the middle of things...
    #
    echo "Task Completed."
}


_display_help() {
    _expand_all_sshd_deploy_paths
    echo "task_sshd.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Activates or Disables sshd."
    echo 
    echo "Env paramas"
    echo "-----------"
    echo "SPD_SSHD_SERVICE$(test -z "$SPD_SSHD_SERVICE" && echo '  - sshd status (-1/0/1)' || echo "=$SPD_SSHD_SERVICE")"
    echo "SPD_SSHD_PORT$(test -z "$SPD_SSHD_PORT" && echo '     - what port sshd should use' || echo "=$SPD_SSHD_PORT")"
    echo "SPD_SSH_HOST_KEYS$(test -z "$SPD_SSH_HOST_KEYS" && echo ' - tgz file with host_keys' || echo "=$SPD_SSH_HOST_KEYS")"
    echo
    echo "SPD_TASK_DISPLAY$(test -z "$SPD_TASK_DISPLAY" && echo '      - if 1 will only display what will be done' || echo "=$SPD_TASK_DISPLAY")"
    echo "SPD_DISPLAY_NON_TASKS$(test -z "$SPD_DISPLAY_NON_TASKS" && echo ' - if 1 will show what will NOT happen' || echo "=$SPD_DISPLAY_NON_TASKS")"
}



#==========================================================
#
#     main
#
#=====================================================================

if [ "$SPD_INITIAL_SCRIPT" = "" ]; then

    echo ">> before utils"
    . "$DEPLOY_PATH/scripts/extras/utils.sh"
    echo ">> after utils"

    #
    # Since sourced mode cant be detected in a practical way under ash,
    # I use this workaround, first script is expected to set it, if set
    # all other modules can assume to be sourced
    #
    SPD_INITIAL_SCRIPT=1
fi
