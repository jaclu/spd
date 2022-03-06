#!/bin/sh



if [ -z "$SPD_INITIAL_SCRIPT" ]; then
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

    # shellcheck disable=SC1091
    . "$DEPLOY_PATH/scripts/extras/utils.sh"

    #
    # Since sourced mode cant be detected in a practical way under a
    # posix shell, I use this workaround.
    # First script is expected to set it, if set all other modules
    # can assume to be sourced.
    #
    SPD_INITIAL_SCRIPT=1
fi

env | grep "APK"
echo "$SPD_APKS_ADD before [$SPD_APKS_ADD]"
SPD_APKS_ADD="$(apk_list_add $SPD_APKS_ADD 'foo1 foo2')"
echo
echo "$SPD_APKS_ADD after [$SPD_APKS_ADD]"
exit 1
