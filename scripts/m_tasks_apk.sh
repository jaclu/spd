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
#    List tasks provided by this script. If multilple one per line single
#    multi-line string first word is task name, rest is optional
#    description of task
#  script_description
#    Short summary what this script does (for the help display)
#    Single multiline string.
#
#=====================================================================

# shellcheck disable=SC2034
script_tasks="task_apk_update   - update and fix repository
task_apks_delete  - deletes all apks listed in SPD_APKS_DEL
task_apk_upgrade  - upgrades all installed apks
task_apks_add     - adds all apks listed in SPD_APKS_ADD"



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
}


task_apks_add() {
    msg_txt="Installing my selection of software"
    if [ -n "$SPD_APKS_ADD" ]; then
        msg_2 "$msg_txt"
        _filter_dels_from_add
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            echo "$items_add"
        else
            # TODO: see in task_apks_delete() for description
            # about why this seems needed ATM
            check_abort
            echo "$items_add"

            cmd="apk add $items_add"
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



#
#  Remove anything that should not be here from adds, to avoid repeated deletes and adds
#
_filter_dels_from_add() {
    lst="$SPD_APKS_ADD"
    while true; do
        item="${lst%% *}"  # upto first colon excluding it
        lst="${lst#* }"    # after fist colon

	if [ "${SPD_APKS_DEL#*$item}" != "$SPD_APKS_DEL" ]; then
	    echo "WARNING: $item in both SPD_APK_ADD and SPD_APK_DEL - will not be added!"
        else
            if [ -n "$items_add" ]; then
                export items_add="$items_add $item"
            else
                export items_add="$item"
            fi
        fi
        [ "$lst" = "$item" ] && break  # we have processed last item
    done
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
