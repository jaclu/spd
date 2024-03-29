#!/bin/sh
# shellcheck disable=SC2154
#
# Copyright (c) 2021,2022: Jacob.Lundqvist@gmail.com 2022-01-26
# License: MIT
#
# Part of https://github.com/jaclu/spd
#

#=====================================================================
#
#  All task scripts must define the following two variables:
#  script_tasks:
#    List tasks provided by this script. If multiple one per line single
#    multi-line string first word is task name, rest is optional
#    description of task
#  script_description
#    Short summary what this script does (for the help display)
#    Single multi line string.
#
#=====================================================================

# shellcheck disable=SC2034
script_tasks='task_dcron'
script_description="Activates or Disables a cron service, defined by SPD_DCRON"

#=====================================================================
#
#   Describe additional parameters, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_parameters() {
    echo "SPD_DCRON$(
        test -z "$SPD_DCRON" &&
            echo '              -  cron status (-1/0/1)' ||
            echo "=$SPD_DCRON"
    )"
    echo "SPD_DCRON_ROOT_CRONTAB$(
        test -z "$SPD_DCRON_ROOT_CRONTAB" &&
            echo ' -  root crontab file to use, if not given will not be used.' ||
            echo "=$SPD_DCRON_ROOT_CRONTAB"
    )"
}

#=====================================================================
#
#  Task (public) functions
#
#  Assumed to start with task_ and then describe the task in a sufficiently
#  unique way to give an idea of what this task does,
#  and not collide with other modules.
#  Use a short prefix unique for your module.
#
#=====================================================================

task_dcron() {
    verbose_msg "task_dcron($SPD_DCRON)"
    check_abort

    #
    # source dependencies if not available
    #
    if ! command -v 'ensure_service_is_added' 2>/dev/null | grep -q 'function'; then
        verbose_msg "task_dcron() needs to source openrc to satisfy dependencies"
        # shellcheck disable=SC1091
        . "$DEPLOY_PATH/scripts/tools/openrc.sh"
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

    -1) # disable
        _dcron_label
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_3 "Will be disabled"
        else
            check_abort
            msg_3 "Disabling service"
            [ -z "$(command -v openrc)" ] && ensure_installed openrc
            service_installed="$(rc-service -l | grep $service_name)"
            if [ "$service_installed" != "" ]; then
                disable_service $service_name default
                msg_3 "was disabled"
            else
                echo "Service $service_name was not active, no action needed"
            fi
        fi
        echo
        ;;

    0) # unchanged
        if [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
            _dcron_label
            echo "Will NOT be changed"
        fi
        ;;

    1) # activate
        _dcron_label
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_3 "Will be enabled"
        else
            check_abort
            msg_3 "Enabling service"
            [ -z "$(command -v openrc)" ] && ensure_installed openrc
            [ -z "$(command -v $service_name)" ] && ensure_installed $service_name
            ensure_runlevel_default

            msg_3 "Activating service"
            ensure_service_is_added $service_name default restart
        fi
        _dcron_host_crontab
        ;;

    *)
        error_msg "task_dcron($SPD_DCRON) invalid option, must be one of -1, 0, 1"
        ;;

    esac
    echo

    unset service_name
    unset service_installed
}

#=====================================================================
#
#   Internal functions, start with _ and abbreviation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_dcron_label() {
    msg_2 "dcron service"
    echo "  Runs tasks at selected times"
}

_dcron_host_crontab() {
    msg_3 "root crontab"
    if [ "$SPD_DCRON_ROOT_CRONTAB" != "" ] && [ -f "$SPD_DCRON_ROOT_CRONTAB" ]; then
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
#   Run this script via extras/script_base.sh
#
#=====================================================================

if test -z "$DEPLOY_PATH"; then
    #  Run this in stand-alone mode

    DEPLOY_PATH=$(cd -- "$(dirname -- "$0")/.." && pwd)
    echo "DEPLOY_PATH=$DEPLOY_PATH  $0"

    # shellcheck disable=SC1091
    . "${DEPLOY_PATH}/scripts/tools/script_base.sh"
fi
