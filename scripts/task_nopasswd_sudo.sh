#!/bin/sh
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
script_tasks="task_nopasswd_sudo"
script_description="Installs sudo and creates a no password sudo group wheel,
if it does not already exist. This task has no direct parameters."



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

task_nopasswd_sudo() {
    msg_2 "no-pw sudo for group wheel"
    if [ "$SPD_TASK_DISPLAY" != "1" ]; then
        check_abort
        ensure_installed sudo
        if [ -f /etc/sudoers.d/wheel ]; then
            msg_3 "group wheel already setup by AOK-iSH"
        else
            grep deploy-ish /etc/sudoers > /dev/null
            if [ $? -eq 1 ]; then
                msg_3 "adding %wheel NOPASSWD to /etc/sudoers"
                echo "%wheel ALL=(ALL) NOPASSWD: ALL # added by deploy-ish" >> /etc/sudoers
            else
                msg_3 "present"
            fi
        fi
    elif [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        echo "Will NOT be set"
    else
        echo "will be set if not done already"
    fi
    echo
}



#=====================================================================
#
#   Run this script via extras/script_base.sh
#
#=====================================================================

script_dir="$(dirname "$0")"

# shellcheck disable=SC1091
[ -z "$SPD_INITIAL_SCRIPT" ] && . "${script_dir}/tools/script_base.sh"

unset script_dir
