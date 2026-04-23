#!/bin/sh

test_variable_retrieval() {
    expand_yaml_config_var SPD_UNAME

    echo "Verify variables retrieved"
    # shellcheck disable=SC2154 # SPD_ vars read via config files
    {
        # expand references to other variables recursively
        expand_yaml_config_var SPD_HOME_DIR_CONTENT
        expand_yaml_config_var SPD_UNAME

        eval foo=\$SPD_HOME_DIR_CONTENT
        echo "SPD_UNAME:            [$SPD_UNAME]"
        echo "SPD_HOME_DIR_CONTENT: [$SPD_HOME_DIR_CONTENT]"
        echo "SPD_NO_BLANKS:        [$SPD_NO_BLANKS]"
        echo "SPD_WITH_BLANKS:      [$SPD_WITH_BLANKS]"
        echo "SPD_APK_MAN:          [$SPD_APK_MAN]"
    }
}

test_variable_defaults() {

    expand_yaml_config_var SPD_EMPTY_NOT omega
    expand_yaml_config_var SPD_EMPTY omega

    # shellcheck disable=SC2154 # SPD_ vars read via config files
    {
        echo "SPD_EMPTY_NOT [$SPD_EMPTY_NOT]"
        echo "SPD_EMPTY [$SPD_EMPTY]"
    }
}

test_recursive_references() {

    # expand_yaml_config_var SPD_REF_3
    # # shellcheck disable=SC2154 # SPD_ vars read via config files
    # echo "SPD_REF_3 [$SPD_REF_3]"

    # # circular ref 5 4 3 2 4
    expand_yaml_config_var SPD_REF_5
    # shellcheck disable=SC2154 # SPD_ vars read via config files
    echo "SPD_REF_5 [$SPD_REF_5]"

    # expand_yaml_config_var SPD_SELF_REF
    # # shellcheck disable=SC2154 # SPD_ vars read via config files
    # echo "SPD_SELF_REF [$SPD_SELF_REF]"
}

test_multiple_references() {

    expand_yaml_config_var SPD_MULTIPLE
    # shellcheck disable=SC2154 # SPD_ vars read via config files
    echo "SPD_MULTIPLE [$SPD_MULTIPLE]"
}

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

. "$D_REPO"/tools/process-yaml-config_file.sh

parse_yaml_config_file "$D_REPO"/configs/task_overrides/filesystem_alpine.yml
parse_yaml_config_file "$D_REPO"/debug/dummy_config.yml

# test_variable_retrieval
# test_variable_defaults
# test_recursive_references
test_multiple_references
