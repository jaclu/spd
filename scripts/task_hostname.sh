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
script_tasks="task_hostname"
script_description="Give non AOK filesystem hostname suffix -i to make it more obvious
to indicate a default iSH filesystem.
Since hostname can't be changed inside iSH, we set /etc/hostname to the
desired name and use a custom hostname binary to display this instead."



#=====================================================================
#
# Additional variables
#
#=====================================================================

_th_alternate_hostname_bin_source=files/extra_bins/hostname
_th_alternate_hostname_bin_destination=/usr/local/bin/hostname


#=====================================================================
#
#   Describe additional paramas, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_paramas() {
    echo "SPD_HOSTNAME_BIN$(
    test -z "$SPD_HOSTNAME_BIN" \
        && echo ' -' \
        && echo '  Location of binary acting as hostname replacement (reading /etc/hostname)' \
        && echo "  defaults to $_th_alternate_hostname_bin_destination." \
        && echo '  This needs to be before /bin in your PATH!' \
        && echo "  You also need to change your prompt to use \$(hostname) instead of \h " \
        && echo '  In order for this alternate hostname version to be prompt displayed.' \
        && echo ' ' \
        || echo "=$SPD_HOSTNAME_BIN")"
    echo "SPD_HOSTNAME_SET$(
        test -z "$SPD_HOSTNAME_SET" \
        && echo ' - if not 1 this task will be skipped, and no hostname related steps will be taken.' \
        || echo "=$SPD_HOSTNAME_SET")"
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

task_hostname() {
    [ "$SPD_HOSTNAME_SET" != "1" ] && return # skip this task requested

    msg_2 "Setting hostname if this is not AOK"    
    check_abort
    _th_expand_all_deploy_paths     

    if [ -d "/AOK" ]; then 
        msg_3 "AOK filesystem"
        echo "hostname will not be altered."
    else
    	[ -z "$SPD_HOSTNAME_BIN" ] && SPD_HOSTNAME_BIN="$_th_alternate_hostname_bin_destination"
    	_th_setup_env
        _th_alternate_host_name
    fi
    echo
}



#=====================================================================
#
#   Internal functions, start with _ and abrevation of script name to make it
#   obvious they should not be called by other modules.
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
            /bin/hostname >  /etc/hostname
        fi
    fi
}

_th_alternate_host_name() {
    new_hostname="$(/bin/hostname)-i"
    verbose_msg "New hostname: $new_hostname"
    if [ "$SPD_TASK_DISPLAY" = 1 ]; then
        echo "hostname will be changed into $new_hostname"
    else
        [ ! -x "$SPD_HOSTNAME_BIN" ] && error_msg "SPD_HOSTNAME_BIN not executable, aborting"
        echo  "$new_hostname" > /etc/hostname
        msg_3 "hostname: $(hostname)"
    fi
    unset new_hostname
}



#=====================================================================
#
#   Run this script via extras/script_base.sh
#
#=====================================================================

# shellcheck disable=SC1091
[ -z "$SPD_INITIAL_SCRIPT" ] && . "$(dirname "$0")"/extras/script_base.sh
