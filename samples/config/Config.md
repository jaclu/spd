# Hierarchial config structure

All config files are expected to be located in ***custom/config*** relative to the
basedir of this repository.

I haven included a sample defaults.cfg file in ***samples/config*** can be used as a starting point

Copy to ***custom/config*** to use it

Config files are sourced after the spd code is loaded, so any internal variables
or functions can be accessed.<br>
This makes it possible to do conditionals like this
snippet that I have in the config file named after my iPhones hostname,
I have no need for man pages on my pure ish instance or on my iPhone.

```bash
if is_aok; then
    SPD_PKGS_ADD="$SPD_PKGS_ADD man-pages mandoc mg-doc"
fi
```

## Config files are read in the following order, later ones override earlier ones

If you run a task or bin/deploy-ish with the -v param all config files being
considered, and those found and read are listed.

### [1] defaults.cfg

This one is parsed first, should set defaults for all config variables.
Typically better to leave as is from the samples/defaults.cfg,
since it ensures safe defaults, not triggering  any action.
Also contains hopefully usefull explainations for any setting.
This config file is the only one that must be present, all others are
simpy ignored if not found.

### [2] OS / Distro based config

Read depending on the running machines OS / distro etc.
The code for this is in scripts/tools/utils.sh:detect_env()
This describes my implementation, feel free to change it to match your
logic.

```text
2-1 cfg_os_type
2-2 cfg_kernel
2-3 cfg_distro_family
2-4 cfg_distro
```

config files that will be used if found, the mac and ubuntu is mostly
just to show how to add other platforms. This is not an apropriate tool
for managing full blown systems, use ansible or similar for that.

```text
[2-1] darwin.cfg
            [2-4] macos.cfg
[2-1] linux.cfg
        [2-3] debian.cfg
            [2-4] ubuntu.cfg
[2-1] ish.cfg                           - general iSH stuff
    [2-2] ish-kernel.cfg                - specifics for Standard iSH kernel
            [2-4] ish-alpine.cfg        - specifics for ish running Alpine FS
            [2-4] ish-debian.cfg        - specifics for iSH running Debian FS
    [2-2] ish-aok.cfg                   - specifics for the iSH-AOK kernel
            [2-4] ish-alpine.cfg        - specifics for iSH-AOK running Alpine FS
            [2-4] ish-debian.cfg        - specifics for iSH-AOK running Debian FS
```

### [3] hostname based config

Per hostname configs.
Pattern is [hostname lowercased].cfg
So a hostname MyiSHDevive would be read as myishdevice.cfg

### [4] settings-last.cfg

This one is read after all os type and hostname processing. Not something I use, but for some it could be handy.
