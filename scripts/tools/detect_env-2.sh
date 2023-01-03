#!/bin/sh
#
# Copyright (c) 2021: Jacob.Lundqvist@gmail.com 2021-07-25
# License: MIT
#
# Part of https://github.com/jaclu/spd
#

#
# No need to run more than once
#
[ -n "$os_type" ] && return



_this_script="detect_env.sh"
echo ">> extras/$_this_script"
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



#
#  Will set the following variables
#
# os_type       - Basic OS type Linux/Darwin
# distro_family - General distro type, debian/ish etc
# distro        - Specific distro Ubuntu/ish-AOK etc
#

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
            else
                distro=$distro_ish
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
exit 1
