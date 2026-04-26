# TODO

## settings scan order

Think this is better but remains to be seen

- file system
- platform - can override filesystem defaults with platform specifics

## Config features

- Delete items needs to be implemented if a platform can not use a default package

## link stdout/err if not present

## Debug levels

0 reduced progress state cmd_wrapper shell commands progress will only be displayed on error
1 normal state all cmd_wrapper shell commands will display progress
2 .. more and more

should dbg lvl condition be added to log it via second param

## parameter expansion

### handle parallel expansion

SPD_FULL_NAME: "{{ SPD_FIRST_NAME }} {{ SPD_LAST_NAME }}"

When more than one detected reset relative stats except for global lookup depth
count and do full expansion of each item

## platform-iSH.sh more actions needed

FS Alpine

Install etc/inittab-alpine

Install extras to /usr/local/bin

Generate sshd host keys

Link the fake init to /sbin/init

FS Devuan

Install custom /etc/init.d/rc

Generate required locales

Install etc/inittab-devuan

FS Debian, old version 10

Deploy custom_openssh {{ ift_openssh_tgz }}

Install custom /etc/init.d/rc

Install etc/inittab-devuan

FS Debian, old version 10

Deploy custom_openssh {{ ift_openssh_tgz }}

Install custom /etc/init.d/rc

Link the fake init to /sbin/init
