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
echo 'export PATH="/path/to/cortex-cli-repo/bin:$PATH"' >> ~/.bashrc
cp -rv man/cortex.1 ~/.local/share/man/man1/cortex.1
sudo mandb 2>/dev/null || true
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

VIM Binding for Node Linking:

```vim
noremap <leader>l :r! cortex pick link 2>/dev/null<CR>
```
