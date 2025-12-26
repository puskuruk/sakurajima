#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

 # 🏴 SAKURAJIMA — UPDATE AEROSPACE NATIVE SHORTCUTS
 # Idempotently (re)installs the native shortcuts bridge actions.
 
 if [[ -x "${HOME}/setup/scripts/install-aerospace-native-shortcuts.sh" ]]; then
   exec "${HOME}/setup/scripts/install-aerospace-native-shortcuts.sh"
 fi

 exec "${HOME}/.local/bin/install-aerospace-native-shortcuts"