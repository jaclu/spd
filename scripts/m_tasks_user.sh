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
script_tasks="task_restore_user      - creates user according to env variables
task_user_pw_reminder  - displays a reminder if no password has been set"
script_description="Creates a new user.
If SPD_UID and/or SPD_GID are given, previous occupants are migrated to the
first available ID at or above 1000 to ensure this user gets the desired IDS"



#=====================================================================
#
#   Describe additional paramas, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_paramas() {
    echo "SPD_UNAME$(
        test -z "$SPD_UNAME" && echo ' - username to ensure exists' \
        || echo "=$SPD_UNAME" )"
    echo "SPD_UID$(
        test -z "$SPD_UID" && echo '   - userid to be used' \
        || echo "=$SPD_UID" )"
    echo "SPD_GID$(
        test -z "$SPD_GID" && echo '   - groupid to be used' \
        || echo "=$SPD_GID" )"
    echo "SPD_SHELL$(
        test -z "$SPD_SHELL" && echo ' - shell for username' \
        || echo "=$SPD_SHELL" )"
    echo "SPD_HOME_DIR_TGZ$(
        test -z "$SPD_HOME_DIR_TGZ" \
        && echo '          - unpack this tgz file if found' \
        || echo "=$SPD_HOME_DIR_TGZ" )"
    echo "SPD_HOME_DIR_UNPACKED_PTR$(
        test -z "$SPD_HOME_DIR_UNPACKED_PTR" \
        && echo ' -  Indicates home.tgz is unpacked' \
        || echo "=$SPD_HOME_DIR_UNPACKED_PTR" )"
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

task_restore_user() {
    msg_txt="Username: $SPD_UNAME"
    SPD_SHELL=${SPD_SHELL:-/bin/ash}

    _mtu_expand_all_deploy_paths

    if [ -n "$SPD_UNAME" ]; then
        #
        # Ensure user is created
        #
        msg_2 "$msg_txt"
        check_abort
        ensure_installed shadow "Adding shadow (provides useradd & usermod)"

        if ! grep -q ^"$SPD_UNAME" /etc/passwd  ; then
            # ensure shadow and hence adduser is installed
            if [ "$SPD_TASK_DISPLAY" = "1" ]; then
                msg_3 "Will be created"
                msg_3 "shell: $SPD_SHELL"
                ensure_shell_is_installed "$SPD_SHELL"
            else
                _mtu_make_available_uid_gid
                params="-m -G wheel -s $SPD_SHELL $SPD_UNAME"
                [ -n "$SPD_UID" ] && params="-u $SPD_UID $params"
                if [ -n "$SPD_GID" ]; then
                    if ! (2> /dev/null groupadd -g "$SPD_GID" "$SPD_UNAME") ; then
                        #if [ "$(groupadd -g "$SPD_GID" "$SPD_UNAME")" != "" ]; then
                        error_msg "group id already in use: $SPD_GID"
                    fi
                    params="-g $SPD_GID $params"
                fi
                cmd="useradd $params"
                if ! ($cmd); then
                    groupdel "$SPD_UNAME"
                    error_msg "task_restore_user() - useradd failed to complete."
                fi
                msg="added: $SPD_UNAME"
                if [ -n "$SPD_UID" ] || [ -n "$SPD_GID" ]; then
                    msg="$msg ("
                    [ -n "$SPD_UID" ] && msg="$msg$SPD_UID"
                    [ -n "$SPD_GID" ] && msg="$msg:$SPD_GID"
                    msg="$msg)"
                fi
                msg_3 "$msg"
                msg_3 "shell: $SPD_SHELL"
            fi
        else
            msg_3 "Already pressent"
            #
            # If given, ensure user has right UID & GID
            #
            if [ "$SPD_UID" != "" ]; then
                msg_3 "Verifying UID"
                if [ "$(id -u "$SPD_UNAME")" != "$SPD_UID" ] ; then
                    error_msg "$(
                        printf "Wrong UID - expected: %s found: " "$SPD_UID"
                        id -u "$SPD_UNAME")"
                fi
            fi
            if [ "$SPD_GID" != "" ]; then
                msg_3 "Verifying GID"
                if [ "$(id -g "$SPD_UNAME")" != "$SPD_GID" ] ; then
                    error_msg "$(
                        printf "Wrong GID - expected: %s found: " "$SPD_GID"
                        (id -g "$SPD_UNAME"))"
                fi
            fi

            msg_3 "Checking shell"
            # extracting part after last :
            current_shell="$(
                grep "^$SPD_UNAME:" /etc/passwd | sed 's/:/ /g' |  \
                awk '{ print $NF }')"
            if [ "$current_shell" != "$SPD_SHELL" ]; then
                if [ "$SPD_TASK_DISPLAY" = "1" ]; then
                    echo "Will change shell $current_shell -> $SPD_SHELL"
                else
                    ensure_shell_is_installed "$SPD_SHELL"
                    usermod -s "$SPD_SHELL" "$SPD_UNAME"
                    echo "new shell: $SPD_SHELL"
                fi
            else
	           echo "$current_shell"
            fi
        fi
        echo

        #
        # Restore user home
        #
        if [ -n "$SPD_HOME_DIR_TGZ" ]; then
            unpack_home_dir "Restoration of /home/$SPD_UNAME" "$SPD_UNAME" \
                /home/"$SPD_UNAME" "$SPD_HOME_DIR_TGZ" \
                "$SPD_HOME_DIR_UNPACKED_PTR"

        fi
    elif [ "$SPD_TASK_DISPLAY" = "1" ] && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
        msg_2 "Will NOT create any user"
    fi
    echo

    unset msg_txt
    unset params
    unset cmd
    unset msg
    unset current_shell
}


task_user_pw_reminder() {
    if [ -n "$SPD_UNAME" ] && grep -q "$SPD_UNAME":\!: /etc/shadow; then
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



#=====================================================================
#
#   Internal functions, start with _ and abrevation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_mtu_expand_all_deploy_paths() {
    #
    # Expanding path variables that are either absolute or relative
    # related to the deploy-path
    #
    SPD_HOME_DIR_TGZ=$(expand_deploy_path "$SPD_HOME_DIR_TGZ")
}



#
#  Try to make the SPD_UID SPD_GID available
#  by trying to move curren occupants to other ids
#  If not possible change SPD_UID / SPD_GID to
#  an available pair and print out warning
#
_mtu_make_available_uid_gid() {
    [ -z "$SPD_UID" ] && [ -z "$SPD_GID" ] && return
    if [ -n "$SPD_UID" ]; then
        user_name=$(sed 's/:/ /g' /etc/passwd | awk '{print $1 " " $3}' | \
                    grep "$SPD_UID" | awk '{print $1}')
    fi
    if [ -n "$SPD_GID" ]; then
        group_name=$(grep "$SPD_GID" /etc/group | sed 's/:/ /' | \
                     awk '{print $1}')
    fi
    if [ -z "$user_name" ] && [ -z "$group_name" ]; then
        # no change needed so we can leave
        msg_3 "No colliding uid or gid"
        return
    fi
    msg_3 "Intended uid/gid is beeing used"
    echo "Will try to free up desired uid & gid"
    #
    # getting the first id free in both users and groups
    #
    over1k="^1...$" # need to be a variable to pass checkbashisms test
    id_available="$(cat /etc/group /etc/passwd | cut -d ":" -f 3 | \
        grep "$over1k" | sort -n | tail -n 1 | \
        awk '{ print $1+1 }')"
    unset over1k

    # If no ids were in the 1xxx range nothing was found, so pick 1000
    test -z "$id_available" && id_available=1000

    chown_home=0
    if test -n "$user_name" ; then
        echo "Changing uid for $user_name into $id_available"
        usermod -u "$id_available" "$user_name"
        chown_home=1
    fi
    if test -n "$group_name" ; then
        echo "Changing gid for $user_name into $id_available"
        groupmod -g "$id_available" "$group_name"
        chown_home=1
    fi
    if [ "$chown_home" = 1 ]; then
        msg_3 "changing home ownership"
        echo "/home/$user_name -> $id_available:$id_available"
        chown "$id_available":"$id_available" /home/"$user_name"
    fi
    #
    # Even if the GID of the offending user wasnt the offending GID
    # this is still a safe action
    #
    test -f /home/"$user_name" && \
        chown "$user_name":"$user_name" /home/"$user_name" -R
    test -f /var/mail/"$user_name" && \
        chown "$user_name":"$user_name" /var/mail/"$user_name" -R

    unset user_name
    unset group_name
    unset id_available
    unset chown_home
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
