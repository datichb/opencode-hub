#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# opencode-hub — Script d'installation
#
# Usage :
#   curl -fsSL https://raw.githubusercontent.com/datichb/opencode-hub/main/install.sh | bash
#   ou : bash install.sh
#
# Ce script :
#   1. Clone ou met à jour le repo dans ~/.opencode-hub
#   2. Vérifie et installe les dépendances (jq, Node.js/npm, opencode, bun)
#   3. Crée l'alias 'oc' dans le fichier rc shell de l'utilisateur
#   4. Initialise les fichiers de config locaux
#   5. Lance oc install pour finaliser la configuration
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ─────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────
REPO_URL="https://github.com/datichb/opencode-hub.git"
INSTALL_DIR="${OPENCODE_HUB_DIR:-$HOME/.opencode-hub}"

# ─────────────────────────────────────────
# COLORS & LOGGERS
# ─────────────────────────────────────────
RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[94m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

log_info()    { echo -e "${BLUE}◆${RESET}  $*"; }
log_success() { echo -e "${GREEN}◆${RESET}  $*"; }
log_warn()    { echo -e "${YELLOW}◆${RESET}  $*" >&2; }
log_error()   { echo -e "${RED}◆${RESET}  $*" >&2; }
log_title()   { echo -e "\n${BOLD}$*${RESET}"; }

_intro() { echo ""; echo -e "${BOLD}◆  $*${RESET}"; echo -e "${DIM}│${RESET}"; }
_outro() { echo -e "${DIM}└${RESET}  $*"; echo ""; }

# ─────────────────────────────────────────
# OS DETECTION
# ─────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    *)       echo "unknown" ;;
  esac
}

OS=$(detect_os)

# ─────────────────────────────────────────
# ÉTAPE 1 — CLONE / UPDATE DU REPO
# ─────────────────────────────────────────
_intro "Récupération de opencode-hub"

if [ -d "$INSTALL_DIR/.git" ]; then
  log_info "Mise à jour du repo existant dans $INSTALL_DIR ..."
  if git -C "$INSTALL_DIR" pull --ff-only --quiet; then
    log_success "Repo mis à jour (main)"
  else
    log_warn "Échec du pull — repo conservé tel quel"
  fi
else
  if [ -d "$INSTALL_DIR" ] && [ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
    log_warn "Le dossier $INSTALL_DIR existe mais n'est pas un repo git."
    read -rp "  Supprimer et recloner ? [y/N] : " _overwrite
    if [[ "${_overwrite:-N}" =~ ^[Yy]$ ]]; then
      rm -rf "$INSTALL_DIR"
    else
      log_error "Installation annulée — choisir un autre dossier via OPENCODE_HUB_DIR=/chemin bash install.sh"
      exit 1
    fi
  fi
  log_info "Clonage du repo dans $INSTALL_DIR ..."
  git clone --quiet "$REPO_URL" "$INSTALL_DIR" \
    && log_success "Repo cloné avec succès"
fi

_outro "Sources disponibles dans $INSTALL_DIR"

# ─────────────────────────────────────────
# ÉTAPE 2 — DÉPENDANCES
# ─────────────────────────────────────────
_intro "Vérification des dépendances"

# ── git ──────────────────────────────────
if ! command -v git &>/dev/null; then
  log_error "git est requis mais introuvable. Installer git puis relancer ce script."
  exit 1
fi
log_success "git $(git --version | awk '{print $3}')"

# ── jq ───────────────────────────────────
if ! command -v jq &>/dev/null; then
  log_warn "jq non détecté — dépendance critique"
  if [ "$OS" = "macos" ] && command -v brew &>/dev/null; then
    read -rp "  Installer jq via Homebrew ? [Y/n] : " _jq_choice
    if [[ "${_jq_choice:-Y}" =~ ^[Yy]$ ]]; then
      if brew install jq --quiet; then
        log_success "jq installé"
      else
        log_error "Échec installation jq — installer manuellement : brew install jq"
        exit 1
      fi
    else
      log_warn "Certaines fonctionnalités seront dégradées sans jq"
    fi
  elif [ "$OS" = "linux" ] && command -v apt-get &>/dev/null; then
    log_info "Installation de jq via apt-get..."
    if sudo apt-get install -y -q jq; then
      log_success "jq installé"
    else
      log_error "Échec installation jq — installer manuellement : sudo apt-get install jq"
      exit 1
    fi
  else
    log_warn "Installer jq manuellement :"
    log_info "  macOS  : brew install jq"
    log_info "  Ubuntu : sudo apt-get install jq"
    log_info "  Autre  : https://jqlang.github.io/jq/download/"
  fi
else
  log_success "jq $(jq --version)"
fi

# ── Node.js / npm ─────────────────────────
if ! command -v node &>/dev/null; then
  log_warn "Node.js non détecté — requis pour opencode"
  if [ "$OS" = "macos" ] && command -v brew &>/dev/null; then
    read -rp "  Installer Node.js via Homebrew ? [Y/n] : " _node_choice
    if [[ "${_node_choice:-Y}" =~ ^[Yy]$ ]]; then
      if brew install node --quiet; then
        log_success "Node.js installé"
      else
        log_error "Échec installation Node.js"
        exit 1
      fi
    else
      log_warn "opencode ne pourra pas être installé sans Node.js"
    fi
  elif [ "$OS" = "linux" ]; then
    log_info "Installation de Node.js via NodeSource (LTS)..."
    if curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - \
       && sudo apt-get install -y -q nodejs; then
      log_success "Node.js installé"
    else
      log_warn "Échec installation Node.js — installer manuellement : https://nodejs.org"
    fi
  else
    log_warn "Installer Node.js manuellement : https://nodejs.org"
  fi
else
  log_success "Node.js $(node --version)"
fi

# ── opencode ─────────────────────────────
if ! command -v opencode &>/dev/null; then
  if command -v npm &>/dev/null; then
    log_info "Installation de opencode via npm..."
    if npm install -g opencode-ai --silent; then
      log_success "opencode installé"
    else
      log_warn "Échec installation opencode — installer manuellement : npm install -g opencode-ai"
    fi
  else
    log_warn "npm introuvable — opencode non installé. Installer Node.js puis : npm install -g opencode-ai"
  fi
else
  log_success "opencode $(opencode --version 2>/dev/null || echo '?')"
fi

# ── bun ──────────────────────────────────
if ! command -v bun &>/dev/null; then
  log_info "Installation de bun..."
  if command -v curl &>/dev/null; then
    if curl -fsSL https://bun.sh/install | bash 2>/dev/null; then
      log_success "bun installé"
    else
      log_warn "Échec installation bun — installer manuellement : https://bun.sh"
    fi
    # Rendre bun disponible dans la session courante si installé via curl
    if [ -f "$HOME/.bun/bin/bun" ]; then
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
    fi
  else
    log_warn "curl introuvable — bun non installé. Installer manuellement : https://bun.sh"
  fi
else
  log_success "bun $(bun --version)"
fi

_outro "Dépendances vérifiées"

# ─────────────────────────────────────────
# ÉTAPE 3 — ALIAS SHELL
# ─────────────────────────────────────────
_intro "Configuration de l'alias 'oc'"

# Déterminer le fichier rc à modifier
_rc_file=""
if [ -n "${ZSH_VERSION:-}" ] || [ "${SHELL:-}" = "/bin/zsh" ] || [ "${SHELL:-}" = "/usr/bin/zsh" ]; then
  _rc_file="$HOME/.zshrc"
elif [ -n "${BASH_VERSION:-}" ] || [ "${SHELL:-}" = "/bin/bash" ] || [ "${SHELL:-}" = "/usr/bin/bash" ]; then
  _rc_file="$HOME/.bashrc"
  [ "$OS" = "macos" ] && _rc_file="$HOME/.bash_profile"
fi

_alias_line="alias oc=\"$INSTALL_DIR/oc.sh\""

if [ -n "$_rc_file" ]; then
  if grep -qF "alias oc=" "$_rc_file" 2>/dev/null; then
    log_info "Alias 'oc' déjà présent dans $_rc_file"
  else
    {
      echo ""
      echo "# opencode-hub"
      echo "$_alias_line"
    } >> "$_rc_file"
    log_success "Alias 'oc' ajouté dans $_rc_file"
  fi
  # Ajouter bun au PATH dans le rc si pas déjà présent
  if ! grep -qF 'BUN_INSTALL' "$_rc_file" 2>/dev/null && [ -d "$HOME/.bun" ]; then
    {
      # shellcheck disable=SC2016  # Intentional: $HOME/$BUN_INSTALL must expand at shell runtime
      echo 'export BUN_INSTALL="$HOME/.bun"'
      # shellcheck disable=SC2016
      echo 'export PATH="$BUN_INSTALL/bin:$PATH"'
    } >> "$_rc_file"
    log_success "PATH bun ajouté dans $_rc_file"
  fi
else
  log_warn "Shell non reconnu — ajouter manuellement dans votre fichier rc :"
  log_info "  $_alias_line"
fi

_outro "Alias configuré"

# ─────────────────────────────────────────
# ÉTAPE 4 — INIT CONFIG LOCAUX
# ─────────────────────────────────────────
_intro "Initialisation des fichiers locaux"

PROJECTS_DIR="$INSTALL_DIR/projects"
PROJECTS_FILE="$PROJECTS_DIR/projects.md"
PROJECTS_EXAMPLE="$PROJECTS_DIR/projects.example.md"
PATHS_FILE="$PROJECTS_DIR/paths.local.md"
API_KEYS_FILE="$PROJECTS_DIR/api-keys.local.md"

mkdir -p "$PROJECTS_DIR"

if [ ! -f "$PROJECTS_FILE" ]; then
  if [ -f "$PROJECTS_EXAMPLE" ]; then
    cp "$PROJECTS_EXAMPLE" "$PROJECTS_FILE"
    log_success "projects.md créé depuis projects.example.md"
  else
    cat > "$PROJECTS_FILE" <<'PROJEOF'
# Registre des projets

<!-- FORMAT
## <PROJECT_ID>
- Nom : <nom lisible>
- Stack : <technologies>
- Board Beads : <PROJECT_ID>
- Tracker : <jira|gitlab|none>
- Labels : <liste séparée par virgules>
-->

---

*Aucun projet enregistré pour l'instant.*
*Ajouter un projet : oc init*
PROJEOF
    log_success "projects.md créé"
  fi
else
  log_info "projects.md déjà présent — conservé"
fi

if [ ! -f "$PATHS_FILE" ]; then
  echo "# Chemins locaux (ignoré par git)" > "$PATHS_FILE"
  log_success "paths.local.md créé"
else
  log_info "paths.local.md déjà présent — conservé"
fi

if [ ! -f "$API_KEYS_FILE" ]; then
  cat > "$API_KEYS_FILE" <<'KEYSEOF'
# Clés API par projet (ignoré par git)
# Format :
#   [PROJECT_ID]
#   model=claude-opus-4-5
#   provider=anthropic
#   api_key=sk-ant-...
#   base_url=https://...  # optionnel
KEYSEOF
  chmod 600 "$API_KEYS_FILE"
  log_success "api-keys.local.md créé (permissions 600)"
else
  log_info "api-keys.local.md déjà présent — conservé"
fi

_outro "Fichiers locaux initialisés"

# ─────────────────────────────────────────
# ÉTAPE 5 — CONFIGURATION VIA oc install
# ─────────────────────────────────────────
_intro "Configuration des outils AI"

log_info "Lancement de 'oc install' pour choisir vos cibles et configurer votre fournisseur LLM..."
echo -e "${DIM}│${RESET}"

if bash "$INSTALL_DIR/oc.sh" install; then
  _outro "Configuration terminée"
else
  log_warn "Configuration incomplète — relancer plus tard : oc install"
  _outro "Installation de base réussie"
fi

# ─────────────────────────────────────────
# RÉSUMÉ FINAL
# ─────────────────────────────────────────
echo ""
echo -e "${BOLD}◆  opencode-hub installé avec succès !${RESET}"
echo -e "${DIM}│${RESET}"
echo -e "${DIM}│${RESET}  Répertoire : ${INSTALL_DIR}"
echo -e "${DIM}│${RESET}"
echo -e "${DIM}│${RESET}  Prochaine étape — recharger votre shell :"
echo -e "${DIM}│${RESET}"
if [ -n "${_rc_file:-}" ]; then
  echo -e "${DIM}│${RESET}    source $_rc_file"
  echo -e "${DIM}│${RESET}"
fi
echo -e "${DIM}│${RESET}  Puis enregistrer un projet :"
echo -e "${DIM}│${RESET}"
echo -e "${DIM}│${RESET}    oc init          # enregistrer un projet"
echo -e "${DIM}│${RESET}    oc deploy        # déployer les agents"
echo -e "${DIM}│${RESET}    oc help          # voir toutes les commandes"
echo -e "${DIM}└${RESET}"
echo ""
