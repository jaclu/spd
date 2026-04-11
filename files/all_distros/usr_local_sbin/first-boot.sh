#!/bin/sh
#
#  Part of https://github.com/jaclu/ish-fstool
#
#  License: MIT
#
#  Copyright (c) 2026: Jacob.Lundqvist@gmail.com
#
#  Tasks to run at 1s boot on iSH platform, such as changing ssh port
#  depending on if this is iSH / iSH-AOK

is_ish() {
    [ -d /proc/ish ]
}

is_ish_aok() {
    is_ish || return 1
    grep -qi ish-aok /proc/version 2>/dev/null
}

set_sshd_port() {
    # change sshd_config and /etc/init.d/autossh to use the right port

    new_port="$1"
    conf="/etc/ssh/sshd_config"

    # Replace existing Port line (first match), else append
    if grep -q '^[[:space:]]*Port[[:space:]]' "$conf"; then
        # Replace first occurrence only
        sed '0,/^[[:space:]]*Port[[:space:]]/s//Port '"$new_port"'/' "$conf" >"$conf.tmp" \
            && mv "$conf.tmp" "$conf"
    else
        printf '\nPort %s\n' "$new_port" >>"$conf"
    fi
}

#===============================================================
#
#   Main
#
#===============================================================

first_boot_done=/etc/opt/ift/1st-boot-done

[ -f "$first_boot_done" ] && exit 0 # first boot has been done
is_ish || exit 0                    # not meanigul to run until the platform is iSH

if is_ish_aok; then
    set_sshd_port 2023
    rm -f /usr/local/bin/uptime # On AOK regular uptime can be used
fi

build_files="
/.chroot_default_cmd
/.chroot_hostname
/etc/opt/chrooted_ish
"

lbl_1 "Doing some first boot on iSH cleanup"

printf '%s\n' "$build_files" \
    | while IFS= read -r f; do
        [ -n "$f" ] || continue
        safe_remove --ignore-sys-path "$f"
    done

mkdir -p "$(dirname "$first_boot_done")"
touch "$first_boot_done"
