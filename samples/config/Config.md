# Hierarchial config structure

All config files are expected to be located in ***custom/config*** relative to the
basedir of this repository.

Config files are sourced after the spd code is loaded, so any internal variables
or functions can be accessed.<br>
This makes it possible to do conditionals like this
snippet that I have in the config file named after my iPhones hostname,
I have no need for man pages on my pure ish instance or on my iPhone.

```
if [ "$SPD_FILE_SYSTEM" = "AOK" ]; then
    SPD_APKS_ADD="$SPD_APKS_ADD man-pages mandoc mg-doc"
fi
```

#### Config files are read in the following order, later ones override earlier ones.

If you run a task or bin/deploy-ish with the -v param all config files being
considered, and those found and read are listed.

#### [1] defaults.cfg

This one is parsed first, should set defaults for all config variables.
Typically better to leave as is from the samples/defaults.cfg,
since it ensures safe defaults, not triggering  any action.
Also contains hopefully usefull explainations or any setting.
This config file is the only one that _must_ be present, all others are
simpy ignored if not found.


#### [2] settings-pre-os.cfg

This is typically your baseline config, will be read before any OS / distro
or hostname related configs.<br>
You only need to specify changes from defaults.cfg here and in all additional
config files



#### [3] OS / Distro based config

Read depending on the running machines OS / distro etc.
```
3-1	os_type
3-2	distro_family
3-3	distro
```
Sample config files 
```
[3-1] darwin.cfg
        [3-3] macos.cfg
[3-1] linux.cfg
    [3-2] ish-family.cfg
        [3-3] ish.cfg
        [3-3] ish-aok.cfg
    [3-2] debian.cfg
        [3-3] ubuntu.cfg
```
I have included sample files in ***samples/config*** can be used as a starting point

- ish-family.cfg
- ish.cfg
- ish-aok.cfg

Copy them to ***custom/config***. If they seem usefull.



#### [4] settings-post-os.cfg

Here you can override any OS/distro settings before hostnames are parsed.



#### [5] hostname based config

Per hostname configs.
Pattern is [hostname lowercased].cfg
So a hostname MyiSHDevive would be read as myishdevice.cfg



#### [6] settings-last.cfg

This one is read after all os type and hostname processing. Not something I use, but for some it could be handy.
