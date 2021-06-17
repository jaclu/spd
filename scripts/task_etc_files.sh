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

task_replace_some_etc_files() {
    _expand_all_etc_deploy_paths
    msg_2 "Copying some files to /etc"
    # If the config file is not found, no action will be taken

    _copy_etc_file /etc/hosts "$SPD_FILE_HOSTS"
    _copy_etc_file /etc/apk/repositories "$SPD_FILE_REPOSITORIES"
    #
    # The AOK inittab is more complex, and does not need to be modified
    # to enablle openrc, so we do not touch it.
    #
    if [ "$SPD_FILE_SYSTEM" != "AOK" ]; then
        _copy_etc_file /etc/inittab "$DEPLOY_PATH/files/inittab-default-FS"
    fi
    echo
}



#==========================================================
#
#   Internals
#
#==========================================================

_expand_all_etc_deploy_paths() {
    SPD_FILE_HOSTS=$(expand_deploy_path "$SPD_FILE_HOSTS")
    SPD_FILE_REPOSITORIES=$(expand_deploy_path "$SPD_FILE_REPOSITORIES")
}


_copy_etc_file() {
    dst_file="$1"
    src_file="$2"
    surplus_param="$3"
    [ "$surplus_param" != "" ] && error_msg "_copy_etc_file("$dst_file","$src_file") more than 2 params given!" 1
    [ "$dst_file" = "" ] && error_msg "_copy_etc_file() param 1 dst_file not supplied!" 1
    if [ "$src_file" != "" ]; then
    	msg_3 "$dst_file"
    	[ -f "$src_file" ] || error_msg "_copy_etc_file() src_file NOT FOUND!\n$src_file\n" 1    
    	if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            cp "$src_file" "$dst_file"
   	    echo "$src_file"
    	elif [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
            echo "Will NOT be modified"
    	fi
    fi
    unset src_file
    unset dst_file
    unset surplus_param
}


_run_this() {
    task_replace_some_etc_files
    echo "Tasks Completed."
}


_display_help() {
    _expand_all_etc_deploy_paths
    echo "m_tasks_etc_files.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Some tasks to change /etc files"
    echo
    echo "Tasks included:"
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
