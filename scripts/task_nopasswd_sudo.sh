#!/bin/sh
#
#  This script is controlled from extras/script_base.sh this specific
#  script only contains settings and overrrides.
#
#   List tasks provided by this script. If multilple one per line single
#   multi-line string
#
script_tasks="task_nopasswd_sudo"

#=====================================================================
#
#   Short summary what this script does (for the help display)
#   Single multiline string.
#
#=====================================================================
script_description="Installs sudo and creates a no password sudo group wheel,
if it does not allready exist. This task has no direct params."



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

task_nopasswd_sudo() {
    msg_2 "no-pw sudo for group wheel"
    if [ "$SPD_TASK_DISPLAY" != "1" ]; then
        check_abort
        ensure_installed sudo
        grep deploy-ish /etc/sudoers > /dev/null
        if [ $? -eq 1 ]; then
            msg_3 "adding %wheel NOPASSWD to /etc/sudoers"
            echo "%wheel ALL=(ALL) NOPASSWD: ALL # added by deploy-ish" >> /etc/sudoers
        else
            msg_3 "pressent"
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
#   Internals, start with _ to make it obvious they should not be
#   called by other modules.
#
#=====================================================================



#=====================================================================
#
#   Describe additional paramas
#
#=====================================================================

help_local_paramas() {
}



#=====================================================================
#
#   Run this script via script_base
#
#=====================================================================

. extras/script_base.sh
