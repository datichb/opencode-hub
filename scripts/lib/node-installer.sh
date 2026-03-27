#!/bin/bash
# node-installer.sh — Détection et installation de Node.js
# Appelé par cmd-install.sh quand une cible requiert node/npm

# ── Version nvm dynamique ─────────────────────────────────────────────────────

_get_latest_nvm_version() {
  local version
  version=$(curl -sf https://api.github.com/repos/nvm-sh/nvm/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)
  echo "${version:-v0.40.3}"
}

# ── Instructions manuelles ────────────────────────────────────────────────────

_print_manual_instructions() {
  local method="$1"
  echo ""
  log_info "Installe Node.js manuellement puis relance : ./oc.sh install"
  echo ""
  case "$method" in
    volta)
      log_info "  Via Volta :"
      log_info "    curl https://get.volta.sh | bash"
      log_info "    volta install node"
      log_info "    → https://volta.sh"
      ;;
    brew)
      log_info "  Via Homebrew :"
      log_info "    brew install node"
      ;;
    nvm)
      local v; v=$(_get_latest_nvm_version)
      log_info "  Via nvm :"
      log_info "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${v}/install.sh | bash"
      log_info "    nvm install --lts"
      log_info "    → https://github.com/nvm-sh/nvm"
      ;;
    *)
      log_info "  Via Volta  : https://volta.sh"
      log_info "  Via nvm    : https://github.com/nvm-sh/nvm"
      log_info "  Installeur : https://nodejs.org"
      ;;
  esac
  echo ""
}

# ── Installers ────────────────────────────────────────────────────────────────

_install_with_volta() {
  log_info "Installation de Volta..."
  curl -sf https://get.volta.sh | bash
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"

  if ! command -v volta &>/dev/null; then
    log_error "Volta installé mais introuvable dans le PATH"
    return 1
  fi
  log_success "Volta installé"

  log_info "Installation de Node.js via Volta..."
  volta install node
}

_install_with_brew() {
  log_info "Installation de Node.js via Homebrew..."
  brew install node
}

_install_with_nvm() {
  local v; v=$(_get_latest_nvm_version)
  log_info "Version nvm détectée : $v"
  log_info "Installation de nvm..."
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${v}/install.sh" | bash

  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

  if ! command -v nvm &>/dev/null; then
    log_error "nvm installé mais introuvable dans le PATH"
    return 1
  fi
  log_success "nvm $v installé"

  log_info "Installation de Node.js LTS via nvm..."
  nvm install --lts
}

# ── Vérification post-install ─────────────────────────────────────────────────

_verify_node_in_path() {
  if command -v node &>/dev/null; then
    log_success "Node.js $(node -v) disponible"
    return 0
  fi

  echo ""
  log_warn "Node.js installé mais pas encore dans le PATH de cette session."
  log_info "Ouvre un nouveau terminal puis relance : ./oc.sh install"
  echo ""
  return 1
}

# ── Install avec méthode choisie ─────────────────────────────────────────────

_install_node_with() {
  local method="$1"

  echo ""
  read -rp "$(echo -e "  ${YELLOW}?${RESET}  Installer automatiquement ? [Y/n] ")" confirm
  confirm="${confirm:-Y}"

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    _print_manual_instructions "$method"
    return 1
  fi

  echo ""
  case "$method" in
    volta) _install_with_volta ;;
    brew)  _install_with_brew  ;;
    nvm)   _install_with_nvm   ;;
  esac || { _print_manual_instructions "$method"; return 1; }

  _verify_node_in_path
}

# ── Choix interactif (toujours affiché, avec indication de disponibilité) ─────

_choose_installer() {
  local os="$1"
  local options=()
  local labels=()

  # Charger nvm si présent avant détection
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

  local volta_label="Volta  (recommandé — https://volta.sh)"
  command -v volta &>/dev/null && volta_label="Volta  (déjà installé, recommandé)"
  options+=("volta")
  labels+=("$volta_label")

  if [ "$os" = "macos" ]; then
    local brew_label="Homebrew"
    command -v brew &>/dev/null && brew_label="Homebrew  (déjà installé)"
    options+=("brew")
    labels+=("$brew_label")
  fi

  local nvm_label="nvm    (https://github.com/nvm-sh/nvm)"
  command -v nvm &>/dev/null && nvm_label="nvm    (déjà installé)"
  options+=("nvm")
  labels+=("$nvm_label")

  echo ""
  log_info "Comment installer Node.js ?"
  echo ""
  for i in "${!labels[@]}"; do
    printf "  ${BLUE}%d${RESET}) %s\n" "$((i+1))" "${labels[$i]}"
  done
  echo ""
  read -rp "  Numéro (défaut: 1) : " choice
  choice="${choice:-1}"

  local idx=$(( choice - 1 ))
  if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#options[@]}" ]; then
    log_warn "Choix invalide — Volta sélectionné par défaut"
    idx=0
  fi

  echo "${options[$idx]}"
}

# ── Détection et dispatch ─────────────────────────────────────────────────────

_detect_and_install_node() {
  local os; os=$(detect_os)
  local method; method=$(_choose_installer "$os")
  _install_node_with "$method"
}

# ── Point d'entrée public ─────────────────────────────────────────────────────

ensure_node() {
  if command -v node &>/dev/null; then
    log_success "Node.js $(node -v) détecté"
    return 0
  fi

  log_warn "Node.js n'est pas installé"
  _detect_and_install_node
}
