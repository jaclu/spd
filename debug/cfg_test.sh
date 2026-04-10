#!/bin/sh

#
# Test
#
d_here="$(dirname "$(dirname "$(realpath "$0")")")"

. "$d_here"/tools/process_cofig_file.sh

read_config_file "$d_here"/debug/dummy_config.yml

# expand_var2() {
#     _ev_varname=$1
#     _ev_needle='${'
#     while eval "_ev_val=\"\$$_ev_varname\""; do
#         # shellcheck disable=SC2154
#         case $_ev_val in
#             *"$_ev_needle"*) ;;
#             *) break ;;
#         esac
#         eval "$_ev_varname=\"$_ev_val\""
#     done
# }

expand_var() {
    _ev_varname=$1
    while eval "_ev_val=\"\$$_ev_varname\""; do
        # shellcheck disable=SC2154
        [ "$_ev_val" = "${_ev_val#*\$\{}" ] && break
        eval "$_ev_varname=\"$_ev_val\""
    done
}

echo "Verify variables retrieved"
# shellcheck disable=SC2154
{
    # expand_var SPD_UNAME
    expand_var SPD_HOME_DIR_CONTENT

    eval foo=\$SPD_HOME_DIR_CONTENT
    echo "SPD_UNAME:            [$SPD_UNAME]"
    echo "SPD_HOME_DIR_CONTENT: [$SPD_HOME_DIR_CONTENT]"
    # echo "foo [$foo]"
    # echo "$SPD_HOME_DIR_CONTENT"
    # echo
    # SPD_HOME_DIR_CONTENT="custom/tars/home_${SPD_UNAME}.tgz"
    # echo "$SPD_HOME_DIR_CONTENT"

}
