#!/bin/bash
# Gestion des cibles de déploiement par projet.
# Usage : oc target <sous-commande> [args]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
source "$LIB_DIR/target-picker.sh"

##
# Affiche les cibles configurées pour un projet.
# @param {string} $1 — PROJECT_ID
##
cmd_info() {
  local raw_id="${1:-}"
  if [ -z "$raw_id" ]; then
    log_error "Usage : oc target info <PROJECT_ID>"
    exit 1
  fi

  local id
  id=$(normalize_project_id "$raw_id")
  if ! project_exists "$id"; then
    log_error "Projet $id introuvable → ./oc.sh list"
    exit 1
  fi

  local current
  current=$(get_project_targets "$id")
  echo ""
  if [ -z "$current" ]; then
    echo -e "  Cibles pour ${BOLD}$id${RESET} : (toutes les cibles actives de hub.json)"
  else
    echo -e "  Cibles pour ${BOLD}$id${RESET} : $current"
  fi
  echo ""
}

##
# Sélectionne les cibles de déploiement pour un projet donné.
# Lance le picker interactif et écrit le résultat dans projects.md.
# @param {string} $1 — PROJECT_ID
##
cmd_select() {
  local raw_id="${1:-}"
  if [ -z "$raw_id" ]; then
    log_error "Usage : oc target select <PROJECT_ID>"
    exit 1
  fi

  local id
  id=$(normalize_project_id "$raw_id")
  if ! project_exists "$id"; then
    log_error "Projet $id introuvable → ./oc.sh list"
    exit 1
  fi

  local current
  current=$(get_project_targets "$id")
  log_title "Sélection des cibles — $id"
  if [ -z "$current" ]; then
    log_info "Sélection actuelle : toutes les cibles actives (hub.json)"
  else
    log_info "Sélection actuelle : ${current}"
  fi
  echo ""

  PICKED_TARGETS=""
  _pick_project_targets "${current:-all}"

  # Normaliser : "all" → vide (= fallback hub.json)
  local new_targets="$PICKED_TARGETS"
  [ "$new_targets" = "all" ] && new_targets=""

  if [ "$new_targets" = "$current" ]; then
    log_info "Aucune modification."
    return
  fi

  if [ -z "$new_targets" ]; then
    # Supprimer le champ Targets → retour au comportement global
    _set_project_targets "$id" "all"
    echo ""
    log_success "Cibles réinitialisées pour $id → toutes les cibles actives seront utilisées"
  else
    _set_project_targets "$id" "$new_targets"
    echo ""
    local count
    count=$(echo "$new_targets" | tr ',' '\n' | grep -v '^$' | wc -l | tr -d ' ')
    log_success "$count cible(s) sélectionnée(s) pour $id : $new_targets"
  fi

  # Proposer un redéploiement immédiat
  echo ""
  read -rp "Redéployer maintenant ? [Y/n] : " redeploy </dev/tty
  redeploy="${redeploy:-Y}"
  if [[ "$redeploy" =~ ^[Yy]$ ]]; then
    exec "$HUB_DIR/oc.sh" deploy all "$id"
  else
    log_info "Déployer plus tard : ./oc.sh deploy all $id"
  fi
}

# ── DISPATCH ─────────────────────────────────────────────────────────────────

SUBCOMMAND="${1:-}"
shift 2>/dev/null || true

case "$SUBCOMMAND" in
  info)    cmd_info "$@" ;;
  select)  cmd_select "$@" ;;
  *)
    echo -e "${BOLD}oc target — Gestion des cibles de déploiement par projet${RESET}"
    echo ""
    echo "  info <PROJECT_ID>     Afficher les cibles configurées pour un projet"
    echo "  select <PROJECT_ID>   Choisir les cibles de déploiement pour un projet"
    echo ""
    echo -e "${BOLD}Exemples :${RESET}"
    echo "  ./oc.sh target info MY-PROJECT"
    echo "  ./oc.sh target select MY-PROJECT"
    echo ""
    echo -e "${BOLD}Cibles disponibles :${RESET}"
    echo "  opencode     → .opencode/agents/"
    echo "  claude-code  → .claude/agents/"
    echo "  vscode       → .vscode/prompts/"
    echo ""
    echo "  Par défaut (si non configuré), les cibles actives de hub.json sont utilisées."
    echo ""
    ;;
esac
