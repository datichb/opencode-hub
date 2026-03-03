#!/bin/bash
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

log_title "Installation de opencode-hub"

OS=$(detect_os)
log_info "OS détecté : $OS"

# ── Node.js ──────────────────────────────
if ! command -v node &>/dev/null; then
  log_error "Node.js n'est pas installé → https://nodejs.org"
  exit 1
fi
log_success "Node.js $(node -v) détecté"

# ── OpenCode ─────────────────────────────
if ! command -v opencode &>/dev/null; then
  log_info "Installation de OpenCode..."
  npm install -g opencode-ai
  log_success "OpenCode installé"
else
  log_success "OpenCode déjà installé ($(opencode --version 2>/dev/null || echo '?'))"
fi

# ── Beads ────────────────────────────────
if ! command -v beads &>/dev/null; then
  log_info "Installation de Beads..."
  npm install -g @beads/cli
  log_success "Beads installé"
else
  log_success "Beads déjà installé"
fi

# ── Dossiers requis ──────────────────────
mkdir -p "$HUB_DIR/projects"
mkdir -p "$HUB_DIR/skills"
mkdir -p "$HUB_DIR/.opencode/agents"

# ── Fichiers initiaux ────────────────────
if [ ! -f "$PROJECTS_FILE" ]; then
  echo "# Projets" > "$PROJECTS_FILE"
  log_success "projects.md créé"
fi

if [ ! -f "$PATHS_FILE" ]; then
  echo "# Chemins locaux (ignoré par git)" > "$PATHS_FILE"
  log_success "paths.local.md créé"
fi

echo ""
log_success "opencode-hub prêt !"
