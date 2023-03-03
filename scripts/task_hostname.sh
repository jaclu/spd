#!/bin/sh
# shellcheck disable=SC2154
#
#  Copyright (c) 2021,2022: Jacob.Lundqvist@gmail.com
#  License: MIT
#
#  Part of https://github.com/jaclu/spd
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
script_tasks="task_hostname"
script_description="Give AOK kernels hostname suffix -aok to make it more
obvious to indicate a default iSH filesystem.
Since hostname can't be changed inside iSH, we set /etc/hostname to the
desired name and use a custom hostname binary to display this instead."

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

task_hostname() {
    if [ "$SPD_HOSTNAME_SET" != "1" ]; then
        msg_2 "Hostname will not be processed"
        return # skip this task requested
    fi

    check_abort

    _th_task_label

    #
    # source dependencies if not available
    #
    if ! command -V 'ensure_service_is_added' 2>/dev/null | grep -q 'function'; then
        verbose_msg "task_hostname() needs to source openrc to satisfy dependencies"
        # shellcheck disable=SC1091
        . "$DEPLOY_PATH/scripts/tools/openrc.sh"
    fi

    if ! is_aok_kernel; then
        msg_2 "Not AOK kernel, hostname does not need altering"
        return
    elif hostname | grep -q "\-aok"; then
        msg_3 "Hostname already set for AOK kernel"
        return
    fi

    orig_hostname="$(hostname)"
    new_hostname="${orig_hostname}-aok"
    initd_hostname="/etc/init.d/hostname"
    if [ "$SPD_TASK_DISPLAY" = "0" ]; then
        orig_hostname="$(hostname)"
        if is_debian; then
            msg_3 "Removing previous service files"
            rm -f /etc/init.d/hostname
            rm -f /etc/init.d/hostname.sh
            rm -f /etc/rcS.d/S01hostname.sh
            rm -f /etc/systemd/system/hostname.service
        fi
        msg_3 "Changing hostname into:$new_hostname"
        sed s/NEW_HOSTNAME/"$new_hostname"/ "$DEPLOY_PATH"/files/init.d/aok-hostname-service >"$initd_hostname"
        chmod 755 "$initd_hostname"
        ensure_service_is_added hostname boot
        "$initd_hostname" restart
        msg_3 "Hostname now is:$(hostname)"
        #
        #  Since hostname was changed, configs need to be read again,
        #  in order to pick up the config for this renamed hostname
        #
        msg_1 "Changed hostname - re-reading config"
        read_config
    else
        msg_3 "hostname will be altered into: $new_hostname"
    fi
    unset orig_hostname
    unset new_hostname
    unset initd_hostname
}

#=====================================================================
#
#   Internal functions, start with _ and abbreviation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_th_task_label() {
    msg_2 "Change hostname for AOK kernels"
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
