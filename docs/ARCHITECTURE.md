# Cortex-CLI architecture notes

This document is for readers who are new to Bash scripting.

## Why the code is split across many files

Bash files can become hard to read if they grow too large. Cortex-CLI uses small
modules so each file has a single responsibility. The entrypoint (`bin/cortex`)
loads the modules and calls a command dispatcher.

## Data model

A Cortex instance is a directory with:

- `.cortex/schema.yml` (configuration)
- `.cortex/index/` (derived caches)
- `README.md` + `metadata.yml` at the root
- node directories `ROOT/<NODE_ID>/` containing their own README + metadata.

## How commands are structured

- `cmd_*.sh` files parse CLI arguments and show help.
- `lib/*.sh` files implement the underlying primitives.

This pattern keeps argument parsing separate from the filesystem logic.
