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



#==========================================================
#
#   Public functions
#
#==========================================================

task_sshd() {
    if [ "$1" != "" ]; then
        SPD_SSHD_SERVICE="$1"
    elif [ "$SPD_SSHD_SERVICE" = "" ]; then
        SPD_SSHD_SERVICE="0"
        error_msg "SPD_SSHD_SERVICE not defined, asuming no action"
    fi
    msg_txt="sshd service"
    case "$SPD_SSHD_SERVICE" in
        "-1" ) # disable
            msg_2 "$msg_txt"
            msg_3 "will be disabled"
            if [ ! "$SPD_TASK_DISPLAY" = "1" ]; then                        
                if [ "$(2> /dev/null rc-status |grep sshd)" != "" ]; then
                    rc-service sshd stop
                    rc-update del sshd
                    msg_3 "was disabled"
                else
                    echo "sshd not active, no action needed"
                fi
            fi
            echo
            ;;
            
        "0" )  # unchanged
            if [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ $SPD_DISPLAY_NON_TASKS = "1" ]; then
                msg_2 "$msg_txt"
                echo "Will NOT be changed"
            fi
            ;;
        
        "1" )  # activate 
            msg_txt_2=$msg_txt
            _unpack_ssh_host_keys
            msg_2 "$msg_txt_2"
            if [ "$SPD_SSHD_PORT" = "" ]; then
                error_msg "Invalid setting: SPD_SSHD_PORT must be specified" 1
            fi
            # This will be run regardless if it was already running,
            # since the sshd_config might have changed
            if [ "$SPD_TASK_DISPLAY" = "1" ]; then
                msg_3 "Will be enabled"
                echo "port: $SPD_SSHD_PORT"
                echo
            else
                msg_3 "Ensuring hostkeys exist"
                ssh-keygen -A
                echo "hostkeys ready"
                echo
                ensure_runlevel_default
                ensure_installed openssh
                # use requested port
                sed -i "s/.*Port.*/Port $SPD_SSHD_PORT/" /etc/ssh/sshd_config
                ensure_service_is_added sshd restart
                # in case some config changes happened, make sure sshd is restarted
                #rc-service sshd restart
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
    #
    #  Even if you don't intend to activate sshd initially
    #  it still makes senc to deploy any saved ssh host keys
    #  A) they are there if you need them
    #  B) you dont have to wait for host keys to be generated
    #     when and if you want to run sshd
    #
    msg_txt="Device specific ssh host keys"

    if [ "$SPD_SSH_HOST_KEYS" != "" ]; then
        msg_2 "$msg_txt"
        if test -f "$SPD_SSH_HOST_KEYS" ; then
            msg_3 "Will be untared into /etc/ssh"
            echo "$SPD_SSH_HOST_KEYS"
            if [ "$SPD_TASK_DISPLAY" != "1" ]; then
                ensure_installed openssh-client
                cd /etc/ssh || error_msg "Failed to cd into /etc/ssh" 1
                2>/dev/null rm /etc/ssh/ssh_host_*
                tar xvfz "$SPD_SSH_HOST_KEYS"
            fi
        else
            msg_3 "Not found"
            echo "$SPD_SSH_HOST_KEYS"
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "$msg_txt"
        echo "Will NOT be used"
    fi
    echo
}


_run_this() {
    task_sshd
    echo "Task Completed."
}


_display_help() {
   echo "task_sshd.sh [cfg] [-h|-1|0|1]"
   echo "  cfg - reads config file for params"
   echo "  If given service status should be one of"
   echo "    -1 - disable"
   echo "     0 - ignore/nochange"
   echo "     1 - enable"
   echo
   echo "Activates or Disables sshd, status defined by"
   echo "SPD_SSHD_SERVICE or command line param."
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
