#!/usr/bin/env bash
# Bash completion for sakurajima-apps
# Dynamically loads app names from the catalog

_sakurajima_apps_completion() {
  local cur prev catalog
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  catalog="$HOME/setup/configs/apps-catalog.json"

  # First level: commands
  local commands="list install search info running stop remove logs"

  # Second level: subcommands
  local list_types="docker brew all"
  local install_types="docker brew"

  case "${COMP_CWORD}" in
    1)
      # Complete main commands
      COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
      return 0
      ;;

    2)
      # Complete subcommands based on command
      case "${COMP_WORDS[1]}" in
        list)
          COMPREPLY=( $(compgen -W "$list_types" -- "$cur") )
          return 0
          ;;

        install)
          COMPREPLY=( $(compgen -W "$install_types" -- "$cur") )
          return 0
          ;;
      esac
      ;;

    3)
      # Complete app names based on command and subcommand
      if [[ ! -f "$catalog" ]]; then
        return 1
      fi

      case "${COMP_WORDS[1]}" in
        install)
          case "${COMP_WORDS[2]}" in
            docker)
              # Get Docker app slugs
              local docker_apps=$(jq -r '.docker[].slug' "$catalog" 2>/dev/null)
              COMPREPLY=( $(compgen -W "$docker_apps" -- "$cur") )
              return 0
              ;;

            brew)
              # Get Homebrew app slugs
              local brew_apps=$(jq -r '.homebrew[].slug' "$catalog" 2>/dev/null)
              COMPREPLY=( $(compgen -W "$brew_apps" -- "$cur") )
              return 0
              ;;
          esac
          ;;

        stop|remove|logs)
          # Get running container names (remove sakurajima- prefix)
          local containers=$(docker ps --filter 'name=sakurajima-' --format '{{.Names}}' 2>/dev/null | sed 's/sakurajima-//')
          COMPREPLY=( $(compgen -W "$containers" -- "$cur") )
          return 0
          ;;

        search|info)
          # All apps for search/info
          local all_apps=$(jq -r '.docker[].slug, .homebrew[].slug' "$catalog" 2>/dev/null)
          COMPREPLY=( $(compgen -W "$all_apps" -- "$cur") )
          return 0
          ;;
      esac
      ;;
  esac
}

complete -F _sakurajima_apps_completion sakurajima-apps
