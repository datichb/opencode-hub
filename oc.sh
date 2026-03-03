#!/bin/bash

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$HUB_DIR/scripts"

# Source des variables communes
source "$SCRIPTS_DIR/common.sh"

COMMAND="${1:-}"

case "$COMMAND" in
  install)        bash "$SCRIPTS_DIR/cmd-install.sh" ;;
  init)           bash "$SCRIPTS_DIR/cmd-init.sh" "${2:-}" "${3:-}" ;;
  list)           bash "$SCRIPTS_DIR/cmd-list.sh" ;;
  remove)         bash "$SCRIPTS_DIR/cmd-remove.sh" "${2:-}" ;;
  start)          bash "$SCRIPTS_DIR/cmd-start.sh" "${2:-}" ;;
  sync)           bash "$SCRIPTS_DIR/cmd-sync.sh" ;;
  update)         bash "$SCRIPTS_DIR/cmd-update.sh" ;;
  help|--help|-h) bash "$SCRIPTS_DIR/cmd-help.sh" ;;
  "")             bash "$SCRIPTS_DIR/cmd-help.sh" ;;
  *)
    log_error "Commande inconnue : $COMMAND"
    bash "$SCRIPTS_DIR/cmd-help.sh"
    exit 1
    ;;
esac