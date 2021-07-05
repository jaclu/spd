#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-06-27
# License: MIT
#
# Version: 0.1.0 2021-06-27
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
    DEPLOY_PATH="$(dirname $0)/.."
    # Make it absolutized and normalized
    DEPLOY_PATH="$( cd $DEPLOY_PATH && pwd )"
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

task_hostname() {
    [ "$SPD_HOSTNAME_SET" != "1" ] && return # skip this task requested

    msg_2 "Setting hostname if this is not AOK"    
     _th_expand_all_deploy_paths     
    [ -z "$SPD_HOSTNAME_BIN" ] && SPD_HOSTNAME_BIN="$_th_alternate_hostname_bin_destination"
    _th_setup_env

    if [ -d "/AOK" ]; then 
        msg_3 "AOK filesystem"
	echo "hostname will not be altered."
    else
        _th_alternate_host_name
    fi
    echo
}



#=====================================================================
#
#   Internals, start with _ to make it obvious they should not be
#   called by other modules.
#
#=====================================================================

_th_expand_all_deploy_paths() {
    _th_alternate_hostname_bin_source=$(expand_deploy_path "$_th_alternate_hostname_bin_source")
}


_th_setup_env() {
    if [ "$SPD_TASK_DISPLAY" != 1 ]; then
        if [ ! -f "$SPD_HOSTNAME_BIN" ]; then
            echo "Copying custom hostname binary to $SPD_HOSTNAME_BIN"
            cp "$_th_alternate_hostname_bin_source"  "$SPD_HOSTNAME_BIN"
        fi
        if [ ! -f /etc/hostname ] || [ "$(cat /etc/hostname)" = 'localhost' ]; then
	    echo "Setting default content for /etc/hostname"
	    echo "$(/bin/hostname)" >  /etc/hostname
        fi
    fi
}


_th_alternate_host_name() {
    current_hostname="$(hostname)"
    new_hostname="$(/bin/hostname)-i"
    if [ "$SPD_TASK_DISPLAY" = 1 ]; then
        echo "hostname will be changed into $new_hostname"
    else
        [ ! -x "$SPD_HOSTNAME_BIN" ] && error_msg "SPD_HOSTNAME_BIN not executable, aborting"
        echo  "$new_hostname" > /etc/hostname
        msg_3 "hostname: $(hostname)"
    fi
    unset current_hostname
    unset new_hostname
}


#=====================================================================
#
# _run_this() & _display_help()
# are only run in standalone mode, so no risk for wrong same named function
# being called...
#
# In standlone mode, this will be run from See "main" part at end of
# extras/utils.sh, it first expands parameters,
# then either displays help or runs the task(-s)
#

_run_this() {
    #
    # Perform the task / tasks independently, convenient for testing
    # and debugging.
    #
    task_hostname
    #
    # Always display this final message  in standalone,
    # to indicate process terminated successfully.
    # And did not die in the middle of things...
    #
    echo "Task Completed."
}


_display_help() {
    echo "m_tasks_hostname.sh [-v] [-c] [-h]"
    echo "  -v  - verbose, display more progress info" 
    echo "  -c  - reads config files for params"
    echo "  -h  - Displays help about this task."
    echo
    echo "Give hostname -i suffix if not AOK filesystem"
    echo
    echo "Tasks included:"
    echo " task_hostname"
    echo
    echo "Give non AOK filesystem hostname suffix -i to make it more obvious"
    echo "to indicate a default iSH filesystem."
    echo "Since hostname can't be changed inside iSH, we set /etc/hostname to the"
    echo "desired name and use a custom hostname binary to display this instead."
    echo
    echo "Env paramas"
    echo "-----------"
    echo "SPD_HOSTNAME_BIN$(
        test -z "$SPD_HOSTNAME_BIN" \
	&& echo ' -' \
	&& echo '  Location of binary acting as hostname replacement (reading /etc/hostname)' \
	&& echo "  defaults to $_th_alternate_hostname_bin_destination." \
	&& echo '  This needs to be before /bin in your PATH! You also need to change your' \
	&& echo '  prompt to use $(hostname) instead of \h "' \
	&& echo '  In order for this alternate hostname version to be used.' \
	&& echo ' ' \
        || echo "=$SPD_HOSTNAME_BIN")"
    echo "SPD_HOSTNAME_SET$(
        test -z "$SPD_HOSTNAME_SET" \
        && echo ' - if not 1 this task will be skipped, and no hostname related steps will be taken.' \
        || echo "=$SPD_HOSTNAME_SET")"
	
    echo "SPD_TASK_DISPLAY$(
        test -z "$SPD_TASK_DISPLAY" \
        && echo '  - if 1 will only display what will be done' \
        || echo "=$SPD_TASK_DISPLAY")"
    echo
}



#=====================================================================
#
#     main
#
#=====================================================================

#
# Some defaults
#
_th_alternate_hostname_bin_source=files/extra_bins/hostname
_th_alternate_hostname_bin_destination=/usr/local/bin/hostname

if [ -z "$SPD_INITIAL_SCRIPT" ]; then

    . "$DEPLOY_PATH/scripts/extras/utils.sh"

    #
    # Since sourced mode cant be detected in a practical way under ash,
    # I use this workaround, first script is expected to set it, if set
    # all other modules can assume to be sourced
    #
    SPD_INITIAL_SCRIPT=1
fi
