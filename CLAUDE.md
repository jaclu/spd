# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Simple Posix Deploy (SPD)** is a minimal-dependency shell-based deployment tool targeting
resource-constrained platforms (iSH/iPad, Termux/Android, Alpine, Debian, Devuan).
It replaces Ansible-style tools where those can't run locally.

The project is currently undergoing a **total rewrite** — functional but incomplete.

## Running Tasks

There is no build step. Tasks are shell scripts run directly:

```bash
./tasks/platform-iSH.sh          # iSH platform deployment
./tasks/fileSystem-Alpine.sh      # Alpine filesystem setup
./tasks/fileSystem-Debian.sh      # Debian filesystem setup
./tasks/fileSystem-Devuan.sh      # Devuan filesystem setup
./tasks/service-autossh.sh        # AutoSSH service
./tasks/service-runbg.sh          # Background runner service
```

On first run, if `configs/` doesn't exist, it is auto-created by copying `config_templates/`.

## Architecture

### Execution Flow

1. A task script sources `tools/prepare-env.sh` (which sources `tools/script-utils.sh`)
2. Config files are loaded in order via `parse_yaml_config_file`:
   - `configs/defaults.yml`
   - `configs/file_systems/{alpine|debian|devuan}.yml` (detected)
   - `configs/platform/{ish|ish_aok|linux|macos}.yml` (detected)
   - `configs/hostname/{lowercased-hostname}.yml` (if present)
   - `configs/overrides.yml` (user overrides, always last)
3. Tasks needing task-specific config also load `configs/task/<task>.yml`,
   then re-load `configs/overrides.yml`
4. Before using a config variable, call `expand_yaml_config_var VARNAME`
   to resolve `{{ OTHER_VAR }}` references

### Key Source Files

- `tools/script-utils.sh` — Core library: platform/FS detection, `is_ish()`,
  `fs_is_alpine()`, `cmd_wrapper()`, `is_yaml_true()`
- `tools/prepare-env.sh` — Deployment functions: `package_install()`,
  `copy_items()`, debug helpers
- `tools/process-yaml-config_file.sh` — Dependency-free YAML parser;
  handles `{{ VAR }}` template expansion
- `tools/service-handler.sh` — Service lifecycle for OpenRC and SysV-init
- `tools/validate-core-io.sh` — iSH fix: validates/repairs `/dev/null` and stdio
- `tasks/*.sh` — Entry points, each handles a specific platform or service

### Config System

- `configs/` is **git-ignored** so repo updates never overwrite local config;
  on first run it is auto-populated from `config_templates/`
- `config_templates/` is the committed baseline — compare against your local
  `configs/` to pick up new config options
- YAML values support `{{ VAR_NAME }}` references to other config vars (expanded lazily)
- Config loading is additive: later files override earlier ones for the same key

### File Deployment (`copy_items`)

File selection is explicit — ambiguous selections are rejected:

- `-all-` — copy everything from the source directory
- `-none-` — skip entirely
- Space-separated filenames — copy only those files

### SPD_ABORT Safety

`SPD_ABORT` in config controls execution:

- `0` — full run (prepare + execute)
- `1` — prepare only
- `2` — don't run (default for macOS to prevent accidents)

### Debug Levels (`SPD_DEBUG_LEVEL`)

- `0` — silent, errors only
- `1` — normal progress (default)
- `2` — verbose; `cmd_wrapper` output goes to stdout
- `3+` — additional internal details

### Service Handler

`SPD_SERVICE_HANDLER` selects the init system:

- `openrc` — uses `rc-update`, runlevels from `SPD_SVC_OPENRC_RUNLVLS`
- `sysv-init` — manages `/etc/rc?.d/` symlinks, levels from `SPD_SVC_SYSV_LVL_START/STOP`

## Shell Style

- Scripts use POSIX sh compatibility (`#!/bin/sh` or `#!/usr/bin/env sh`)
- Use `&&` at end of line for line continuation (not `\`)
- Platform/FS detection via functions from `script-utils.sh` rather than hardcoded checks
