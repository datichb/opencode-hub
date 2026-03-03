#!/bin/bash
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

log_title "Mise à jour des outils"

log_info "Mise à jour OpenCode..."
if npm update -g opencode-ai; then
  log_success "OpenCode mis à jour"
else
  log_warn "Échec de la mise à jour OpenCode"
fi

log_info "Mise à jour Beads..."
if npm update -g @beads/cli; then
  log_success "Beads mis à jour"
else
  log_warn "Échec de la mise à jour Beads"
fi

echo ""
log_success "Mise à jour terminée"
