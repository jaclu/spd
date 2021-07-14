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
    _ts_expand_all_deploy_paths
    
    verbose_msg "task_sshd($SPD_SSHD_SERVICE)"

    #
    # source dependencies if not available
    #
    if ! command -V 'ensure_service_is_added' 2>/dev/null | grep -q 'function' ; then
        verbose_msg "task_sshd() needs to source openrc to satisfy dependencies"
        . "$DEPLOY_PATH/scripts/extras/openrc.sh"
    fi

    #
    # Name of service
    #
    service_name=sshd

    if [ -z "$SPD_SSHD_SERVICE" ]; then
        SPD_SSHD_SERVICE="0"
        warning_msg "SPD_SSHD_SERVICE not defined, service sshd will not be modified"
    fi
    
    case "$SPD_SSHD_SERVICE" in

        "-1" ) # disable
            _ts_task_label
            if [ "$SPD_TASK_DISPLAY" = "1" ]; then
	           msg_3 "Will be disabled"
            else
                check_abort
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
            if [ "$SPD_TASK_DISPLAY" = "1" ] && \
               [ "$SPD_DISPLAY_NON_TASKS" = "1" ]
            then
                _ts_task_label
                echo "Will NOT be changed"
                echo
            fi
            ;;
        
        "1" )  # activate 
            _ts_task_label
            [ "$SPD_SSHD_PORT" = "" ] && error_msg "Invalid setting: SPD_SSHD_PORT must be specified"

            if [ "$SPD_TASK_DISPLAY" = "1" ]; then
                msg_3 "Will be enabled"
                echo "port: $SPD_SSHD_PORT"
                echo
            else
                msg_3 "Enabeling service"
                check_abort
                ensure_runlevel_default
                ensure_installed openssh
                #
                #  Preparational steps
                #
                _ts_unpack_ssh_host_keys

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
            error_msg "Invalid setting: SPD_SSHD_SERVICE=$SPD_SSHD_SERVICE\nValid options: -1 0 1"

    esac

    unset service_name
    unset service_installed
}



#=====================================================================
#
#   Internals, start with _ to make it obvious they should not be
#   called by other modules.
#
#=====================================================================

_ts_expand_all_deploy_paths() {
    #
    # Expanding path variables that are either absolute or relative
    # related to the deploy-path
    #

    SPD_SSH_HOST_KEYS=$(expand_deploy_path "$SPD_SSH_HOST_KEYS")
}


_ts_task_label() {
    msg_2 "sshd service"
}


_ts_unpack_ssh_host_keys() {
    msg_3 "Device specific ssh host keys"

    if [ "$SPD_SSH_HOST_KEYS" != "" ]; then
        echo "$SPD_SSH_HOST_KEYS"
        if test -f "$SPD_SSH_HOST_KEYS" ; then
            msg_3 "Will be untared into /etc/ssh"
            if [ "$SPD_TASK_DISPLAY" != "1" ]; then
                cd /etc/ssh || error_msg "Failed to cd into /etc/ssh"
                # remove any previous host keys
                2> /dev/null rm /etc/ssh/ssh_host_*

                2> /dev/null tar xfz "$SPD_SSH_HOST_KEYS" || error_msg "Untar failed!"
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
}


_display_help() {
    _ts_expand_all_deploy_paths

    echo "task_sshd.sh [-v] [-c] [-h]"
    echo "  -h  - Displays help about this task."
    echo "  -c  - reads config files for params"
    echo "  -x  - Run this task, otherwise just display what would be done"
    echo "  -v  - verbose, display more progress info"
    echo
    echo "Tasks included:"
    echo " task_sshd"
    echo
    echo "Activates or Disables sshd."
    echo 
    echo "Env paramas"
    echo "-----------"
    echo "SPD_SSHD_SERVICE$(
        test -z "$SPD_SSHD_SERVICE" \
        && echo '  - sshd status (-1/0/1)' \
        || echo "=$SPD_SSHD_SERVICE")"
    echo "SPD_SSHD_PORT$(
        test -z "$SPD_SSHD_PORT" \
        && echo '     - what port sshd should use' \
        || echo "=$SPD_SSHD_PORT")"
    echo "SPD_SSH_HOST_KEYS$(
        test -z "$SPD_SSH_HOST_KEYS" \
        && echo ' - tgz file with host_keys' \
        || echo "=$SPD_SSH_HOST_KEYS")"
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
