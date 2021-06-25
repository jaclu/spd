#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-04-30
# License: MIT
#
# Version: 0.1.0 2021-04-30
#    Initial release
#
# Part of ishTools
#
# See explaination in the top of extras/utils.sh
# for some recomendations on how to set up your modules!
#

if test -z "$DEPLOY_PATH" ; then
    #
    # This was most likely not sourced, define DEPLOY_PATH based
    # on location of this script. This variable is used to find config
    # files etc, so should always be set!
    #
    # First define it relative based on this scripts location
    DEPLOY_PATH="$(dirname "$0")/.."
    # Make it absolutized and normalized
    DEPLOY_PATH="$( cd "$DEPLOY_PATH" && pwd )"
fi



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

task_apk_update() {
    msg_2 "update & fix apk index"
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
        echo
    elif      [ "$SPD_TASK_DISPLAY" = "1" ] \
          &&  [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "$msg_txt"
        echo "nothing listed, no action to take"
        echo
    fi
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
#   Internals, start with _ to make it obvious they should not be
#   called by other modules.
#
#=====================================================================


#=====================================================================
#
# _run_this() & _display_help()
# are only run in standalone mode, so no risk for wrong same named function
# being called...
#
# In standlone mode, this will be run from See "main" part at end of
# extras/utils.sh, it first expands parameters,
# then either displays help or runs the task(-s)
#

_run_this() {
    #
    # Perform the task / tasks independently, convenient for testing
    # and debugging.
    #
    [ -z "$SPD_APKS_DEL" ] && [ -z "$SPD_APKS_ADD" ] && \
        warning_msg "None of the task variables set"
    task_apk_update
    if [ -n "$SPD_APKS_DEL" ]; then
        task_apks_delete
    else
        warning_msg "SPD_APKS_DEL not set, skipping task_apks_delete()"
    fi
    task_apk_upgrade
    if [ -n "$SPD_APKS_ADD" ]; then
        task_apks_add
    else
        warning_msg "SPD_APKS_ADD not set, skipping task_apks_add()"
    fi

    #
    # Always display this final message  in standalone,
    # to indicate process terminated successfully.
    # And did not die in the middle of things...
    #
    echo "Task Completed."
}

_display_help() {
    echo "m_tasks_apk.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info"
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Tasks included:"
    echo " task_apk_update   - updates repository"
    echo " task_apk_upgrade  - upgrades all installed apks"
    echo " task_apks_delete  - deletes all apks listed in SPD_APKS_DEL"
    echo " task_apks_add     - adds all apks listed in SPD_APKS_ADD"
    echo
    echo "Env paramas"
    echo "-----------"
    #
    # If the variable is defined show it, otherwise explain it!
    #
    echo "SPD_APKS_DEL$(
        test -z "$SPD_APKS_DEL" \
        && echo ' - packages to remove, comma separated' \
        || echo "='$SPD_APKS_DEL'")"
    echo "SPD_APKS_ADD$(
        test -z "$SPD_APKS_ADD" \
        && echo ' - packages to add, comma separated' \
        || echo "='$SPD_APKS_ADD'")"
    echo
    echo "SPD_TASK_DISPLAY$(
        test -z "$SPD_TASK_DISPLAY" \
        && echo '      - if 1 will only display what will be done' \
        || echo "=$SPD_TASK_DISPLAY")"
    echo "SPD_DISPLAY_NON_TASKS$(
        test -z "$SPD_DISPLAY_NON_TASKS" \
        && echo ' - if 1 will show what will NOT happen' \
        || echo "=$SPD_DISPLAY_NON_TASKS")"
}



#=====================================================================
#
#     main
#
#=====================================================================

if [ -z "$SPD_INITIAL_SCRIPT" ]; then

    . "$DEPLOY_PATH/scripts/extras/utils.sh"

    #
    # Since sourced mode cant be detected in a practical way under ash,
    # I use this workaround, first script is expected to set it, if set
    # all other modules can assume to be sourced
    #
    SPD_INITIAL_SCRIPT=1
fi
