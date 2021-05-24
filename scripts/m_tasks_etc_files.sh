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


if test -z "$DEPLOY_PATH" ; then
    # Most likely not sourced...
    DEPLOY_PATH="$(dirname "$0")/.."               # relative
    DEPLOY_PATH="$( cd "$DEPLOY_PATH" && pwd )"  # absolutized and normalized
fi



#==========================================================
#
#   Public functions
#
#==========================================================

task_etc_hosts() {
    # Add my local hosts
    msg_txt="/etc/hosts"
    if [ "$SPD_FILE_HOSTS" != "" ]; then
        msg_3 "$msg_txt"
        test -f "$SPD_FILE_HOSTS" || error_msg "SPD_FILE_HOSTS not found!\n$SPD_FILE_HOSTS" 1
        echo "$SPD_FILE_HOSTS"
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            cp "$SPD_FILE_HOSTS"  /etc/hosts
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_3 "$msg_txt"
        echo "Will NOT be modified"
    fi
}


task_etc_apk_repositories() {
    msg_txt="/etc/apk/repositories"
    if  [ "$SPD_FILE_REPOSITORIES" != "" ]; then
        msg_3 "$msg_txt"
        test -f "$SPD_FILE_REPOSITORIES" || error_msg "SPD_FILE_REPOSITORIES not found!\n$SPD_FILE_REPOSITORIES" 1
        echo "$SPD_FILE_REPOSITORIES"
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            cp "$SPD_FILE_REPOSITORIES" /etc/apk/repositories
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_3 "$msg_txt"
        echo "Will NOT be modified"
    fi
}


replace_default_fs_inittab() {
    #
    # The AOK inittab is more complex, and does not need to be modified
    # to hack sshd to run at boot, so we do not touch it.
    #
    if [ "$SPD_FILE_SYSTEM" != "AOK" ]; then
        msg_3 "/etc/inittab"
        # Get rid of unused getty's
        inittab=$DEPLOY_PATH/files/inittab-default-FS
        echo "$inittab"
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            cp "$inittab" /etc/inittab
        fi
        unset inittab
    fi
}


task_replace_some_etc_files() {
    msg_2 "Copying some files to /etc"
    # If the config file is not found, no action will be taken

    task_etc_hosts
    task_etc_apk_repositories
    replace_default_fs_inittab
}



#==========================================================
#
#   Internals
#
#==========================================================

_run_this() {
    task_replace_some_etc_files
    echo "Tasks Completed."
}


_display_help() {
    echo "m_tasks_etc_files.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Some tasks to change /etc files"
    echo
    echo "Tasks included:"
    echo " task_update              - updates repository"
    echo " task_upgrade             - upgrades all installed apks"
    echo " task_remove_software     -  deletes all apks listed in SPD_APKS_DEL"
    echo " task_install_my_software - adds all apks listed in SPD_APKS_ADD"
    echo
    echo " task_replace_some_etc_files - "
    echo "   SPD_FILE_HOSTS will replace /etc/hots"
    echo "   SPD_FILE_REPOSITORIES will replace /etc/apk/repositories"
    echo "If the default /etc/inittab from iSH is detected it is replaced with one"
    echo "where all gettys are disabled, since they arent used anyhow,"
    echo "and openrc settings are corected. This will not happen on AOK filesystems"
    echo "Their inittab is mostly ok"
    echo
    echo "Env paramas"
    echo "-----------"
    echo "SPD_FILE_HOSTS$(test -z "$SPD_FILE_HOSTS" && echo ' - custom /etc/hosts' || echo =$SPD_FILE_HOSTS )"
    echo "SPD_FILE_REPOSITORIES$(test -z "$SPD_FILE_REPOSITORIES" && echo ' - repository_file_to_use' || echo =$SPD_FILE_REPOSITORIES )"
    echo
    echo "SPD_TASK_DISPLAY$(test -z "$SPD_TASK_DISPLAY" && echo ' -  if 1 will only display what will be done' || echo =$SPD_TASK_DISPLAY)"
    echo "SPD_DISPLAY_NON_TASKS$(test -z "$SPD_DISPLAY_NON_TASKS" && echo ' -  if 1 will show what will NOT happen' || echo =$SPD_DISPLAY_NON_TASKS)"
}



#==========================================================
#
#     main
#
#==========================================================

if [ "$SPD_INITIAL_SCRIPT" = "" ]; then

    . "$DEPLOY_PATH/scripts/extras/utils.sh"

    #
    # Since sourced mode cant be detected in a practiacl way under ash,
    # I use this workaround, first script is expected to set it, if set
    # script can assume to be sourced
    #
    SPD_INITIAL_SCRIPT=1
fi
