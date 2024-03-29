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
#    Single mulsti line string.
#
#=====================================================================

# shellcheck disable=SC2034
script_tasks='task_sshd'
script_description="Activates or Disables sshd."

#=====================================================================
#
#   Describe additional parameters, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_parameters() {
    echo "SPD_SSHD_SERVICE$(
        test -z "$SPD_SSHD_SERVICE" &&
            echo '  - sshd status (-1/0/1)' ||
            echo "=$SPD_SSHD_SERVICE"
    )"
    echo "SPD_SSHD_PORT$(
        test -z "$SPD_SSHD_PORT" &&
            echo '     - what port sshd should use' ||
            echo "=$SPD_SSHD_PORT"
    )"
    echo "SPD_SSH_HOST_KEYS$(
        test -z "$SPD_SSH_HOST_KEYS" &&
            echo ' - tgz file with host_keys' ||
            echo "=$SPD_SSH_HOST_KEYS"
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

task_sshd() {
    msg_2 "task_sshd()"
    # if [ -z "$SPD_SSHD_PORT" ]; then
    #     msg_2 "task_sshd: No port set, aborting"
    #     return
    # fi

    [ -z "$SPD_SSHD_SERVICE_NAME" ] && SPD_SSHD_SERVICE_NAME="sshd"

    _ts_expand_all_deploy_paths

    verbose_msg "task_sshd($SPD_SSHD_SERVICE)"

    #
    # Name of service
    #
    if is_debian; then
        service_name=ssh
    else
        service_name=sshd
    fi

    #
    # source dependencies if not available
    #
    if ! command -v 'ensure_service_is_added' 2>/dev/null | grep -q 'function'; then
        verbose_msg "task_sshd() needs to source openrc to satisfy dependencies"
        # shellcheck disable=SC1091
        . "$DEPLOY_PATH/scripts/tools/openrc.sh"
    fi

    #
    #  If param not set, ensure nothing will be changed
    #
    if [ -z "$SPD_SSHD_SERVICE" ]; then
        SPD_SSHD_SERVICE="0"
        # warning_msg "SPD_SSHD_SERVICE not defined, service sshd will not be modified"
    fi

    case "$SPD_SSHD_SERVICE" in

    "-1") # disable
        _ts_task_label
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

    "0") # unchanged
        if [ "$SPD_TASK_DISPLAY" = "1" ] &&
            [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
            _ts_task_label
            echo "Will NOT be changed"
            echo
        fi
        ;;

    "1") # activate
        _ts_task_label
        [ "$SPD_SSHD_PORT" = "" ] && error_msg "Invalid setting: SPD_SSHD_PORT must be specified"

        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_3 "will be enabled"
            echo "port: $SPD_SSHD_PORT"
            echo
        else
            check_abort
            msg_3 "Enabling service"
            _ts_unpack_ssh_host_keys
            [ -z "$(command -v openrc)" ] && ensure_installed openrc
            [ -z "$(command -v sshd)" ] && ensure_installed openssh-server
            ensure_runlevel_default

            msg_3 "Ensuring hostkeys exist"
            ssh-keygen -A
            echo "hostkeys ready"
            echo

            #
            # use requested port
            #
            sed -i "s/.*Port .*/Port $SPD_SSHD_PORT/" /etc/ssh/sshd_config

            ensure_service_is_added $service_name default restart
            msg_1 "sshd listening on port: $SPD_SSHD_PORT"
        fi
        ;;

    *)
        error_msg "Invalid setting: SPD_SSHD_SERVICE=$SPD_SSHD_SERVICE\nValid options: -1 0 1"
        ;;

    esac

    unset service_name
    unset service_installed
}

#=====================================================================
#
#   Internal functions, start with _ and abbreviation of script name to make it
#   obvious they should not be called by other modules.
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
    msg="Device specific ssh host keys"
    if [ -z "$SPD_SSH_HOST_KEYS" ]; then
        if [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
            msg_3 "$msg"
            unset msg
            echo "Will NOT be used"
        fi
        return
    fi
    msg_3 "$msg"
    unset msg

    echo "$SPD_SSH_HOST_KEYS"
    if test -f "$SPD_SSH_HOST_KEYS"; then
        msg_3 "Will be untared into /etc/ssh"
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            cd /etc/ssh || error_msg "Failed to cd into /etc/ssh"
            # remove any previous host keys
            rm 2>/dev/null /etc/ssh/ssh_host_*
            tar 2>/dev/null xfz "$SPD_SSH_HOST_KEYS" || error_msg "Untar failed!"
        fi
    else
        msg_3 "Not found"
    fi

    echo
    # error_msg "Aborting after hostkey check" 1
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
