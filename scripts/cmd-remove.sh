#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

PROJECT_ID="${1:-}"
require_project_id "$PROJECT_ID"
PROJECT_ID=$(normalize_project_id "$PROJECT_ID")

# ── Confirmation ──────────────────────────
if ! project_exists "$PROJECT_ID"; then
  log_error "Projet $PROJECT_ID introuvable dans le registre"
  exit 1
fi

read -rp "$(echo -e "  ${YELLOW}⚠${RESET}  Supprimer $PROJECT_ID ? [y/N] ")" confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { log_info "Annulé"; exit 0; }

# ── Supprimer du projects.md ──────────────
# Supprime le bloc ## PROJECT_ID jusqu'au prochain ## ou fin de fichier
command -v perl &>/dev/null || { log_error "perl requis pour cette opération"; exit 1; }
perl -i -0pe 's/\n## \Q'"${PROJECT_ID}"'\E\n.*?(?=\n## |\z)//s' "$PROJECTS_FILE"
log_success "Projet $PROJECT_ID supprimé de projects.md"

# ── Supprimer du paths.local.md ───────────
if path_exists "$PROJECT_ID"; then
  sed -i.bak "/^${PROJECT_ID}=/d" "$PATHS_FILE" && rm -f "${PATHS_FILE}.bak"
  log_success "Chemin supprimé de paths.local.md"
fi

# ── Supprimer de api-keys.local.md ────────
if api_keys_entry_exists "$PROJECT_ID"; then
  remove_api_keys_section "$PROJECT_ID"
  log_success "Clé API supprimée de api-keys.local.md"
fi

echo ""
log_success "$PROJECT_ID retiré du registre"
