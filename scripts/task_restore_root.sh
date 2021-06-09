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

task_restore_root() {
    _update_root_shell
    msg_txt="Restoration of /root"
    if [ "$SPD_ROOT_HOME_TGZ" != "" ]; then
        unpack_home_dir root /root "$SPD_ROOT_HOME_TGZ" "$SPD_ROOT_UNPACKED_PTR" "$SPD_ROOT_REPLACE"
        echo
    fi
}



#==========================================================
#
#   Internals
#
#==========================================================

_update_root_shell() {
    SPD_ROOT_SHELL="${SPD_ROOT_SHELL:-"/bin/ash"}"
    #pidfile="${SSHD_PIDFILE:-"/run/$RC_SVCNAME.pid"}"

    if [ "$SPD_ROOT_SHELL" = "" ]; then
        # no change requested
        return
    fi   
    
    current_shell=$(grep ^root /etc/passwd | sed 's/:/ /g'|  awk '{ print $NF }')
    
    if [ "$current_shell" != "$SPD_ROOT_SHELL" ]; then
        msg_2 "Changing root shell"
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            echo "Will change root shell $current_shell -> $SPD_ROOT_SHELL"
            ensure_shell_is_installed $SPD_ROOT_SHELL
        else
            ensure_shell_is_installed $SPD_ROOT_SHELL
            usermod -s $SPD_ROOT_SHELL root
            msg_3 "new root shell: $SPD_ROOT_SHELL"
        fi
        echo
 
    elif [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_3 "root shell unchanged"
        echo "$current_shell"
        echo
    fi
}

_run_this() {
    task_restore_root
    echo "Task Completed."
}

_display_help() {
    echo "task_restore_root.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Restores root environment. currently shell and /root content can be modified."            
    echo "Can restore /root from a tgz file. Optional ptr to indicate if it has"
    echo "already been unpacked."
    echo "Normal operation is to just untar it into /root."
    echo "SPD_ROOT_REPLACE=1 moves /root to /root-OLD (previous such removed)"
    echo "Before unpacking."
    echo
    echo "Env paramas"
    echo "-----------"
    echo "SPD_ROOT_SHELL$(test -z "$SPD_ROOT_SHELL" && echo ' - switch to this shell' || echo =$SPD_ROOT_SHELL )"
    echo "SPD_ROOT_HOME_TGZ$(test -z "$SPD_ROOT_HOME_TGZ" && echo ' - unpack this into /root if found' || echo =$SPD_ROOT_HOME_TGZ )"
    echo
    echo "SPD_ROOT_UNPACKED_PTR$(test -z "$SPD_ROOT_UNPACKED_PTR" && echo ' - Indicates root.tgz is unpacked' || echo =$SPD_ROOT_UNPACKED_PTR )"
    echo "SPD_ROOT_REPLACE$(test -z "$SPD_ROOT_REPLACE" && echo ' - if 1 move previous /root to /root-OLD and replace it' || echo =$SPD_ROOT_REPLACE )"
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

