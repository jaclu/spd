#!/bin/sh
#
# Copyright (c) 2021,2022: Jacob.Lundqvist@gmail.com
# License: MIT
#
# Version: 1.2.4 2022-03-19
#      Corrected information that AOK kernel was detected not filesystem
#  1.2.1 2021-07-14
#      Improved check for AOK kernel
#  1.2.0 2021-07-25
#       Added this header
#
# Part of https://github.com/jaclu/spd
#

#=====================================================================
#
#  All task scripts must define the following two variables:
#  script_tasks:
#    List tasks provided by this script. If multiple one per line single
#    multi-line string first word is task name, rest is optional
#    description of task
#  script_description
#    Short summary what this script does (for the help display)
#    Single multi line string.
#
#=====================================================================

# shellcheck disable=SC2034
script_tasks="task_hostname"
script_description="Give AOK filesystem hostname suffix -aok to make it more obvious
to indicate a default iSH filesystem.
Since hostname can't be changed inside iSH, we set /etc/hostname to the
desired name and use a custom hostname binary to display this instead."



#=====================================================================
#
# Additional variables
#
#=====================================================================

_th_relative_hostname_bin_source=files/extra_bins/hostname
_th_alternate_hostname_bin=/usr/local/bin/hostname
_th_relative_initd_hostname=custom/etc_files/initd_hostname-aok


#=====================================================================
#
#   Describe additional parameters, if none are used don't define
#   help_local_params() script_base.sh will handle that condition.
#
#=====================================================================

help_local_parameters() {
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
#  Assumed to start with task_ and then describe the task in a sufficiently
#  unique way to give an idea of what this task does,
#  and not collide with other modules.
#  Use a short prefix unique for your module.
#
#=====================================================================

task_hostname() {
    [ "$SPD_HOSTNAME_SET" != "1" ] && return # skip this task requested

    check_abort
    _th_expand_all_deploy_paths

    #
    # source dependencies if not available
    #
    if ! command -V 'ensure_service_is_added' 2>/dev/null | grep -q 'function'; then
        verbose_msg "task_sshd() needs to source openrc to satisfy dependencies"
        # shellcheck disable=SC1091
        . "$DEPLOY_PATH/scripts/tools/openrc.sh"
    fi


    msg_2 "Setting hostname if this is not AOK"

    if [ -n "$(uname -a | grep -i AOK)" ]; then
        msg_3 "AOK kernel"
        msg_3 "hostname will be altered."
        _th_setup_env
        _th_alternate_host_name
    else
        msg_3 "Not AOK"
        rm "$_th_alternate_hostname_bin" 2> /dev/null
    fi
    echo
}



#=====================================================================
#
#   Internal functions, start with _ and abbreviation of script name to make it
#   obvious they should not be called by other modules.
#
#=====================================================================

_th_expand_all_deploy_paths() {
    _th_alternate_hostname_bin_source=$(expand_deploy_path "$_th_relative_hostname_bin_source")
}

_th_setup_env() {
    th_initd_hostname=$(expand_deploy_path "$_th_relative_initd_hostname")
    if [ "$SPD_TASK_DISPLAY" != 1 ]; then
        if [ -f "$_th_alternate_hostname_bin_source" ]; then
            msg_3 "Copying custom hostname binary to $_th_alternate_hostname_bin"
            cp "$_th_alternate_hostname_bin_source" "$_th_alternate_hostname_bin"
	    msg_3 "Copying custom init.d/hostname"
	    cp "$th_initd_hostname" /etc/init.d/hostname
            ensure_installed openrc
	    msg_3 "Ensure it starts in runlevel boot"
            ensure_service_is_added hostname boot restart
        else
            error_msg "Failed to find alternate hostname bin [$_th_alternate_hostname_bin_source]!" 1
        fi
        if [ ! -f /etc/hostname ] || [ "$(cat /etc/hostname)" = 'localhost' ]; then
            msg_3 "Setting default content for /etc/hostname"
            /bin/hostname >  /etc/hostname
        fi
    fi
}

#
#
#  Add -aok if the kernel is not AOK, to indicate regular iSH
#
_th_alternate_host_name() {
    new_hostname="$(/bin/hostname)-aok"
    verbose_msg "New hostname: $new_hostname"
    if [ "$SPD_TASK_DISPLAY" = 1 ]; then
        echo "hostname will be changed into $new_hostname"
    else
        [ ! -x "$_th_alternate_hostname_bin" ] && error_msg "$_th_alternate_hostname_bin not executable, aborting"
        echo  "$new_hostname" > /etc/hostname
        msg_3 "hostname: $($_th_alternate_hostname_bin)"
    fi
    unset new_hostname
}



#=====================================================================
#
#   Run this script via extras/script_base.sh
#
#=====================================================================

script_dir="$(dirname "$0")"

# shellcheck disable=SC1091
[ -z "$SPD_INITIAL_SCRIPT" ] && . "${script_dir}/tools/script_base.sh"

unset script_dir
