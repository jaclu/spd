# TODO

## settings scan order

Think this is better but remains to be seen

- file system
- platform - can override filesystem defaults with platform specifics

## Config features

- Delete items needs to be implemented if a platform can not use a default package

## link stdout/err if not present

## Debug levels

0 reduced progress state cmd_filtered shell commands progress will only be displayed on error
1 normal state all cmd_filtered shell commands will display progress
2 .. more and more

should dbg lvl condition be added to log it via second param

## parameter expansion

### handle parallel expansion  

spd_full_name: "{{ SPD_FIRST_name }} {{ spd_last_name }}"

When more than one detected reset relative stats except for global lookup depth count and do full expansion of each item 
