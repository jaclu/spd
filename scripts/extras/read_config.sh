#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-07-25
# License: MIT
#
# Part of https://github.com/jaclu/spd


#
# This should only be sourced...
#
_this_script="read_config.sh"
if [ "$(basename "$0")" = ${_this_script} ]; then
    echo "ERROR: ${_this_script} is not meant to be run stand-alone!"
    exit 1
fi
unset _this_script

# shellcheck disable=SC1091
. "$DEPLOY_PATH/scripts/extras/detect_env.sh"

CONFIG_PATH="$DEPLOY_PATH/custom/config"



#==========================================================
#
#   Public functions
#
#==========================================================

#
# See samples/config/Config.md for explanation how config files are
# processed.
#
read_config() {
    #
    # the config files are located in $DEPLOY_PATH/custom/config/
    # and have the extension .cfg
    # In order to lowercase the cfg file names when they depend
    # on env variables we only give the base name of the
    # config file below
    #
    _read_cfg_file defaults 1

    _read_cfg_file settings-pre-os

    echo "os_type:       [$os_type]"
    echo "distro_family: [$distro_family]"
    echo "distro:        [$distro]"
    [ -n "$os_type" ] &&        _read_cfg_file "$os_type"
    [ -n "$distro_family" ] &&  _read_cfg_file "$distro_family"
    [ -n "$distro" ] &&         _read_cfg_file "$distro"

    _read_cfg_file settings-post-os

    _read_cfg_file "$(hostname | sed 's/\./ /' | awk '{print $1}')"

    _read_cfg_file settings-last

    [ -n "$p_verbose" ] && echo  # White space after listing config files parsed
}



#==========================================================
#
#   Internals
#
#==========================================================

_read_cfg_file() {
    cfg_file="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    must_exist="${2:-0}"

    [ -z "$cfg_file" ] && error_msg "_read_cfg_file() called with no param!"
    cfg_file="$CONFIG_PATH/${cfg_file}.cfg"

    if [ -f "$cfg_file" ]; then
        verbose_msg "will read: $cfg_file"
        #shellcheck disable=SC1090
        . "$cfg_file"
    elif [ "$must_exist" = "1" ]; then
        error_msg "_read_cfg_file($cfg_file) obligatory config file not found!"
    else
        verbose_msg "NOT found: $cfg_file"
    fi

    unset cfg_file
    unset musut_exist
}
