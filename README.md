# Simple Posix Deploy

Deploy tool with minimal dependencies, to run it initially only needs posix any
dependencies for spd itself is handled from within.
Suitable for deployment of minimalistic environments, such as iSH/Termux etc.
Primary purpose is to be used instead of Ansible etc, on limited environments where
it can't run locally, or the task over head makes it unpractical to run from a
deploy sever.

advanced tools are not practically usable. Typical reasons:

- Can't be run locally on the target
- Overhead per remote task is so high, that a deploy "takes for ever"
- Setting up the target to run the deploy tool is so complex that it in it self
  becomes a major pain.

spd initially only depends on /bin/sh, any additional tools needed like
grep/awk/sed etc will be scanned for, if possible be installed, otherwise
reported as a failed dependency in need of manual handling.

If this is deployed on a mountable file system, be it iCloud, USB-stick etc

All that should be needed is to have this tool-set mounted on the target system
and run `bin/deploy`

## SPD modularity

Main workflow is to first set up the env, reading relevant configs and overrides,
then gathering all tasks in the tasks list and executing them one by one

- Gather defaults
- Override with custom configs
- Ensure all listed tasks was found
- Execute task list one by one
- Update global state of he deploy

Add a passive option, to just list what tasks would be done

### tasks

- Simple to detect config params needed
- public functions
  - task_prepare - setting up any environmental dependencies in order for task_execute
    to be executed, such as installing dependencies if need be etc
  - task_execute - perform the actual task
  - task_cleanup - cleanup of any temp files etc created by the task
  - task_abort - restoration of all files/changes a task did, if unable to complete

## spd_dependency_issue

1 - neither install or remove can be done
2 - remove but not install can be done

## Config files

Configs are assumed to be in configs/
The repo has generic sample congis in config_templates/ when any task is started
and configs/ does not exist config_templates/ are copied there for initial usage.
configs/ is in .gitignore, and if it exists it is never touched. So any changes
there will never be meddled with if the repo is updated.

## SPD_DEBUG_LEVEL

Standard output selection lower debug levels

- 0 - Toally quiet, only displaying errors, for integration into other tools
- 1 - Normal progress displayed, commands run wih cmd_wrapper will only display errors
- 2 - cmd_wrapper will display output directly to stdout

Higher levels will display more details
