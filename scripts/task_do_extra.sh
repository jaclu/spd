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
#    Single multi line string.
#
#=====================================================================

# shellcheck disable=SC2034
script_tasks="task_do_extra_task        - Runs user supplied script"
script_description="Runs additional script defined by SPD_EXTRA_TASK
Script will be sourced so exiting functions and variables can be used"

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

task_do_extra_task() {
    _tde_expand_deploy_paths
    if [ -n "$SPD_EXTRA_TASK" ]; then
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            msg_2 "Will run custom task"
            echo "$SPD_EXTRA_TASK"
        else
            msg_2 "Running custom task"
        fi
        test -f "$SPD_EXTRA_TASK" || error_msg "$SPD_EXTRA_TASK not found"
        test -x "$SPD_EXTRA_TASK" || error_msg "$SPD_EXTRA_TASK not executable"
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            check_abort
            echo "Running:   $SPD_EXTRA_TASK"
            echo
            # shellcheck disable=SC1090
            . "$SPD_EXTRA_TASK"
            echo "Completed: $SPD_EXTRA_TASK"
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "NO custom task will be run"
    fi
    echo

    unset msg_txt
}

#=====================================================================
#
#   Internal functions, start with _ and abbreviation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_tde_expand_deploy_paths() {
    #
    # Expanding path variables that are either absolute or relative
    # related to the deploy-path
    #
    SPD_EXTRA_TASK=$(expand_deploy_path "$SPD_EXTRA_TASK")
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
