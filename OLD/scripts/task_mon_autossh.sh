#!/bin/sh
# shellcheck disable=SC2154
#
# Copyright (c) 2023,2022: Jacob.Lundqvist@gmail.com
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
script_tasks="task_mon_autossh"
script_description="Monitors and restarts autossh if no longer responsive"

#=====================================================================
#
#   Describe additional parameters, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_parameters() {
    echo "SPD_MON_AUTOSSH$(
        test -z "$SPD_MON_AUTOSSH" &&
            echo ' -  service enabled status (-1/0/1)' ||
            echo "=$SPD_MON_AUTOSSH"
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

task_mon_autossh() {
    verbose_msg "task_mon_autossh($SPD_MON_SSHD)"
    check_abort

    #
    #  If param not set, ensure nothing will be changed
    #
    if [ -z "$SPD_MON_AUTOSSH" ]; then
        SPD_MON_AUTOSSH="0"
        warning_msg "SPD_MON_AUTOSSH not defined, service mon_autossh will not be modified"
        return
    fi

    #
    # Name of service
    #
    service_name=mon_autossh
    service_fname="/etc/init.d/$service_name"
    source_fname="$DEPLOY_PATH/files/services/$service_name"
    service_bin="$DEPLOY_PATH/files/extra_bins/autossh_monitor"
    #
    # source dependencies if not available
    #
    if ! command -v 'ensure_service_is_added' 2>/dev/null | grep -q 'function'; then
        verbose_msg "task_mon_autossh() needs to source openrc to satisfy dependencies"
        # shellcheck disable=SC1091
        . "$DEPLOY_PATH/scripts/tools/openrc.sh"
    fi

    case "$SPD_MON_AUTOSSH" in

    -1) # disable
        _mon_autossh_label
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_3 "Will be disabled"
        else
            check_abort
            msg_3 "Disabling service"
            [ -z "$(command -v openrc)" ] && ensure_installed openrc # needed to handle services
            service_installed="$(rc-service -l | grep $service_name)"
            if [ -n "$service_installed" ]; then
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
            _mon_autossh_label
            echo "Will NOT be changed"
        fi
        ;;

    1) # activate
        _mon_autossh_label
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_3 "Will be enabled"
        else
            check_abort
            msg_3 "Enabling service"
            [ -z "$(command -v openrc)" ] && ensure_installed openrc # needed to handle services
            ensure_runlevel_default

            #diff "$source_fname" "$service_fname" > /dev/null 2>&1
            #if [ $? -ne 0 ]; then

            #
            #  Ensure that the latest service is deployed
            #
            msg_3 "Deploying autossh_monitor"
            cp "$service_bin" /usr/local/sbin
            msg_3 "Deploying service file"
            cp "$source_fname" "$service_fname"
            chmod 755 "$service_fname"

            msg_3 "Activating service"
            ensure_service_is_added $service_name default restart
        fi
        ;;

    *)
        error_msg "task_mon_autossh($SPD_MON_AUTOSSH) invalid option, must be one of -1, 0, 1"
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

_mon_autossh_label() {
    msg_2 "mon_autossh service"
    echo "  Ensuring autossh is responsive, restarts it if not."
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
