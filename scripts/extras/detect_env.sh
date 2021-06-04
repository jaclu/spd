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
# No need to run more than once
#
[ ! -z "$os_type" ] && return

#
#  Will set the following variables
#
# os_type       - Basic OS type Linux/Darwin
# distro_family - General distro type, debian/ish etc
# distro        - Specific distro Ubuntu/ish-AOK etc
#



#
#  Some constants
#
os_type_Linux='Linux'
os_type_Darwin='Darwin'

distro_family_ish='ish'

distro_ish='ish'
distro_ish_AOK='ish-AOK'
distro_MacOS='MacOS'


#
#  Detect environ
#
case "$(uname)" in
    $os_type_Linux)
        os_type=$os_type_Linux
    	if [ "$(uname -r | grep $distro_family_ish)" != "" ]; then
	    distro_family=$distro_family_ish
	    if [ "$(uname -r | grep $distro_ish_AOK)" != "" ]; then
	        distro=$distro_ish_AOK
	    else
	    	distro=$distro_ish
	    fi
	#elif [ "$(uname -r) | grep ish" != "" ]; then
	fi
    	;;
	
    $os_type_Darwin)
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
