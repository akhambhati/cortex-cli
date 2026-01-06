# Cortex-CLI

A small, terminal-first CLI for a **Cortex** personal knowledge base.

This implementation is intentionally **mechanical**:
- Fixed filesystem layout
- A small, explicit `.cortex/schema.yml` controls *rules and defaults* (ID policy, metadata, link parsing, indexing policy)
- Indexes are derived caches in `.cortex/index/`

## Layout

```
MY_CORTEX/
  .cortex/
    schema.yml
    index/
      nodes.tsv
      links.tsv
      assets.tsv
      stamp.yml
    locks/
  README.md
  metadata.yml
  NODE_ID/
    README.md
    metadata.yml
    assets/
```

## Install

Linux:

```bash
sudo install -m 0755 bin/cortex /usr/local/bin/cortex
sudo install -m 0644 man/cortex.1 /usr/local/share/man/man1/cortex.1
sudo mandb 2>/dev/null || true
```

Termux:

```bash
install -m 0755 bin/cortex $PREFIX/bin/cortex
```

## Quick start

```bash
cortex init /path/to/MY_CORTEX --title "Holocron"
cd /path/to/MY_CORTEX

ID=$(cortex node new --title "My first node")
cortex node edit "$ID"
cortex index show nodes
cortex validate
```

## Help

```bash
cortex --help
cortex node --help
cortex node new --help
```


## Bash completion

Source the completion script:

```bash
source /path/to/cortex/completions/cortex.bash
```

Or install it system-wide (Linux):

```bash
sudo cp completions/cortex.bash /etc/bash_completion.d/cortex
```

## Optional dependencies

Some commands use external tools if available:
- `fzf` for `cortex pick`
- `ripgrep (rg)` for `cortex search`

