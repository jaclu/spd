# Simple Posix Deploy

Deploying in place for simple Posix environs, where ansible and similar more
advanced tools do not make much sense since getting to the point of being able
to run it, would enforce a lot of painful touch typing.

Especially since minimalist linux/linux like devices should ideally be self
contained and it should be possible to set them up with minimal preparations
or dependency of deployment servers.

This tool-set achieves this by only depending on a posix shell, and a small
enough number of generic nix tools, that it should hopefully be able to run
out of the box on anything.

It's current primary purpose is to be used for deployments of
iSH environments, so it assumes apk packaging, but it should be possible to
fairly easily adopt it to other systems.

All that should be needed is to have this tool-set mounted on the target system
and run `bin/deploy-ish`

`bin/deploy-ish` has two primary usage cases

-   To restore a fresh install into your preferred state
-   To ensure any config changes are applied to this device

It is not fully idempotent, since some tasks will be redone, but it is in the
sense that repeated runs wont alter anything unless config changes requests so.

### Procedure to setup your environment

I deploy this to iCloud, this way I can use it on any of my devices, and my
configs are maintained if I go to a new device or delete - reinstall
the iSH app. Any host based differences in config I can also setup in advance.

Be aware that iCloud seems to often fail to keep iOS devices in sync, so
please check out the section "Annoyances of iCloud" towards the end of this
document, for some suggestions. Personally I always perform the inbound sync
fix before running this tool on a fresh FS in order to ensure the iCloud
content is up to date.

My procedure on a pristine iSH system (as root)

-   `mount -t ios . /spd` (or any other local path) - Chose where this is located on your devices iCloud in the popup
-   `/spd/bin/deploy-ish` takes one to a couple of minutes, depending on how
    many apks you install. - If user was defined, displays a reminder to set the user password if
    it has not been set yet.
-   Set the user password if requested to do so, following the instructions.

### export / import FS

If I import a pristine FS and mount it, in order to "get back to a clean env"
the procedure is somewhat simpler, since the mount is remembered between
reboots, even if the FS is replaced. The mount point must however exist,
so I typically do a delete / install cycle every now and then:

-   create the mount point dir if it does not exist
-   mount the intended location
-   run `/[MountPoint]/bin/deploy-ish` <br>
    Make sure to hit Ctrl-C before actual deploy starts!
    This way the deploy-ish command is in the history.
-   export the FS
-   run `/[MountPoint]/bin/deploy-ish`

So when I later import this FS, all I need to do after boot-up once I have
a root prompt, is up-arrow and hit enter, and my environment will be restored
with just 2 key-presses!

## Configuration is defined in custom/config

1.  Copy **samples/config** to **custom/config**
1.  Check the **Config.md** in that directory and adjust configs to your
    preferences

Once the config is set up according to your preferences, redeploys will
only require you to run `bin/deploy-ish`, and your iSH will be in your
preferred state. If you have multiple iSH instances you want to set up
slightly differently, you can use hostname to identify which host a given
config is aimed for. See **custom/config/Config.md** for more details.

## File-structure

### bin

The main apps included in this repository.

### scripts

All procedures are separated into task scripts

```
task_XXX.sh     - single task script
m_tasks_XXX.sh  - multiple tasks script
```

Any task can be tested standalone, to ensure its functioning as intended.
This hopefully makes it easier to examine configs and debug issues. In order
to create additional task scripts, just copy one of them, keep the boiler
plate code, and you should have a new task script with minimal fuzz,
test it out and your done! Once it works as intended add the task(-s)
to `bin/deploy-ish`

All 3 "run modes" also can use the option -c This will read the config files,
ie

-   [-h] display help -- For parameters not defined a description is printed, if the param is defined its content will be displayed
-   [no option for this mode] info about what actions will be performed
-   [-x] execute tasks

param example usages

-   can be set as env variables

    `SPD_TIME_ZONE=Europe/London ./task_timezone.sh -h`

    To see that the param was set as intended

    `SPD_TIME_ZONE=Europe/London ./task_timezone.sh -x`

    To run the task with the param(-s) given

-   using config settings

    `./task_timezone.sh -c -h`

    To read config files and display what was found. Please note that config file settings override env settings, this is rather counter intuitive I guess.

### samples

-   config -- should be copied into custom/config
-   additional-restore-tasks -- A sample of a script that does some additional stuff. See `scripts/task_do_extra.sh -h` for more info.
-   additional-as-user -- A sample of a script that is run as a user by the supplied additional-restore-tasks
    This is a subset of my extra_tasks, with any more private items filtered out :) Mostly to give you a general idea of how I use it.

### custom

Ignored by the repository, suggested location for your own local files

#### custom/config

This is a hard-coded path. All other files used by the tasks are defined in your configs, so you can decide a good location for them if **custom** does not fit your needs. Remember to store anything outside the local filesystem, in order for it to be available for other devices or after a reinstall.

If you really want to change it, it is defined in **scripts/tools/read_config.sh**

### files

This is where I store some sample files that might be convenient to deploy, if so indicated in your config. Sample config lines referring to these are present but not activated, to ensure no unintentional deploy happens. You can use your own such files by indicating so in your
config.

-   repositories-Alpine-v3.12 -> /etc/apk/repositories
-   extra_bins/hostname -- See task_hostname.sh for details

### initial-apks

Every now and then I update these, always check the date to see if it is fresh enough to be useful for you.
This directory contains lists of all apks installed out of the box generated by apk-leaves.
This way its simple to see what is needed to get all your stuff, and what you might want to remove in your restore procedure.

## Available tools

### bin/deploy-ish

Restores an iSH env to be setup according to your configurations

### bin/apk-leaves

Displays all leave apks, ie apks that no other apks depend upon. In order to recreate a software deploy all you need to know are the leave nodes. Install them and you will have replicated your env.

Should be fully generic, uses ash shell so should work on a fresh deploy.
Would probably run on any Alpine system, but I haven't tried.

Run with -h param to see options.

At least on my iPad 5th gen this takes like 10 mins to run, so be warned :)

## Annoyances of iCloud

Syncing between devices is pretty flawed at the moment. Both inbound and outbound sync struggles at times.

-   inbound sync -- ie items changed elsewhere.

    To some extent this also applies to MacOS, but there inbound sync is less error prone, but from time to time you will need to do this action if syncing seems out of date, the procedure is the same as for iOS. It seems the only reliable way to ensure your iOS device retrieves changes from other devices is to do a full tree walk, the two methods I have found to solve this so far (from within iSH) are:

    -   `find . > /dev/null`
    -   `ls -laR . > /dev/null` If using ls, ensure you also "display" the dot-files to make sure they are synced, so better keep the -la parameters, even if you don't really care that much about dot-files in every situation.

    Filtering out normal output saves you from drowning in a list of the entire filesystem. Only items in need of sync will be printed, and then they will be synced. Not necessary but you can always run the command again for ease of mind, this time you should see no output.
    Either works, personally I usually use `find`

    -   quicker to type, since I can't rely on aliases at this point.
    -   If I also want to search for some file, I can combine the two tasks by just not piping to /dev/null

-   outbound sync -- ie items changed locally.

    Less error prone, but if it seems something changed on one device isn't picked up by other devices, open Files/Finder on the device where the change has been done, if you see a cloud symbol in the iCloud entry point or in the location where the change was made, usually clicking on the changed file tends to resolve the issue and it is synced into iCloud.

Not sure if this is due to some iSH glitch, or that the status "wait for iOS to sync the file" gets mistaken for a file access error, since iOS doesn't seem to have problems with files not being locally present. For changes on other devices iOS is just as bad and gladly displays the old content instead of forcing an update right away. Eventually iOS will get the new file, but between an update has been "uploaded" and when it is present on the other device iOS will show the old version and be happy about it.

## sshd related things to be aware of

Remember that even if you login using pubkeys, you still need to define a password, since by default sshd does not allow logins to password-less accounts.

It will take a little while for ssshd to be started after a reboot. On my iPad 5th gen, its around 10s but depending on device that will differ. Pretty soon you will have a feeling for how long you need to wait. If you try to early you will be rejected "Connection refused", so you can always repeatedly try to login until it succeeds, with no negative impact.
