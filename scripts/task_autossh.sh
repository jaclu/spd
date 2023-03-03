#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-07-26
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
script_tasks='task_autossh'
script_description="Sets up a reverse port forward so that a common host can
make a dial-back ssh connection."

#=====================================================================
#
#   Describe additional parameters, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_parameters() {
    echo "SPD_AUTOSSH_REVERSE_PORT$(test -z "$SPD_AUTOSSH_REVERSE_PORT" && echo ' - set to reverse port if wanted' || echo "=$SPD_AUTOSSH_REVERSE_PORT")"
}

#==========================================================
#
#  Task (public) functions
#
#  Assumed to start with task_ and then describe the task in a sufficiently
#  unique way to give an idea of what this task does,
#  and not collide with other modules.
#  Use a short prefix unique for your module.
#
#==========================================================

task_autossh() {

    #
    # source dependencies if not available
    #
    if ! command -v 'ensure_service_is_added' 2>/dev/null | grep -q 'function'; then
        verbose_msg "task_sshd() needs to source openrc to satisfy dependencies"
        # shellcheck disable=SC1091,SC2154
        . "$DEPLOY_PATH/scripts/tools/openrc.sh"
    fi

    service_fname="/etc/init.d/autossh"

    # unset SPD_AUTOSSH_REVERSE_PORT
    case "$SPD_AUTOSSH_REVERSE_PORT" in

    "" | "0")
        # Disable
        # shellcheck disable=SC2154
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_2 "autossh will be disabled"
        else
            check_abort
            msg_2 "Disabling autossh service"
            [ -z "$(command -v openrc)" ] && ensure_installed openrc
            service_installed="$(rc-service -l | grep autossh)"
            if [ "$service_installed" != "" ]; then
                disable_service autossh default
                rm "$service_fname"
                echo "now disabled"
            else
                echo "Service autossh was not active, no action needed"
            fi
        fi
        ;;

    *)
        # Enable
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_2 "autossh will be enabled"
            echo "reverse forward on $SPD_AUTOSSH_CONNECT ${SPD_AUTOSSH_REVERSE_PORT}:localhost:${SPD_SSHD_PORT}"
            echo
        else
            check_abort
            if [ -z "$SPD_AUTOSSH_CONNECT" ] || [ -z "$SPD_AUTOSSH_REVERSE_PORT" ] || [ -z "$SPD_SSHD_PORT" ]; then
                error_msg "SPD_AUTOSSH_CONNECT, SPD_AUTOSSH_REVERSE_PORT and SPD_SSHD_PORT must be defined!"
            fi
            msg_2 "Setting up autossh"
            [ -z "$(command -v openrc)" ] && ensure_installed openrc
            [ -z "$(command -v autossh)" ] && ensure_installed autossh
            ensure_runlevel_default
            msg_3 "Setting reverse port to $SPD_AUTOSSH_CONNECT $SPD_AUTOSSH_REVERSE_PORT:localhost:$SPD_SSHD_PORT"

            #
            #  Add host to /root/.ssh/known_hosts
            #
            mkdir -p /root/.ssh
            # shellcheck disable=SC2086
            ssh -o StrictHostKeyChecking=no $SPD_AUTOSSH_CONNECT date

            sed "s/REVERSE_PORT_FORWARD/$SPD_AUTOSSH_REVERSE_PORT\:localhost\:$SPD_SSHD_PORT/" "$DEPLOY_PATH"/files/services/autossh |
                sed "s#REMOTE_CONNECTION#$SPD_AUTOSSH_CONNECT#" >"$service_fname"
            if is_debian; then
                # Debian 10 autossh doesn't have the -e flag, so skip that line
                sed -e '/-e/ s/^#*/#/' -i "$service_fname"
            fi
            chmod 755 "$service_fname"
            ensure_service_is_added autossh default restart
        fi
        ;;

    esac
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
