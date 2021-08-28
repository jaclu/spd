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

# shellcheck disable=SC2034
script_tasks="task_replace_some_etc_files  - replaces hosts and repositories if so requested
task_patch_etc_files         - Fixes some files with issues"
script_description="Will fix /etc/inittab, and if so requested replace some /etc files"



#=====================================================================
#
#   Describe additional paramas, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_paramas() {
    echo "SPD_FILE_HOSTS$(
        test -z "$SPD_FILE_HOSTS" \
        && echo '        - will replace /etc/hots' \
        || echo "=$SPD_FILE_HOSTS" )"
    echo "SPD_FILE_REPOSITORIES$(
        test -z "$SPD_FILE_REPOSITORIES" \
        && echo ' - will replace /etc/apk/repositories' \
        || echo "=$SPD_FILE_REPOSITORIES" )"
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

task_replace_some_etc_files() {
    verbose_msg "task_replace_some_etc_files()"

    _tef_expand_all_deploy_paths

    msg_2 "Replacing some files in /etc"
    # If the config file is not found, no action will be taken
    check_abort
    
    [ -n "$SPD_FILE_HOSTS" ] &&  _tef_copy_etc_file "$SPD_FILE_HOSTS" /etc/hosts
    [ -n "$SPD_FILE_REPOSITORIES" ] && _tef_copy_etc_file "$SPD_FILE_REPOSITORIES" /etc/apk/repositories
    echo
}

task_patch_etc_files() {
    msg_2 "Patching some /etc files"
    check_abort
    _tef_fix_inittab
    _tef_fix_profile  # Need to run after apt update!!
    echo
}



#=====================================================================
#
#   Internal functions, start with _ and abrevation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_tef_expand_all_deploy_paths() {
    #
    # Expanding path variables that are either absolute or relative
    # related to the deploy-path
    #
    SPD_FILE_HOSTS=$(expand_deploy_path "$SPD_FILE_HOSTS")
    SPD_FILE_REPOSITORIES=$(expand_deploy_path "$SPD_FILE_REPOSITORIES")
}


_tef_copy_etc_file() {

    src_file="$1"
    dst_file="$2"
    surplus_param="$3"

    [ -n "$surplus_param" ] && error_msg "_copy_etc_file($src_file, $dst_file) [$surplus_param] more than 2 params given!"
    verbose_msg "_tef_copy_etc_file($src_file, $dst_file)"
    if [ -n "$src_file" ]; then
        msg_3 "$dst_file"
        [ ! -f "$src_file" ] && error_msg "_tef_copy_etc_file() src_file[$src_file] NOT FOUND!\n$src_file"
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            cp "$src_file" "$dst_file"
            echo "$src_file"
        elif [ "$SPD_TASK_DISPLAY" = "1" ] \
                && [ "$SPD_DISPLAY_NON_TASKS" = "1" ]; then
            echo "Will NOT be modified"
        fi
    fi
    unset dst_file
    unset src_file
    unset surplus_param
}


_tef_fix_inittab() {
    inittab_file="/etc/inittab"
    verbose_msg "_tef_cleanup_inittab()"
     msg_3 "Inspecting $inittab_file"

    # Since iSH has no concept of consoles getty lines are pointless
    if grep -q 'getty' "$inittab_file"; then
        msg_3 "Removing gettys"
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
           sed -i '/getty/d' "$inittab_file"
            echo "done!"
        else
            echo "will happen"
       fi
    fi

    # Get rid of mostly non functional openrc config lines
    ok_line="::sysinit:/sbin/openrc default"
    if grep openrc "$inittab_file" | grep -q -v "$ok_line"; then
        msg_3 "Fixing openrc related content"
        if ! grep -q "$ok_line" /etc/inittab ; then
            if [ "$SPD_TASK_DISPLAY" != "1" ]; then
                sed -i '/::sysinit/d' "$inittab_file"
                sed -i '/::wait:/d' "$inittab_file"
                echo "$ok_line"  >> "$inittab_file"
                echo "done!"
            else
                echo "will happen"
            fi
        else
        echo "Patch already applied!"
        fi
    fi

    unset inittab_file
    unset ok_line
}


_tef_fix_profile() {
    #
    # As of 2021-07-16 profile is updated into a state where path is reversed,
    # by apt update. To minimize the changes, this just throws in
    # a corrected path after this segment
    #
    #
    if grep -q append_path /etc/profile ; then
    msg_3 "Fixing /etc/profile PATH"
    if ! grep -q "export PATH=" /etc/profile ; then
        if [ "$SPD_TASK_DISPLAY" = "1" ]; then
        echo "broken /etc/profile detected, will be fixed"
        else
        sed -i '/^export PATH/a \\n# Fix for broken reversed append_path\nexport PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n' /etc/profile
                echo "done!"
        fi
    else
        echo "Patch already applied!"
    fi
    fi
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
