#!/bin/sh

handler_sysv() {
    # shellcheck disable=SC2154 # opt_task defined by caller
    case "$opt_task" in
        install)
            ln -sf "$svc_script" /etc/rc0.d/K01runbg
            ln -sf "$svc_script" /etc/rc1.d/K01runbg
            ln -sf "$svc_script" /etc/rc6.d/K01runbg

            ln -sf "$svc_script" /etc/rc2.d/S01runbg
            ln -sf "$svc_script" /etc/rc3.d/S01runbg
            ln -sf "$svc_script" /etc/rc4.d/S01runbg
            ln -sf "$svc_script" /etc/rc5.d/S01runbg
            ;;
        remove) safe_remove /etc/rc?.d/*runbg ;;
        *) err_msg "handler_sysv() unrecognized option: [$opt_task]" ;;
    esac
}
