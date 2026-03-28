#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

PROJECT_ID="${1:-}"
PROJECT_PATH="${2:-}"

# ── Saisie interactive si pas d'arguments ─
if [ -z "$PROJECT_ID" ]; then
  echo -e "${BOLD}Initialisation d'un projet${RESET}"
  echo ""
  read -rp "  PROJECT_ID (ex: MON-APP) : " PROJECT_ID
fi

PROJECT_ID=$(normalize_project_id "$PROJECT_ID")

# Validation du format PROJECT_ID : lettres, chiffres, tirets et underscores uniquement
if ! echo "$PROJECT_ID" | grep -qE '^[A-Z0-9_-]+$'; then
  log_error "PROJECT_ID invalide : '$PROJECT_ID'"
  log_info  "Caractères autorisés : lettres, chiffres, tirets (-) et underscores (_). Pas d'espaces ni de slashes."
  exit 1
fi

if [ -z "$PROJECT_PATH" ]; then
  read -rp "  Chemin local (ex: ~/workspace/mon-app) : " PROJECT_PATH
fi

# Expand ~ manuellement
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

# ── Validations ───────────────────────────
if project_exists "$PROJECT_ID"; then
  log_warn "Le projet $PROJECT_ID existe déjà dans le registre"
else
  # Infos supplémentaires
  read -rp "  Nom complet : " PROJECT_NAME
  read -rp "  Stack (ex: Vue 3 + Laravel) : " PROJECT_STACK
  read -rp "  Labels Beads (ex: feature,fix,front,back) : " PROJECT_LABELS

  # Choix du tracker externe (optionnel)
  echo ""
  echo -e "  ${BOLD}Tracker externe (optionnel) :${RESET}"
  echo "    1) Aucun"
  echo "    2) Jira"
  echo "    3) GitLab"
  echo ""
  read -rp "  Choix [1] : " tracker_choice
  case "${tracker_choice:-1}" in
    2) PROJECT_TRACKER="jira" ;;
    3) PROJECT_TRACKER="gitlab" ;;
    *)  PROJECT_TRACKER="none" ;;
  esac

  # Ajouter dans projects.md
  cat >> "$PROJECTS_FILE" <<EOF

## $PROJECT_ID
- Nom : ${PROJECT_NAME:-$PROJECT_ID}
- Stack : ${PROJECT_STACK:-N/A}
- Board Beads : $PROJECT_ID
- Tracker : ${PROJECT_TRACKER}
- Labels : ${PROJECT_LABELS:-feature,fix}
EOF

  log_success "Projet $PROJECT_ID ajouté dans projects.md"

  # Proposer la configuration du tracker si non-none
  if [ "$PROJECT_TRACKER" != "none" ]; then
    echo ""
    read -rp "  Configurer $PROJECT_TRACKER maintenant ? [Y/n] : " setup_now
    if [[ "${setup_now:-Y}" =~ ^[Yy]$ ]]; then
      bash "$SCRIPTS_DIR/cmd-beads.sh" tracker setup "$PROJECT_ID"
    else
      log_info "Configurer plus tard : ./oc.sh beads tracker setup $PROJECT_ID"
    fi
  fi
fi

# ── Chemin local ──────────────────────────
if path_exists "$PROJECT_ID"; then
  log_warn "Chemin déjà enregistré pour $PROJECT_ID"
else
  if [ ! -d "$PROJECT_PATH" ]; then
    log_warn "Le dossier $PROJECT_PATH n'existe pas encore"
  fi
  echo "${PROJECT_ID}=${PROJECT_PATH}" >> "$PATHS_FILE"
  log_success "Chemin enregistré dans paths.local.md"
fi

echo ""
log_success "Projet $PROJECT_ID initialisé → ./oc.sh start $PROJECT_ID"
