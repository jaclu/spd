#!/bin/sh
# shellcheck disable=SC2154
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
#    List tasks provided by this script. If multiple one per line single
#    multi-line string first word is task name, rest is optional
#    description of task
#  script_description
#    Short summary what this script does (for the help display)
#    Single multi line string.
#
#=====================================================================

# shellcheck disable=SC2034
script_tasks="task_runbg"
script_description="Installs and Activates or Disables a service that monitors the iOS
location this ensures that iSH will continue to run in the background."

#=====================================================================
#
#   Describe additional parameters, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_parameters() {
    echo "SPD_RUN_BG$(
        test -z "$SPD_RUN_BG" &&
            echo ' -  location_tacker status (-1/0/1)' ||
            echo "=$SPD_RUN_BG"
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

task_runbg() {
    verbose_msg "task_runbg($SPD_RUN_BG)"
    check_abort

    #  Defaults to no action
    [ -z "$SPD_RUN_BG" ] && SPD_RUN_BG=0

    #
    # Name of service
    #
    service_name=runbg
    service_fname="/etc/init.d/$service_name"
    source_fname="$DEPLOY_PATH/files/services/$service_name"

    #
    # source dependencies if not available
    #
    if ! command -v 'ensure_service_is_added' 2>/dev/null | grep -q 'function'; then
        verbose_msg "task_runbg() needs to source openrc to satisfy dependencies"
        # shellcheck disable=SC1091
        . "$DEPLOY_PATH/scripts/tools/openrc.sh"
    fi

    #
    #  If param not set, ensure nothing will be changed
    #
    if [ "$SPD_RUN_BG" = "" ]; then
        SPD_RUN_BG="0"
        warning_msg "SPD_RUN_BG not defined, service runbg will not be modified"
    fi

    case "$SPD_RUN_BG" in

    -1) # disable
        _runbg_label
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_3 "Will be disabled"
        else
            check_abort
            msg_3 "Disabling service"
            [ -z "$(command -v openrc)" ] && ensure_installed openrc
            service_installed="$(rc-service -l | grep $service_name)"
            if [ "$service_installed" != "" ]; then
                disable_service $service_name default
                echo "now disabled"
            else
                echo "Service $service_name was not active, no action needed"
            fi
            rm $service_fname -f
        fi
        echo
        ;;

    0) # unchanged
        if [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
            _runbg_label
            echo "Will NOT be changed"
        fi
        ;;

    1) # activate
        _runbg_label
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_3 "Will be enabled"
        else
            check_abort
            msg_3 "Enabling service"
            [ -z "$(command -v openrc)" ] && ensure_installed openrc
            ensure_runlevel_default

            #diff "$source_fname" "$service_fname" > /dev/null 2>&1
            #if [ $? -ne 0 ]; then

            #
            #  Ensure that the latest service is deployed
            #
            msg_3 "Deploying service file"
            cp "$source_fname" "$service_fname"
            chmod 755 "$service_fname"

            msg_3 "Activating service"
            ensure_service_is_added $service_name default restart
        fi
        ;;

    *)
        error_msg "task_runbg($SPD_RUN_BG) invalid option, must be one of -1, 0, 1"
        ;;
    esac
    echo

    unset service_name
    unset service_fname
    unset source_fname
    unset service_installed
}

#=====================================================================
#
#   Internal functions, start with _ and abbreviation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_runbg_label() {
    msg_2 "runbg service"
    echo "  Ensuring iSH continues to run in the background."
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
