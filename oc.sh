#!/bin/bash

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$HUB_DIR/scripts"

# Source des variables communes
source "$SCRIPTS_DIR/common.sh"

COMMAND="${1:-}"

case "$COMMAND" in
  install)         bash "$SCRIPTS_DIR/cmd-install.sh" "${2:-}" ;;
  init)            bash "$SCRIPTS_DIR/cmd-init.sh" "${2:-}" "${3:-}" ;;
  list)            bash "$SCRIPTS_DIR/cmd-list.sh" ;;
  remove)          bash "$SCRIPTS_DIR/cmd-remove.sh" "${2:-}" ;;
  start)           bash "$SCRIPTS_DIR/cmd-start.sh" "${@:2}" ;;
  deploy)          bash "$SCRIPTS_DIR/cmd-deploy.sh" "${2:-}" "${3:-}" ;;
  skills)          bash "$SCRIPTS_DIR/cmd-skills.sh" "${@:2}" ;;
  agent)           bash "$SCRIPTS_DIR/cmd-agent.sh" "${@:2}" ;;
  sync)            bash "$SCRIPTS_DIR/cmd-sync.sh" ;;
  update)          bash "$SCRIPTS_DIR/cmd-update.sh" ;;
  beads)           bash "$SCRIPTS_DIR/cmd-beads.sh" "${2:-}" "${3:-}" ;;
  help|--help|-h)  bash "$SCRIPTS_DIR/cmd-help.sh" ;;
  "")              bash "$SCRIPTS_DIR/cmd-help.sh" ;;
  *)
    log_error "Commande inconnue : $COMMAND"
    bash "$SCRIPTS_DIR/cmd-help.sh"
    exit 1
    ;;
esac