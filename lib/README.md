# Cortex-CLI library modules

Cortex-CLI is split into small Bash modules under `lib/`.

## How the CLI works

1. `bin/cortex` sources the modules in `lib/`.
2. It dispatches to a command handler (`lib/cmd_*.sh`) based on the first CLI argument.
3. Command handlers parse arguments and call lower-level library functions.

## Key modules

- `common.sh`  
  Generic helpers (errors, atomic writes, root detection).

- `schema.sh`  
  Reads `.cortex/schema.yml` and exposes small getters.

- `time.sh`  
  Timestamp formatting helpers used when writing metadata.

- `node.sh`  
  Create/edit/delete nodes and manage node metadata.

- `asset.sh` + `assets_policy.sh`  
  Attach/list/remove node assets using the schema policy.

- `index.sh`  
  Build and query `.cortex/index/*.tsv` derived indexes.

- `links.sh`  
  Parse/resolve link syntax for validation and indexing.

- `validate.sh`  
  Read-only verification that the instance conforms to the schema.

- `pick.sh`  
  Interactive picker using fzf + rg + bat.

- `help.sh`  
  Loads user help text from `docs/help/*.txt`.

## Indexes

Indexes are stored in `.cortex/index/` as TSV files so they can be inspected with
standard Unix tools (`awk`, `cut`, `column`, etc.). They are treated as derived
caches: they can be rebuilt at any time.
