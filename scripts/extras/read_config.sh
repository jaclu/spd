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


_local_error_msg() {
    printf '\n\nERROR: %b\n' "$1"
    exit 1
}
    

#
# This should only be sourced...
#
[ -z "$DEPLOY_PATH" ] && _local_error_msg "Not meant to be run standalone: scripts/extras/read_config.sh"
    
. "$DEPLOY_PATH/scripts/extras/detect_env.sh"




#==========================================================
#
#   Public functions
#
#==========================================================



#
# Order of reading config files, all lowercased:
#  1 defaults.cfg
#     Here initial defaults are set, like 22 for sshd port etc
#  2 settings-pre.cfg
#     This one is read before parsing os/distro type related configs,
#     here you can set defaults, that might get overridden.
#     Normally this would be the safe location for general settings,
#     Since everything that does not work for a given os/distro will
#     Later be removed or changed.
#  3 $os_type such as linux.cfg / darwin.cfg
#  4 $distro_family such as debian.cfg / ish.cfg
#  5 $distro   such as ubuntu.cfg / ish-aok.cfg
#     If $distro_family is enough to identify a distro, then there will
#     typically not be a matching $distro config file to read
#  6 settings-post.cfg
#     This one is read after the os/distro configs have been read, so this
#     can override os/distro settings.
#  7 $(hostname) up to first dot of hostname such as jacpad.cfg
#     Will always be the last config processed, so what goes here stays.
#

read_config() {
    #
    # the config files are located in $DEPLOY_PATH/custom/config/
    # and have the extention .cfg
    # In order to lowercase the cfg file names when they depend
    # on env variables we only give the basename of the
    # config file below
    #
    _read_cfg_file defaults

    _read_cfg_file settings-pre
    
    [ -n "$os_type" ] &&        _read_cfg_file "$os_type"
    [ -n "$distro_family" ] &&  _read_cfg_file "$distro_family"
    [ -n "$distro" ] &&         _read_cfg_file "$distro"
    
    _read_cfg_file settings-post  # general user settings

    _read_cfg_file "$(hostname | sed 's/\./ /' | awk '{print $1}')"

    [ -n "$p_verbose" ] && echo  # Whitespace after listing config files parsed
}







#==========================================================
#
#   Internals
#
#==========================================================

_read_cfg_file() {
    cfg_file="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

    [ -z "$cfg_file" ] && _local_error_msg "_read_cfg_file() called with no param!"
    cfg_file="$DEPLOY_PATH/custom/config/${cfg_file}.cfg"

    if [ ! -f "$cfg_file" ]; then
	verbose_msg "NOT found: $cfg_file"
        unset cfg_file
	return
    fi
    verbose_msg "will read: $cfg_file"
    . "$cfg_file"
    
    #msg_3 "After reading $cfg_file"
    #echo "Current state of SPD_APKS_DEL:"
    #echo "$SPD_APKS_DEL"
    #echo
    unset cfg_file
}



