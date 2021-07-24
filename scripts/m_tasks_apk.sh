#!/bin/sh
#
#  This script is controlled from extras/script_base.sh this specific
#  script only contains settings and overrrides.
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

script_tasks="task_apk_update   - updates repository
task_apk_upgrade  - upgrades all installed apks
task_apks_delete  - deletes all apks listed in SPD_APKS_DEL
task_apks_add     - adds all apks listed in SPD_APKS_ADD"
#script_description=""



#=====================================================================
#
#   Describe additional paramas, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_paramas() {
    echo "SPD_APKS_DEL$(
        test -z "$SPD_APKS_DEL" \
        && echo ' - packages to remove, comma separated' \
        || echo "='$SPD_APKS_DEL'")"
    echo "SPD_APKS_ADD$(
        test -z "$SPD_APKS_ADD" \
        && echo ' - packages to add, comma separated' \
        || echo "='$SPD_APKS_ADD'")"
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

#
#  Assumed to start with task_ and then describe the task in a suficiently
#  unique way to give an idea of what this task does,
#  and not collide with other modules.
#  Use a short prefix unique for your module.
#

task_apk_update() {
    msg_2 "update & fix apk index"
    check_abort
    if [ "$SPD_TASK_DISPLAY" = "1" ]; then
        msg_3 "Will happen"
    else
        check_abort
        if ! apk update && apk fix ; then
            error_msg "Failed to update repos - network issue?"
        fi
    fi
    echo
}


task_apk_upgrade() {
    msg_2 "upgrade installed apks"
    if [ "$SPD_TASK_DISPLAY" = "1" ]; then
        msg_3 "Will happen"
    else
        check_abort
        apk upgrade ||  error_msg "Failed to upgrade apks - network issue?"
    fi
    echo
}


task_apks_delete() {
    msg_txt="Removing unwanted software"

    if [ -n "$SPD_APKS_DEL" ]; then
        msg_2 "$msg_txt"
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            echo "$SPD_APKS_DEL"
        else
            check_abort
            echo "$SPD_APKS_DEL"
            # TODO: fix
            # argh due to shellcheck complaining that
            #   apk del $SPD_APKS_DEL
            # should instead be:
            #   apk del "$SPD_APKS_DEL"
            # and that leads to apk not recognizing it as multiple apks
            # this seems to be a useable workarround
            #
            cmd="apk del $SPD_APKS_DEL"
            verbose_msg "Will run: $cmd"
            $cmd
        fi
    elif      [ "$SPD_TASK_DISPLAY" = "1" ] \
          &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "$msg_txt"
        echo "nothing listed, no action to take"
    fi
    echo

    unset msg_txt
    unset msg
}


task_apks_add() {
    msg_txt="Installing my selection of software"
    if [ -n "$SPD_APKS_ADD" ]; then
        msg_2 "$msg_txt"
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            echo "$SPD_APKS_ADD"
        else
            # TODO: see in task_apks_delete() for description
            # about why this seems needed ATM
            check_abort
            cmd="apk add $SPD_APKS_ADD"
            verbose_msg "Will run: $cmd"
            $cmd || error_msg "Failed to install requested software - network issue?"

        fi
        echo
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "$msg_txt"
        echo "nothing listed, no action to take"
        echo
    fi
}



#=====================================================================
#
#   Run this script via script_base
#
#=====================================================================


[ -z "$SPD_INITIAL_SCRIPT" ] && . extras/script_base.sh
