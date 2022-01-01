#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 
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

# shellcheck disable=SC2034
script_tasks="task_mon_sshd"
script_description="Monitors and restarts sshd if no longer responsive"



#=====================================================================
#
#   Describe additional paramas, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_paramas() {
    echo "SPD_MON_SSHD$(
        test -z "$SPD_MON_SSHD" \
        && echo ' -  service enabled status (-1/0/1)' \
        || echo "=$SPD_MON_SSHD")"
}



#=====================================================================
#
#  Task (public) functions
#
#  Assumed to start with task_ and then describe the task in a suficiently
#  unique way to give an idea of what this task does,
#  and not collide with other modules.
#  Use a short prefix unique for your module.
#
#=====================================================================

task_mon_sshd() { 
    verbose_msg "task_mon_sshd($SPD_MON_SSHD)"
    check_abort
    
    #
    # Name of service
    #
    service_name=mon_sshd
    service_fname="/etc/init.d/$service_name"
    source_fname="$DEPLOY_PATH/files/services/$service_name"
    service_bin="$DEPLOY_PATH/files/extra_bins/sshd_monitor"
    #
    # source dependencies if not available
    #
    if ! command -V 'ensure_service_is_added' 2>/dev/null | grep -q 'function' ; then
        verbose_msg "task_mon_sshd() needs to source openrc to satisfy dependencies"
        # shellcheck disable=SC1091
        . "$DEPLOY_PATH/scripts/extras/openrc.sh"
    fi

    #
    #  If param not set, ensure nothing will be changed
    #
    if [ "$SPD_MON_SSHD" = "" ]; then
        SPD_MON_SSHD="0"
        warning_msg "SPD_MON_SSHD not defined, service mon_sshd will not be modified"
    fi

    case "$SPD_MON_SSHD" in

        -1 ) # disable
            _mon_sshd_label
            if [ "$SPD_TASK_DISPLAY" = "1" ]; then
               msg_3 "Will be disabled"
            else
                check_abort
                msg_3 "Disabling service"
                ensure_installed openrc  # needed to handle services
                service_installed="$(rc-service -l |grep $service_name )"
                if [ "$service_installed"  != "" ]; then
                    disable_service $service_name default
                    echo "now disabled"
                else
                    echo "Service $service_name was not active, no action needed"
                fi
                rm $service_fname -f
            fi
            echo
            ;;
    
        0 )  # unchanged
            if [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
                _mon_sshd_label
                echo "Will NOT be changed"
            fi
            ;;
    
        1 )  # activate 
            _mon_sshd_label
            if [ "$SPD_TASK_DISPLAY" = "1" ]; then
                msg_3 "Will be enabled"
            else
                check_abort
                msg_3 "Enabeling service"
                ensure_installed openrc  # needed to handle services
                ensure_installed procps  # needed for pgrep
                ensure_runlevel_default

                #diff "$source_fname" "$service_fname" > /dev/null 2>&1
                #if [ $? -ne 0 ]; then

                #
                #  Ensure that the latest service is deployed
                #
                msg_3 "Deploying sshd_monitor"
                cp "$service_bin" /usr/local/bin
                msg_3 "Deploying service file"
                cp "$source_fname" "$service_fname"
                chmod 755 "$service_fname"

                msg_3 "Activating service"
                ensure_service_is_added $service_name default restart
            fi
            ;;

        *)
            error_msg "task_mon_sshd($SPD_MON_SSHD) invalid option, must be one of -1, 0, 1"
    esac
    echo

    unset service_name
    unset service_fname
    unset source_fname
    unset service_installed
}



#=====================================================================
#
#   Internal functions, start with _ and abrevation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_mon_sshd_label() {
    msg_2 "mon_sshd service"
    echo "  Ensuring sshd is responsive, restarts it if not."
}



#=====================================================================
#
#   Run this script via extras/script_base.sh
#
#=====================================================================

script_dir="$(dirname "$0")"

# shellcheck disable=SC1091
[ -z "$SPD_INITIAL_SCRIPT" ] && . "${script_dir}/extras/script_base.sh"

unset script_dir
