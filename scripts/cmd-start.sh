#!/bin/bash
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

PROJECT_ID="${1:-}"
PROMPT="${2:-}"

# ── Sélection interactive si pas d'ID ─────
if [ -z "$PROJECT_ID" ]; then
  mapfile -t ids < <(grep "^## " "$PROJECTS_FILE" | sed 's/^## //')

  if [ ${#ids[@]} -eq 0 ]; then
    log_error "Aucun projet enregistré → ./oc.sh init"
    exit 1
  fi

  echo -e "${BOLD}Choisir un projet :${RESET}"
  echo ""
  for i in "${!ids[@]}"; do
    printf "  ${BLUE}%d${RESET}) %s\n" "$((i+1))" "${ids[$i]}"
  done
  echo ""
  read -rp "  Numéro : " choice
  PROJECT_ID="${ids[$((choice-1))]}"
fi

PROJECT_ID=$(echo "$PROJECT_ID" | tr '[:lower:]' '[:upper:]')

# ── Validations ───────────────────────────
if ! project_exists "$PROJECT_ID"; then
  log_error "Projet $PROJECT_ID introuvable → ./oc.sh list"
  exit 1
fi

PROJECT_PATH=$(get_project_path "$PROJECT_ID")
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

if [ -z "$PROJECT_PATH" ]; then
  log_error "Aucun chemin local pour $PROJECT_ID → ./oc.sh init $PROJECT_ID"
  exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
  log_error "Dossier introuvable : $PROJECT_PATH"
  exit 1
fi

# ── Lancement via adaptateur ─────────────
log_info "Projet   : $PROJECT_ID"
log_info "Dossier  : $PROJECT_PATH"

source "$SCRIPTS_DIR/lib/adapter-manager.sh"
default_target=$(get_default_target)
log_info "Cible    : $default_target"
echo ""

load_adapter "$default_target"
adapter_start "$PROJECT_PATH" "$PROMPT"
