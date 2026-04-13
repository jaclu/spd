- name: Ensure /usr/bin/uptime is symlink to /bin/busybox
# The procps uptime throws Segmentation fault on iSH
# but the package is generally useful, providing a better ps
shell:
cmd: \
    | if [ ! -L /usr/bin/uptime ] \
        || [ "$(readlink -f /usr/bin/uptime)" != "/bin/busybox" ]; then
        if [ -e /usr/bin/uptime ]; then
            rm -f /usr/bin/uptime.ORG # only remove .ORG if it will be replaced
            mv -f /usr/bin/uptime /usr/bin/uptime.ORG || exit 30
        fi
        ln -sf /bin/busybox /usr/bin/uptime || exit 31
        exit 43
    fi
