#!/bin/sh
# shellcheck disable=SC2154
#
#  Copyright (c) 2021, 2022: Jacob.Lundqvist@gmail.com
#  License: MIT
#
#  Part of https://github.com/jaclu/spd
#
#  Installs / de-installs listed packages
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
script_tasks="task_pkgs_update   - update and fix repository
task_pkgs_delete  - deletes all apks listed in SPD_PKGS_DEL
task_pkgs_upgrade  - upgrades all installed apks
task_pkgs_add     - adds all apks listed in SPD_PKGS_ADD"

#=====================================================================
#
#   Describe additional parameters, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_parameters() {
    echo "SPD_PKGS_DEL$(
        test -z "$SPD_PKGS_DEL" &&
            echo ' - packages to remove, comma separated' ||
            echo "='$SPD_PKGS_DEL'"
    )"
    echo "SPD_PKGS_ADD$(
        test -z "$SPD_PKGS_ADD" &&
            echo ' - packages to add, comma separated' ||
            echo "='$SPD_PKGS_ADD'"
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

task_pkgs_update() {
    _mtp_param_cleanup
    msg_2 "update repositories"
    check_abort
    if [ "$SPD_TASK_DISPLAY" = "1" ]; then
        msg_3 "Will happen"
    else
        check_abort

        if ! repo_update; then
            error_msg "Failed to update repos - network issue?"
        fi
    fi
    echo
}

task_pkgs_upgrade() {
    _mtp_param_cleanup
    msg_2 "upgrade installed apks"
    if [ "$SPD_TASK_DISPLAY" = "1" ]; then
        msg_3 "Will happen"
    else
        check_abort
        repo_upgrade || error_msg "Failed to upgrade apks - network issue?"
    fi
    echo
}

task_pkgs_delete() {
    _mtp_param_cleanup
    msg_txt="Removing unwanted software"

    if [ -n "$SPD_PKGS_DEL" ]; then
        msg_2 "$msg_txt"
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            echo "$SPD_PKGS_DEL"
        else
            check_abort
            echo "$SPD_PKGS_DEL"
            # TODO: fix
            # argh due to shellcheck complaining that
            #   apk del $SPD_PKGS_DEL
            # should instead be:
            #   apk del "$SPD_PKGS_DEL"
            # and that leads to apk not recognizing it as multiple apks
            # this seems to be a usable workaround
            #
            cmd="$pkg_remove $SPD_PKGS_DEL"
            verbose_msg "Will run: $cmd"
            $cmd
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] &&
        [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "$msg_txt"
        echo "nothing listed, no action to take"
    fi
    echo

    unset msg_txt
}

task_pkgs_add() {
    _mtp_param_cleanup
    msg_txt="Installing my selection of software"
    if [ -n "$SPD_PKGS_ADD" ]; then
        msg_2 "$msg_txt"
        _mtp_filter_dels_from_add
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            echo "$items_add"
        else
            # TODO: see in task_pkgs_delete() for description
            # about why this seems needed ATM
            check_abort
            echo "$items_add"

            cmd="$pkg_add $items_add"
            verbose_msg "Will run: $cmd"
            echo ">> cmd [$cmd]"
            $cmd || error_msg "Failed to install requested software - network issue?"

        fi
        unset items_add
        echo
    elif [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "$msg_txt"
        echo "nothing listed, no action to take"
        echo
    fi
}

#=====================================================================
#
#   Internal functions, start with _ and abbreviation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_mtp_param_cleanup() {
    # remove extra spaces
    # shellcheck disable=SC2086
    SPD_PKGS_ADD="$(echo $SPD_PKGS_ADD | xargs)"
    # shellcheck disable=SC2086
    SPD_PKGS_DEL="$(echo $SPD_PKGS_DEL | xargs)"
}
#
#  Remove anything that should not be here from adds, to avoid repeated deletes and adds
#
_mtp_filter_dels_from_add() {
    add_lst="$SPD_PKGS_ADD"
    del_lst="$SPD_PKGS_DEL"
    while true; do
        add_item="${add_lst%% *}" # up to first space excluding it
        add_lst="${add_lst#* }"   # after fist space

        abort_this=0
        lst=$del_lst
        while true; do
            del_item="${lst%% *}" # up to first space excluding it
            lst="${lst#* }"       # after fist space

            if [ "$add_item" = "$del_item" ]; then
                echo "WARNING: $add_item in both SPD_PKGS_ADD and SPD_PKGS_DEL - will not be added!"
                abort_this=1
            fi
            [ $abort_this -eq 1 ] && break
            [ "$lst" = "$del_item" ] && break # we have processed last item
        done
        if [ $abort_this -eq 0 ]; then
            if [ -n "$items_add" ]; then
                export items_add="$items_add $add_item"
            else
                export items_add="$add_item"
            fi
        fi
        [ "$add_lst" = "$add_item" ] && break # we have processed last item
    done
    unset add_lst
    unset del_lst
    unset add_item
    unset abort_this
    unset lst
    unset del_item
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
