#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-04-30
# License: MIT
#
# 0.1.0 2021-07-05
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

task_dcron() { 
    verbose_msg "task_dcron($SPD_DCRON)"
    check_abort
    
    #
    # source dependencies if not available
    #
    if ! command -V 'ensure_service_is_added' 2>/dev/null | grep -q 'function' ; then
        verbose_msg "task_dcron() needs to source openrc to satisfy dependencies"
        . "$DEPLOY_PATH/scripts/extras/openrc.sh"
    fi

    #
    # Name of service
    #
    service_name=dcron
            
    if [ "$SPD_DCRON" = "" ]; then
        SPD_DCRON="0"
        warning_msg "SPD_DCRON not defined, service dcron will not be modified"
    fi

    case "$SPD_DCRON" in
        -1 ) # disable
            _dcron_label
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
    
        0 )  # unchanged
            if [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
                _dcron_label
                echo "Will NOT be changed"
            fi
            ;;
    
        1 )  # activate 
            _dcron_label
            if [ "$SPD_TASK_DISPLAY" = "1" ]; then
                msg_3 "Will be enabled"
            else
                msg_3 "Enabeling service"
                check_abort
                ensure_runlevel_default
                ensure_installed $service_name

                msg_3 "Activating service"
                ensure_service_is_added $service_name default restart
            fi
	    _dcron_host_crontab
            ;;

       *) error_msg "task_dcron($SPD_DCRON) invalid option, must be one of -1, 0, 1"
    esac
    echo

    unset service_name
    unset service_installed
}



#=====================================================================
#
#   Internals, start with _ to make it obvious they should not be
#   called by other modules.
#
#=====================================================================

_dcron_label() {
    msg_2 "dcron service"
    echo "  Enabeling tasks to be done at selected times"
}


_dcron_host_crontab() {
    msg_3 "root crontab"
    if [ "$SPD_DCRON_ROOT_CRONTAB" != "" ] &&  [ -f "$SPD_DCRON_ROOT_CRONTAB" ]; then
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
	    echo "Will use: $SPD_DCRON_ROOT_CRONTAB"
	else
	    echo "Using: $SPD_DCRON_ROOT_CRONTAB"
            crontab "$SPD_DCRON_ROOT_CRONTAB"
	fi
    else
        echo "Not setting any root crontab"
    fi
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
    task_dcron
    #
    # Always display this final message  in standalone,
    # to indicate process terminated successfully.
    # And did not die in the middle of things...
    #
    echo "Task Completed."
}


_display_help() {
    echo "task_dcron.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Activates or Disables a cron service, defined by SPD_DCRON"
    echo
    echo "Tasks included:"
    echo " task_dcron"
    echo
    echo "Env paramas"
    echo "-----------"
    echo "SPD_DCRON$(
        test -z "$SPD_DCRON" \
        && echo '              -  cron status (-1/0/1)' \
        || echo "=$SPD_DCRON")"
    echo "SPD_DCRON_ROOT_CRONTAB$(
        test -z "$SPD_DCRON_ROOT_CRONTAB" \
        && echo ' -  root crontab file to use, if not given will not be used.' \
        || echo "=$SPD_DCRON_ROOT_CRONTAB")"
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
