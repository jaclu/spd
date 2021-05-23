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
    echo
    echo "ERROR: $1"
    echo
    exit 1
}
    

#
# This should only be sourced...
#
[ "$DEPLOY_PATH" = "" ] && _local_error_msg "Not meant to be run standalone: scripts/extras/read_config.sh"
    
. "$DEPLOY_PATH/scripts/extras/detect_env.sh"




#==========================================================
#
#   Public functions
#
#==========================================================

read_cfg_file() {
    cfg_file="$1"
    [ -z "$cfg_file" ] && _local_error_msg "read_cfg_file() called with no param!"
    cfg_file="$DEPLOY_PATH/custom/${cfg_file}.cfg"
    verbose_msg "will read: [$cfg_file]"
    #echo read_cfg_file($cfg_file)
    if [ ! -f "$cfg_file" ]; then
	warning_msg "Config file not found: [$cfg_file]"
	return
    fi
    . "$cfg_file"
    #verbose_msg "Parsed: $cfg_file"
    ## [ $p_verbose -eq 1 ] echo "Parsed: $cfg_file"
    [ $SPD_ABORT -eq 1 ] && error_msg "SPD_ABORT detected in $cfg_file" 1
}


read_config() {
    #
    #   Identify the local env, and parse config file
    #
 

    #
    # Set some defaults, in case they are not set in the config file
    # This prevents shellcheck from giving waarnings aboout unasigned variables
    # 
    SPD_UNAME=""
    SPD_APKS_DEL=""
    SPD_APKS_ADD=""
    SPD_TIME_ZONE=""
    SPD_ROOT_UNPACKED_PTR=""
    SPD_HOME_DIR_UNPACKED_PTR=""
    SPD_EXTRA_TASK=""
    
    #
    # Config files
    #
    echo ">> os_type[$os_type] distro_family[$distro_family] distro[$distro] settings[$settings] hostname[$(hostname)]"
    read_cfg_file $os_type
    [ "$distro_family" != "" ] && read_cfg_file $distro_family
    [ "$distro" != "" ] && read_cfg_file $distro
    read_cfg_file settings  # gemeral user settings
    read_cfg_file $(hostname)

    [ $p_verbose -eq 1 ] && echo  # Whitespace after listing config files parsed

    # process path references in config file
    _expand_path_all_params

    #
    # Extra checks for numerical params
    #
    if [ "$SPD_DISPLAY_NON_TASKS" = "" ] || [ "$SPD_DISPLAY_NON_TASKS" != "1" ]; then
        SPD_DISPLAY_NON_TASKS="0"
    fi
    
    # Default sshd port
    [ "$SPD_SSHD_PORT" = "" ] && SPD_SSHD_PORT=1022
   
    if [ "$SPD_ROOT_REPLACE" = "" ] || [ "$SPD_ROOT_REPLACE" -ne 1 ]; then
        SPD_ROOT_REPLACE=0
    fi

    #
    # Unset variables depending on others
    #
    
    # dont unpack user home without an username
    [ "$SPD_UNAME" = "" ] && SPD_HOME_DIR_TGZ=""
}



#==========================================================
#
#   Internals
#
#==========================================================

_expand_path() {
    #
    #  Path not starting with / are asumed to be relative to
    #  $DEPLOY_PATH
    #
    this_path="$1"
    char_1=$(echo "$this_path" | head -c1)

    if [ "$char_1" = "/" ]; then
        echo "$this_path"
    else
        echo "$DEPLOY_PATH/$this_path"
    fi
}


_expand_path_all_params() {
    #
    # Expands all path params that might be relative
    # to the deploy location into a full path
    #
    if [ "$SPD_FILE_REPOSITORIES" = "*** do not touch ***" ]; then
        SPD_FILE_REPOSITORIES=""
    elif [ "$SPD_FILE_REPOSITORIES" != "" ] ; then
        SPD_FILE_REPOSITORIES=$(_expand_path "$SPD_FILE_REPOSITORIES")
    else
        # Use default Alpine repofile
        SPD_FILE_REPOSITORIES="$DEPLOY_PATH/files/repositories-Alpine-v3.12"
    fi
    [ "$SPD_FILE_HOSTS" != "" ] && SPD_FILE_HOSTS=$(_expand_path "$SPD_FILE_HOSTS")
    if [ "$SPD_SSH_HOST_KEYS" != "" ]; then
        #echo "### expanding: [$SPD_SSH_HOST_KEYS]"        
        SPD_SSH_HOST_KEYS=$(_expand_path "$SPD_SSH_HOST_KEYS")
        #echo "    expanded into: [$SPD_SSH_HOST_KEYS]"
    fi
    if [ "$SPD_HOME_DIR_TGZ" != "" ]; then
        #echo "### expanding: [$SPD_HOME_DIR_TGZ]"        
        SPD_HOME_DIR_TGZ=$(_expand_path "$SPD_HOME_DIR_TGZ")
        #echo "    expanded into: [$SPD_HOME_DIR_TGZ]"
    fi
    if [ "$SPD_ROOT_HOME_TGZ" != "" ]; then
        #echo "### expanding: [$SPD_ROOT_HOME_TGZ]"        
        SPD_ROOT_HOME_TGZ=$(_expand_path "$SPD_ROOT_HOME_TGZ")
        #echo "    expanded into: [$SPD_ROOT_HOME_TGZ]"
    fi
    if [ "$SPD_EXTRA_TASK" != "" ]; then
        SPD_EXTRA_TASK=$(_expand_path "$SPD_EXTRA_TASK")
    fi
    #
    # switch to new params
    #
}



