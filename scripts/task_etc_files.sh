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

task_replace_some_etc_files() {
    verbose_msg "task_replace_some_etc_files()"

    _tef_expand_all_deploy_paths

    msg_2 "Doing some fixes to /etc"
    # If the config file is not found, no action will be taken
    check_abort
    
    [ -n "$SPD_FILE_HOSTS" ] &&  _tef_copy_etc_file "$SPD_FILE_HOSTS" /etc/hosts
    [ -n "$SPD_FILE_REPOSITORIES" ] && _tef_copy_etc_file "$SPD_FILE_REPOSITORIES" /etc/apk/repositories
    _tef_cleanup_inittab

    echo
}



#=====================================================================
#
#   Internals, start with _ to make it obvious they should not be
#   called by other modules.
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


_tef_cleanup_inittab() {
    inittab_file="/etc/inittab"
    verbose_msg "_tef_cleanup_inittab()"
    msg_3 "Cleanup of $inittab_file"

    # Since iSH has no concept of consoles getty lines are pointless
    if grep -q 'getty' "$inittab_file"; then
	msg_3 "removing getty's"
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
        if [ "$SPD_TASK_DISPLAY" != "1" ]; then
            sed -i '/::sysinit/d' "$inittab_file"
            sed -i '/::wait:/d' "$inittab_file"
            echo $ok_line  >> "$inittab_file"
            echo "done!"
        else
            echo "will happen"
       fi
    fi

    unset inittab_file
    unset ok_line
}


#=====================================================================
#
# _run_this() & _display_help()
# are only run in standalone mode, so no risk for wrong same named function
# being called...
#
# In standlone mode, this will be run from See "main" part at end of
# extras/utils.sh, it first expands parameters,
# then either displays help or runs run_this
#
_run_this() {
    #
    # Perform the task / tasks independently, convenient for testing
    # and debugging.
    #
    [ -z "$SPD_FILE_HOSTS" ] && [ -z "$SPD_FILE_REPOSITORIES" ] \
        && error_msg "None of the relevant variables set, nothing will be done"
    task_replace_some_etc_files
}


_display_help() {
    _tef_expand_all_deploy_paths

    echo "task_etc_files.sh [-v] [-c] [-h]"
    echo "  -h  - Displays help about this task."
    echo "  -c  - reads config files for params"
    echo "  -x  - Run this task, otherwise just display what would be done"
    echo "  -v  - verbose, display more progress info"
    echo
    echo "Tasks included:"
    echo " task_replace_some_etc_files"
    echo
    echo "Will fix /etc/inittab, and if so requested replace some /etc files"
    echo
    echo "Env paramas"
    echo "-----------"
    echo "SPD_FILE_HOSTS$(
        test -z "$SPD_FILE_HOSTS" \
        && echo '        - will replace /etc/hots' \
        || echo "=$SPD_FILE_HOSTS" )"
    echo "SPD_FILE_REPOSITORIES$(
        test -z "$SPD_FILE_REPOSITORIES" \
        && echo ' - will replace /etc/apk/repositories' \
        || echo "=$SPD_FILE_REPOSITORIES" )"
    echo
    echo "SPD_TASK_DISPLAY$(
        test -z "$SPD_TASK_DISPLAY" \
        && echo '      - if 1 will only display what will be done' \
        || echo "=$SPD_TASK_DISPLAY")"
    echo "SPD_DISPLAY_NON_TASKS$(
        test -z "$SPD_DISPLAY_NON_TASKS" \
        && echo ' - if 1 will show what will NOT happen' \
        || echo "=$SPD_DISPLAY_NON_TASKS")"
    echo
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
