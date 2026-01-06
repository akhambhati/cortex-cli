# Bash completion for cortex
# Source this file from ~/.bashrc or install to /etc/bash_completion.d/cortex

_cortex_find_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.cortex" ]]; then
      printf "%s" "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

_cortex_get_root_from_words() {
  local i
  for ((i=1; i<COMP_CWORD; i++)); do
    if [[ "${COMP_WORDS[i]}" == "--root" && -n "${COMP_WORDS[i+1]:-}" ]]; then
      printf "%s" "${COMP_WORDS[i+1]}"
      return 0
    fi
  done
  if [[ -n "${CORTEX_ROOT:-}" ]]; then
    printf "%s" "$CORTEX_ROOT"
    return 0
  fi
  _cortex_find_root && return 0
  printf "%s" "$PWD"
}

_cortex_node_ids() {
  local root="$1"
  local f="$root/.cortex/index/nodes.tsv"
  if [[ -f "$f" ]]; then
    tail -n +2 "$f" | cut -f1
  else
    # fallback: fs scan
    command ls -1 "$root" 2>/dev/null | grep -E '^[A-Za-z0-9]+$'
  fi
}

_cortex_complete() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  # Determine cortex root from words/env/cwd.
  local root; root="$(_cortex_get_root_from_words)"

  # Global flags (supported anywhere *before* the command).
  local common="--root --help -h"
  local cmds="init node asset index validate pick help"

  # If completing the value for --root, offer directories.
  if [[ "$prev" == "--root" ]]; then
    COMPREPLY=( $(compgen -d -- "$cur") )
    return 0
  fi

  # Build a compact view of the argv that ignores global flags and their arguments.
  # This lets completions work no matter where --root appears.
  local -a args=()
  local i
  for ((i=1; i<COMP_CWORD; i++)); do
    case "${COMP_WORDS[i]}" in
      --root)
        # skip its argument if present
        ((i++))
        ;;
      --help|-h)
        ;;
      --*)
        # unknown global flag: ignore (keeps completion robust)
        ;;
      -*)
        ;;
      *)
        args+=("${COMP_WORDS[i]}")
        ;;
    esac
  done

  # No command yet: complete either global flags or top-level commands.
  if [[ ${#args[@]} -eq 0 ]]; then
    if [[ "$cur" == -* ]]; then
      COMPREPLY=( $(compgen -W "$common" -- "$cur") )
    else
      COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    fi
    return 0
  fi

  local cmd="${args[0]}"
  local sub="${args[1]:-}"
  local sub2="${args[2]:-}"
  local argc=${#args[@]}

  # Helper: suggest node IDs (from index, if present)
  _cortex_suggest_ids() {
    COMPREPLY=( $(compgen -W "$(_cortex_node_ids "$root")" -- "$cur") )
  }

  case "$cmd" in
    init)
      # cortex init [--help]
      COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      return 0
      ;;

    validate)
      # cortex validate [--help]
      COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      return 0
      ;;

    index)
      # cortex index build|show
      if [[ $argc -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "build show --help -h" -- "$cur") )
        return 0
      fi
      case "$sub" in
        show)
          if [[ $argc -eq 2 ]]; then
            COMPREPLY=( $(compgen -W "nodes links assets --help -h" -- "$cur") )
            return 0
          fi
          ;;
      esac
      COMPREPLY=()
      return 0
      ;;

    node)
      # cortex node new|edit|list|rm|touch|title
      if [[ $argc -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "new edit list rm touch title --help -h" -- "$cur") )
        return 0
      fi

      case "$sub" in
        edit)
          # cortex node edit ID [FILE]
          if [[ $argc -eq 2 ]]; then
            _cortex_suggest_ids; return 0
          fi
          if [[ $argc -eq 3 ]]; then
            # Complete file names within the node directory.
            local id="${args[2]}"
            if [[ -n "$id" && -d "$root/$id" ]]; then
              COMPREPLY=( $(compgen -f -- "$root/$id/$cur") )
              # strip root prefix from suggestions for nicer UX
              local j
              for ((j=0; j<${#COMPREPLY[@]}; j++)); do
                COMPREPLY[j]="${COMPREPLY[j]#$root/$id/}"
              done
              return 0
            fi
          fi
          ;;

        rm|touch)
          # cortex node rm ID  | cortex node touch ID
          if [[ $argc -eq 2 ]]; then
            _cortex_suggest_ids; return 0
          fi
          ;;

        list)
          # cortex node list [--format FMT] [--access public|private]
          case "$prev" in
            --access)
              COMPREPLY=( $(compgen -W "public private" -- "$cur") )
              return 0
              ;;
          esac
          COMPREPLY=( $(compgen -W "--format --access --help -h" -- "$cur") )
          return 0
          ;;

        title)
          # cortex node title get|set ...
          if [[ $argc -eq 2 ]]; then
            COMPREPLY=( $(compgen -W "get set --help -h" -- "$cur") )
            return 0
          fi
          case "$sub2" in
            get)
              if [[ $argc -eq 3 ]]; then
                _cortex_suggest_ids; return 0
              fi
              ;;
            set)
              if [[ $argc -eq 3 ]]; then
                _cortex_suggest_ids; return 0
              fi
              ;;
          esac
          ;;

        new)
          # cortex node new --title "..." [--type T] [--state S] [--access public|private] [--id ID]
          case "$prev" in
            --access)
              COMPREPLY=( $(compgen -W "public private" -- "$cur") )
              return 0
              ;;
            --id|--title|--type|--state)
              COMPREPLY=()
              return 0
              ;;
          esac
          if [[ "$cur" == -* ]]; then
            COMPREPLY=( $(compgen -W "--title --type --state --access --id --help -h" -- "$cur") )
            return 0
          fi
          COMPREPLY=()
          return 0
          ;;
      esac

      COMPREPLY=()
      return 0
      ;;

    asset)
      # cortex asset list|attach|rm
      if [[ $argc -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "list attach rm --help -h" -- "$cur") )
        return 0
      fi
      case "$sub" in
        list|attach|rm)
          if [[ $argc -eq 2 ]]; then
            _cortex_suggest_ids; return 0
          fi
          if [[ "$sub" == "rm" && $argc -eq 3 ]]; then
            # Suggest asset filenames for the given node id.
            local id="${args[2]}"
            if [[ -n "$id" && -d "$root/$id" ]]; then
              local adir="$root/$id/assets"
              if [[ -d "$adir" ]]; then
                COMPREPLY=( $(compgen -W "$(command ls -1 "$adir" 2>/dev/null)" -- "$cur") )
                return 0
              fi
            fi
          fi
          ;;
      esac
      COMPREPLY=()
      return 0
      ;;

    pick)
      # cortex pick edit|rm|link
      if [[ $argc -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "edit rm link --help -h" -- "$cur") )
        return 0
      fi
      
			COMPREPLY=()
      return 0
      ;;

    help)
      COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
      return 0
      ;;
  esac

  COMPREPLY=()
  return 0
}

complete -F _cortex_complete cortex
