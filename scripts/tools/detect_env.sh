#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2022-07-11
# License: MIT
#
# Part of https://github.com/jaclu/spd
#

#
# No need to run more than once
#
[ -n "$os_type" ] && return



_this_script="detect_env.sh"
if [ "$(basename "$0")" = ${_this_script} ]; then
    # If run standalone, display what env was detected
    p_verbose=1
fi
unset _this_script



#
#  disable if unset
#
[ -z ${p_verbose+x} ] && p_verbose=0



#
#  Some constants
#
os_type_Linux='Linux'

distro_family_ish='ish-family'
distro_ish='ish'
distro_ish_AOK='ish-AOK'

os_type_Darwin='Darwin'
distro_MacOS='MacOS'


SPD_ISH_KERNEL=""
kernel_ish="iSH"
kernel_ish_aok="iSH-AOK"

# Sample check of what iSH this is
#[ "$SPD_ISH_KERNEL" = "$kernel_ish_aok" ] && echo "This is iSH-AOK"


#
#  Will set the following variables
#
# os_type       - Basic OS type Linux/Darwin
# distro_family - General distro type, debian/ish etc
# distro        - Specific distro Ubuntu/ish-AOK etc
#

if [ -n "$(command -v apt | grep -v local)" ]; then
    # Uses Debian apt as package manager, filtering out hint that apt
    # is unavailable sometimes pressent in iSH FS
    pkg_add="apt install -f"
    pkg_remove="apt remove"
    pkg_installed="dpkg -i"
    pkgs_update="apt update"
    pkgs_upgrade="apt upgrade"
elif [ -n "$(command -v apk)" ]; then
    # Uses Alpine apk package manager
    pkg_add="apk add"
    pkg_remove="apk del"
    pkg_installed="apk info -e"
    pkgs_update="apk update && apk fix"
    pkgs_upgrade="apk upgrade"
else
    echo
    echo "ERROR Failed to identify package manager!"
    exit 1
fi


#
#  Detect environment
#
case "$(uname)" in

    "$os_type_Linux")
        os_type=$os_type_Linux
        if [ "$(uname -r | grep ish)" != "" ]; then
            distro_family=$distro_family_ish
            #if [ "$(uname -r | grep $distro_ish_AOK)" != "" ]; then
            if grep -q AOK /proc/ish/version ; then
                distro=$distro_ish_AOK
                SPD_ISH_KERNEL="$kernel_ish_aok"
            else
                distro=$distro_ish
                SPD_ISH_KERNEL="$kernel_ish"
            fi
            #elif [ "$(uname -r) | grep ish" != "" ]; then
	elif uname -v | grep -q Alpine ; then
	    distro="Alpine"
        fi
        ;;

    "$os_type_Darwin")
        os_type=$os_type_Darwin
        distro_family=""
        distro=$distro_MacOS
        ;;

    *)
        echo
        echo "ERROR: Failed to detect environment"
        exit 1
        ;;

esac

#
# show what was detected if verbose mode
#
if [ "$p_verbose" = "1" ]; then
    echo
    echo "Env detected"
    echo "------------"
    echo "      os_type: $os_type"
    echo "distro_family: $distro_family"
    echo "       distro: $distro"
    echo
fi
