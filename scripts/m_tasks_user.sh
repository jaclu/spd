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

task_restore_user() {
    msg_txt="Username: $SPD_UNAME"
    SPD_SHELL=${SPD_SHELL:-/bin/ash}
    SPD_UID=${SPD_UID:-1000}
    SPD_GID=${SPD_GID:-1000}

    #_get_username 501
    #exit 14

    #echo "First id: [`_find_first_available_uid`]"
    #exit 1
    #echo "returned from _find_first_available_uid()"
    #exit 1
    
    if [ "$SPD_UNAME" != "" ]; then
        #
        # Ensure user is created
        #
        msg_2 "$msg_txt"
        if ! grep ^"$SPD_UNAME" /etc/passwd > /dev/null ; then
            # ensure shadow and hence adduser is installed
            if [ "$SPD_TASK_DISPLAY" -eq 1 ]; then
                [ "$(grep "x:$SPD_UID:" /etc/passwd)" != "" ] && error_msg "uid:$SPD_UID already in use" 1
                [ "$(grep $SPD_GID /etc/passwd)" != "" ] && error_msg "gid:$SPD_GID already in use" 1
                msg_3 "Will be created as $SPD_UNAME:x:$SPD_UID:$SPD_GID::/home/$SPD_UNAME:$SPD_SHELL"
                msg_3 "shell: $SPD_SHELL"
                ensure_shell_is_installed $SPD_SHELL
            else
                ensure_installed shadow "Adding shadow (provides useradd)"
                # we need to ensure the group exists, before using it in useradd
                # TODO: identidy a 501 group by name and delete it
                #groupdel -g "$SPD_UNAME" 2> /dev/null
                groupadd -g $SPD_GID "$SPD_UNAME"
                [ $? != 0 ] && error_msg "group id already in use: $SPD_GID" 1
                #  sets uid & gid to 501, to match apples uid/gid on iOS mounts
                useradd -u $SPD_UID -g $SPD_GID -G wheel -m -s "$SPD_SHELL" "$SPD_UNAME"
                if [ $? != 0 ]; then
                    groupdel $SPD_UNAME
                    error_msg "task_restore_user() - useradd failed to complete." 1
                fi
                msg_3 "added: $SPD_UNAME ($SPD_UID:$SPD_GID)"
                msg_3 "shell: $SPD_SHELL"
            fi
        else
            msg_3 "Already pressent"
            current_shell=$(grep $SPD_UNAME /etc/passwd | sed 's/:/ /g'|  awk '{ print $NF }')
            if [ "$current_shell" != "$SPD_SHELL" ]; then
                if [ "$SPD_TASK_DISPLAY" = "1" ]; then
                    echo "Will change shell $current_shell -> $SPD_SHELL"
                else
                    ensure_shell_is_installed $SPD_SHELL
                    usermod -s $SPD_SHELL $SPD_UNAME
                    msg_3 "new shell: $SPD_SHELL"
                fi
            fi
        fi
        echo

        #
        # Restore user home
        #
        if [ "$SPD_HOME_DIR_TGZ" != "" ]; then
            msg_txt="Restoration of /home/$SPD_UNAME"
            unpack_home_dir "$SPD_UNAME" /home/"$SPD_UNAME" "$SPD_HOME_DIR_TGZ" "$SPD_HOME_DIR_UNPACKED_PTR"
        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "Will NOT create any user"
    fi
    echo
}


task_user_pw_reminder() {
    [ "$SPD_TASK_DISPLAY" -eq 1 ] && return

    if [ "$SPD_UNAME" != "" ] && [ "$(grep "$SPD_UNAME":\!: /etc/shadow)" != "" ]; then
        echo "+------------------------------+"
        echo "|                              |"
        echo "|  Remember to set a password  |"
        echo "|  for your added user:        |"
        echo "|    sudo passwd $SPD_UNAME"
        echo "|                              |"
        echo "+------------------------------+"
        echo
    fi
}



#==========================================================
#
#   Internals
#
#==========================================================

#
# Returns a username, if one is assigned to the param uid
#
_get_username(){
  uid="$1"

  # First try using getent
  if command -v getent > /dev/null 2>&1; then
    echo ">> getent"
    getent passwd "$uid" | cut -d: -f1

  # Next try using the UID as an operand to id.
  elif command -v id > /dev/null 2>&1 && \
    echo ">> id"
       id -nu "$uid" > /dev/null 2>&1; then
    id -nu "$uid"

  # Next try perl - perl's getpwuid just calls the system's C library getpwuid
  elif command -v perl >/dev/null 2>&1; then
    echo ">> perl"
    perl -e '@u=getpwuid($ARGV[0]);
             if ($u[0]) {print $u[0]} else {exit 2}' "$uid"

  # As a last resort, parse `/etc/passwd`.
  else
      echo " parse passwd"
      awk -v uid="$uid" -F: '
         BEGIN {ec=2};
         $3 == uid {print $1; ec=0; exit 0};
         END {exit ec}' /etc/passwd
  fi
}

_find_first_available_uid() {
    i=501

    until false; do
	#echo ">> trying with $i"
	[ "$(grep $i /etc/passwd)" == "" ] && break
	i="$((i+1))"
    done
    verbose_msg "First available UID: $i"
    echo $i
}


_run_this() {
    task_restore_user
    task_user_pw_reminder
    echo "Task Completed."
}      


_display_help() {
    echo "m_tasks_user.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Tasks included:"
    echo " task_restore_user      - creates user according to env variables"
    echo " task_user_pw_reminder  - displays a reminder if no password has been set"
    echo 
    echo "Creates a new user, ensuring it will not overwrite an existing one."
    echo
    echo "Env variables used"
    echo "------------------"
    echo "SPD_UNAME$(test -z "$SPD_UNAME" && echo ' - username to ensure exists' || echo =$SPD_UNAME )"
    echo "SPD_UID$(test -z "$SPD_UID" && echo ' - userid to be used' || echo =$SPD_UID )"
    echo "SPD_GID$(test -z "$SPD_GID" && echo ' - groupid to be used' || echo =$SPD_GID )"
    echo "SPD_SHELL$(test -z "$SPD_SHELL" && echo ' - shell for username' || echo =$SPD_SHELL )"
    echo "SPD_HOME_DIR_TGZ$(test -z "$SPD_HOME_DIR_TGZ" && echo ' - unpack this tgz file if found' || echo =$SPD_HOME_DIR_TGZ )"
    echo "SPD_HOME_DIR_UNPACKED_PTR$(test -z "$SPD_HOME_DIR_UNPACKED_PTR" && echo ' -  Indicates home.tgz is unpacked' || echo =$SPD_HOME_DIR_UNPACKED_PTR )"
    
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
