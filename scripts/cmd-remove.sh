#!/bin/bash
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

PROJECT_ID="${1:-}"
require_project_id "$PROJECT_ID"
PROJECT_ID=$(echo "$PROJECT_ID" | tr '[:lower:]' '[:upper:]')

# ── Confirmation ──────────────────────────
if ! project_exists "$PROJECT_ID"; then
  log_error "Projet $PROJECT_ID introuvable dans le registre"
  exit 1
fi

read -rp "$(echo -e "  ${YELLOW}⚠${RESET}  Supprimer $PROJECT_ID ? [y/N] ")" confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { log_info "Annulé"; exit 0; }

# ── Supprimer du projects.md ──────────────
# Supprime le bloc ## PROJECT_ID jusqu'au prochain ## ou fin de fichier
perl -i -0pe "s/\n## ${PROJECT_ID}\n.*?(?=\n## |\z)//s" "$PROJECTS_FILE"
log_success "Projet $PROJECT_ID supprimé de projects.md"

# ── Supprimer du paths.local.md ───────────
if path_exists "$PROJECT_ID"; then
  sed -i "/^${PROJECT_ID}=/d" "$PATHS_FILE"
  log_success "Chemin supprimé de paths.local.md"
fi

echo ""
log_success "$PROJECT_ID retiré du registre"
