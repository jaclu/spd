#!/bin/sh

#=====================================================================
#
#   Main
#
#=====================================================================

# skip_auto_process_config_hierarchy=yes

D_REPO=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=tools/prepare-env.sh
. "$D_REPO"/tools/prepare-env.sh

#
# Test
#

. "$D_REPO"/tools/process-config_file.sh

read_config_file "$D_REPO"/configs/task_overrides/filesystem_alpine.yml
read_config_file "$D_REPO"/debug/dummy_config.yml

echo "Verify variables retrieved"
# shellcheck disable=SC2154 # SPD_ vars read via config files
{
    expand_config_var SPD_HOME_DIR_CONTENT
    expand_config_var SPD_UNAME

    eval foo=\$SPD_HOME_DIR_CONTENT
    echo "SPD_UNAME:            [$SPD_UNAME]"
    echo "SPD_HOME_DIR_CONTENT: [$SPD_HOME_DIR_CONTENT]"
    echo "SPD_NO_BLANKS:        [$SPD_NO_BLANKS]"
    echo "SPD_WITH_BLANKS:      [$SPD_WITH_BLANKS]"
    echo "SPD_APK_MAN:          [$SPD_APK_MAN]"
}
