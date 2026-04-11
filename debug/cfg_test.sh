#!/bin/sh

#
# Test
#
d_here="$(dirname "$(dirname "$(realpath "$0")")")"

. "$d_here"/tools/process_config_file.sh

read_config_file "$d_here"/debug/dummy_config.yml

echo "Verify variables retrieved"
# shellcheck disable=SC2154
{
    expand_config_var SPD_HOME_DIR_CONTENT
    expand_config_var SPD_UNAME

    eval foo=\$SPD_HOME_DIR_CONTENT
    echo "SPD_UNAME:            [$SPD_UNAME]"
    echo "SPD_HOME_DIR_CONTENT: [$SPD_HOME_DIR_CONTENT]"

}
