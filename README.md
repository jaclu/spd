# Simple Posix Deploy



Deploying in place for simple Posix environs, where ansible and similar more advanced tools do not make much sense since getting to the point of being able to run it, would enforce a lot of painful touch typing.

Especially since minimalistic linux/linux like devices should ideally be self contained and it should be possible to set them up with minimal preparations or dependency of deployment servers.

This toolset achieves this by only depending on a posix shell, and a small enough number of generic nix tools, that it should hopefully be able to run out of the box on anything.

It's current primary purpose is to be used for deployments of iSH environments, so it asumes apk packaging, but it should be possible to fairly easily adopt it to other systems.

All that should be needed is to have this toolset mounted on the target system and run bin/deploy-ish

<br>


# Procedure to setup your environment

I deploy this to iCloud, this way I can use it on any of my devices, and my configs are maintained
if I go to a new device or delete - reinstall the iSH app. Any host based differences in config I can also setup in advance.

My procedure on a pristine iSH system (as root)

- `mount -t ios . /spd` (or any other local path)
    - Chose where this is located on your devices iCloud in the popup
- `/spd/bin/deploy-ish`  
  takes one to a couple of minutes, depending on how many apks you install.
    - If user was defined, displays a reminder to set the user password if it has not been set yet.
- Set the user password if requested to do so, following the instructions.
- Usage once bin/deploy-ish is completed.
    - default FS
        - For local access, just do su - {your username}
    - AOK FS
        - For local access just exit the current session and login as {username} with or without password, depending on if one was set.
    - Common for both
        - For ssh access, asuming you have activated sshd, as soon as "sshd listening on port: xx" is displayed, you can login using the displayed port. Normally the intended user also must have a password defined.

## export / import FS

If I import a pristine FS and mount it, in ordeer to "get back to a clean env" the procedure is somewhat simpler, since the mount is remembered between reboots, even if the FS is replaced. The mountpoint must however exist, so I typically do a delete / install cycle every now and then:

- create the mount point dir if it does not exist
- mount the intended location
- run `/[MountPoint]/bin/deploy-ish -h` <br>
    This way the deploy-ish command is in the history.
- export the FS
- run `/[MountPoint]/bin/deploy-ish` 

So when I later import this FS, all I need to do after bootup once I have a root prompt, is up-arrow, remove the -h and hit enter, and my environment will be restored with just 4 key-presses!


## Configuration is located in custom/config

 1. Copy **samples/config** to **custom/config**
 1. Check the **Config.md** in that directory and adjust configs to your preferences

Once the config is set up according to your preferences, redeploys will only require you to run 
`bin/deploy-ish`, and your iSH will be in your prefered state. If you have multiple iSH instances you want to set up slightly differently, you can use hostname to identify wich host a given config is aimed for. See **custom/config/Config.md** for more details.



**bin/deploy-ish** has two primary usage cases

- To restore a fresh install into your prefeed state
- To ensure any config changes are applied to this device

It is not fully indempotent, since some tasks will be redone, but it is in the sense that repeated runs wont alter anything unless config changes requests so.

<br>

## Filestructure

### bin

The main apps included in this repo.

### scripts

The actual tasks, offered in a way to make them useable in a standalone fashion. Run any script with param -h to get a full list of options and info.

### samples

- config -- should be copied into custom/config
- additional-restore-tasks -- A sample of a script that does some additional stuff. See `scripts/task_do_extra.sh -h` for more info.
- additional-as-user -- A sample of a script that is run as a user by the supplied additional-restore-tasks
This is a subset of my extra_tasks, with any more private items filtered out :) Mostly to give you a general idea of how I use it.

### custom

Ignored by the repo, suggested location for your own local files

### custom/config

This is a hardcoded path. All other files you refer to in theese files, so you can decide a good location for them if **custom** does not fit your needs. Remember to store anything outside the local filesystem, in order for it to be available for other devices or after a reinstall.


### files

This is where I store some sample files that might be convenient to deploy, if so indicated in your config. Sample config lines refering to theese are present but not activated, to ensure no unintentional deploy happens. You can use your own such files by indicating so in your
config.

 * etc_inittab -> /etc/inittab
 * repositories-Alpine-v3.12 -> /etc/apk/repositories

 * services/runbg -- See task_runbg.sh for details
 * extra_bins/hostname -- See task_hostname.sh for details
 * extra_bins/dev_null-fix -- Recreates /dev/null if it is broken



  

### initial-apks

Every now and then I update theese, always check the date to see if it is fresh enough to be usefull for you.
This directory contains lists of all apks installed out of the box generated by apk-leaves.
This way its simple to see what is needed to get all your stuff, and what you might want to remove in your restore procedure.

## Available tools

### bin/apk-leaves

Displays all leave apks, ie apks that no other apks depend upon. In order to recreate a software deploy all you need to know are the leave nodes. Install them and you will have replicated your env.

Should be fully generic, uses ash shell so should work on a fresh deploy.
Would probably run on any Alpine system, but I havent tried.

Run with -h param to see options.

### bin/deploy-ish

Restores an iSH env to be setup according to your preferences

<br>

## Scripts

All procedures are separated into task scripts

```
task_XXX.sh     - single task script
m_tasks_XXX.sh  - multiple tasks script
```

Running a script with param -h will give info both about command line options, what tasks it performs, and what env variables controls its behaviour.

This means that any task can be tested standalone, to ensure its functioning as intended. This hopefully makes it easier to create additional tasks, just copy one of them, keep the boiler plate code, and you should have a new task script with minimal fuzz, just add suitable config variables, test it out and your done!

Remember that any script run without -h will perform all tasks it contains based on the variables that it finds.

<br>

<br>

## sshd related things to be aware of

Remember that even if you login using pubkeys, you still need to define a password, since by default sshd does not allow logins to passwordless accounts.

For both filesystems it will take a little while for ssshd to be started after a reboot. On my iPad 5th gen, its arround 10-15s but depending on device that will differ. Pretty soon you will have a feeling for how long you need to wait. If you try to early you will be rejected "Connection refused", so you can always repeatedly try to login until it succeeds, with no negative impact.
