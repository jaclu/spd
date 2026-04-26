# Simple Posix Deploy

This is in the process of a total rewrite, last old stable prior to this is tagged
with `latest-stable` but it's pretty dated...

Deploy tool with minimal dependencies, to run it initially only needs posix shell,
any dependencies for spd itself is handled from within.
Suitable for deployment of minimalistic environments, such as iSH/Termux etc.
Primary purpose is to be used instead of Ansible etc, on limited environments where
it can't run locally, or the task over head makes it unpractical to run from a
deploy sever.

If not using git on the target platform, clone this then copy/tar it to external/cloud
storage, and then either run it directly from there or untar it first.

iCloud on iSH is so slow, that copying this to an iCloud destination is glacial.
In that scenario taring it to iCloud is almost instant, and the recommended approach.

## Current status

Far from done, but kind of runs now. Can be tested on iSH, make sure to remove
`config_templates/global_overrides.yml` and/or `configs/global_overrides.yml`
for simplicity, or edit them accordingly.

Then run `./tasks/platform-iSH.sh`

## spd_dependency_issue

1 - neither install nor remove can be done
2 - remove but not install can be done

## Config files

Configs are assumed to be in configs/
The repo has generic sample congis in config_templates/ when any task is started
and configs/ does not exist config_templates/ are copied there for initial usage.
configs/ is in .gitignore, and if it exists it is never touched. So any changes
there will never be meddled with if the repo is updated.

Configs are expected to by yaml files, and referencing other settings is valid

SPF_FOO: "{{ SPD_BAR }}"

a config file is read using `parse_yaml_config_file config.yml`
This pre-parses the yml file creating variables of each entry, but no expansion.
if the same name is found in a later config file, the previous state of the variable
is simply replaced.

Before using a config var `expand_yaml_config_var variable` should be done, this
expands the variable it it contains a `{{ FOO }}` block, depending on the current
variables defined via prior calls to `parse_yaml_config_file`

OK this is a two step procedure, but offers yaml handling without any dependencies.

### Basic config

At task initializsation the following configs are read

- configs/defaults.yml

Then depending on detected File System, one of:

- `configs/file_systems/alpine.yml`
- `configs/file_systems/debian.yml`
- `configs/file_systems/devuan.yml`

Next depending on Platform, one of:

- `configs/platform/ish.yml`
  Special case if kernel is iSH-AOK an additional platform config is read,
  to allow for iSH-AOK specific overrides
  - `configs/platform/ish_aok.yml`

- `configs/platform/linux.yml`
- `configs/platform/macos.yml` Essentially only to set `SPD_ABORT: 2` to prevent
  accidental running of any code there.

Then based on hostname-s (lowercased) `configs/hostname/[lowercased hostname].yml

Finally the global user overrides are read `configs/overrides.yml`

Tasks needing additinoal configs, or perhaps needing to override a general config,
like `tasks/service/service-runbg.sh` are recommended to first read
`configs/task/service_runbg.yml`, then reread `configs/overrides.yml` to ensure
user overrides are always honored.

### File selection

Not providing a selection when a folder of files, like a recommended content for
/usr/local/bin needs to be copied is inconclusive, and unspecified selections are
rejected.

There are two tags that can be used.

If all content (typically the default) should be copied use: -all-
If no files should be copied use: -none-

If a subset of the content in the source should be copied, list the files selected
without path: myip network-check

Obviusly its up to each and everyone what changes are made, but in general if a minor
change in what files are deployed is the intended change, it is often simpler to just
override a file selection like SPD_FILES_ISH_ALPINE_ULB in configs/global_overrides.yml

## SPD_DEBUG_LEVEL

Standard output selection via lower debug levels

- 0 - Totally quiet, only displaying errors, for integration into other tools
- 1 - Normal progress displayed, commands run with cmd_wrapper will only display errors
- 2 - cmd_wrapper will display output directly to stdout

Higher levels will display more details
