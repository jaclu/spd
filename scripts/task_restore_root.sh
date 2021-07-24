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

script_tasks="task_restore_root"
script_description="Restores root environment. currently shell and /root content can be modified."



#=====================================================================
#
#   Describe additional paramas, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_paramas() {
    echo "SPD_ROOT_SHELL$(
        test -z "$SPD_ROOT_SHELL" \
        && echo '        - switch to this shell' \
        || echo "=$SPD_ROOT_SHELL")"
    echo "SPD_ROOT_HOME_TGZ$(
        test -z "$SPD_ROOT_HOME_TGZ" \
        && echo '     - unpack this into /root if found' \
        || echo "=$SPD_ROOT_HOME_TGZ")"
    echo
    echo "SPD_ROOT_UNPACKED_PTR$(
        test -z "$SPD_ROOT_UNPACKED_PTR" \
        && echo ' - Indicates root.tgz is unpacked' \
        || echo "=$SPD_ROOT_UNPACKED_PTR")"
    echo "SPD_ROOT_REPLACE$(
        test -z "$SPD_ROOT_REPLACE" \
        && echo '      - if 1 move previous /root to /root-OLD and replace it' \
        || echo "=$SPD_ROOT_REPLACE")"
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

task_restore_root() {
    check_abort
    _trr_expand_all_deploy_paths
    _trr_update_root_shell

    if [ "$SPD_ROOT_HOME_TGZ" != "" ]; then
        unpack_home_dir "Restoration of /root" root /root \
                "$SPD_ROOT_HOME_TGZ" "$SPD_ROOT_UNPACKED_PTR" \
                "$SPD_ROOT_REPLACE"
        echo
    fi
}



#=====================================================================
#
#   Internal functions, start with _ and abrevation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_trr_expand_all_deploy_paths() {
    #
    # Expanding path variables that are either absolute or relative
    # related to the deploy-path
    #
    SPD_ROOT_HOME_TGZ=$(expand_deploy_path "$SPD_ROOT_HOME_TGZ")
}


_trr_update_root_shell() {
    SPD_ROOT_SHELL="${SPD_ROOT_SHELL:-"/bin/ash"}"

    [ "$SPD_ROOT_SHELL" = "" ] && return # no change requested
    
    current_shell=$(grep ^root /etc/passwd | sed 's/:/ /g'|  awk '{ print $NF }')
    
    if [ "$current_shell" != "$SPD_ROOT_SHELL" ]; then
        msg_2 "Changing root shell"
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
            echo "Will change root shell $current_shell -> $SPD_ROOT_SHELL"
            ensure_shell_is_installed "$SPD_ROOT_SHELL"
        else
            ensure_shell_is_installed "$SPD_ROOT_SHELL"
            usermod -s "$SPD_ROOT_SHELL" root
            msg_3 "new root shell: $SPD_ROOT_SHELL"
        fi
        echo
 
    elif       [ "$SPD_TASK_DISPLAY" = "1" ] \
            && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_3 "root shell unchanged"
        echo "$current_shell"
        echo
    fi

    unset current_shell
}



#=====================================================================
#
#   Run this script via script_base
#
#=====================================================================


[ -z "$SPD_INITIAL_SCRIPT" ] && . extras/script_base.sh
