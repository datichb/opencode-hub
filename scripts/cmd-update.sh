#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
source "$LIB_DIR/adapter-manager.sh"

log_title "Mise à jour des outils"

while IFS= read -r target; do
  load_adapter "$target"
  adapter_update
done < <(get_active_targets)

log_info "Mise à jour Beads (bd)..."
if command -v bd &>/dev/null; then
  if command -v brew &>/dev/null && brew list bd &>/dev/null 2>&1; then
    brew upgrade bd && log_success "Beads mis à jour via Homebrew" \
      || log_warn "Échec mise à jour Beads — déjà à jour ou erreur Homebrew"
  else
    log_warn "bd installé mais pas via Homebrew — mise à jour manuelle requise"
    log_info "  → https://beads.sh ou via votre gestionnaire de paquets"
  fi
else
  log_warn "bd non installé — lancez : oc install"
fi

# ── Skills externes ───────────────────────────────────────────────────────────
EXTERNAL_SOURCES="$HUB_DIR/skills/external/.sources.json"
SKILLS_UPDATED=false
if [ -f "$EXTERNAL_SOURCES" ] && [ -s "$EXTERNAL_SOURCES" ] && [ "$(cat "$EXTERNAL_SOURCES")" != '{}' ]; then
  echo ""
  log_info "Mise à jour des skills externes..."
  bash "$SCRIPTS_DIR/cmd-skills.sh" update && SKILLS_UPDATED=true
else
  log_info "Aucun skill externe enregistré — étape ignorée."
fi

echo ""
log_success "Mise à jour terminée"

# ── Proposer un sync si des skills ont été mis à jour ─────────────────────────
if [ "$SKILLS_UPDATED" = true ]; then
  echo ""
  log_warn "Des skills ont été mis à jour — les agents déployés dans vos projets peuvent être obsolètes."
  echo ""
  read -rp "  Lancer oc sync pour redéployer sur tous les projets ? [Y/n] : " sync_now
  if [[ "${sync_now:-Y}" =~ ^[Yy]$ ]]; then
    bash "$SCRIPTS_DIR/cmd-sync.sh"
  else
    log_info "Redéployer manuellement : ./oc.sh sync"
  fi
fi
