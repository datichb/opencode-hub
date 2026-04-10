#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
source "$LIB_DIR/adapter-manager.sh"

log_title "Installation de opencode-hub"

OS=$(detect_os)
log_info "OS détecté : $OS"

# ── Vérifier jq ─────────────────────────
if ! command -v jq &>/dev/null; then
  log_warn "jq non détecté — dépendance critique pour opencode-hub"
  if [ "$OS" = "macos" ] && command -v brew &>/dev/null; then
    read -rp "  Installer jq via Homebrew ? [Y/n] : " jq_choice
    if [[ "${jq_choice:-Y}" =~ ^[Yy]$ ]]; then
      brew install jq && log_success "jq installé" || log_error "Échec installation jq — à installer manuellement"
    else
      log_warn "Certaines fonctionnalités (deploy, skills, beads) seront dégradées sans jq"
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

# ── Choisir les cibles ───────────────────
log_title "Cibles à configurer"
echo ""
echo "  1. OpenCode (recommandé)"
echo "  2. Claude Code"
echo "  3. Tout"
echo ""
read -rp "Choisir (1-3, défaut: 1) : " tool_choice
tool_choice="${tool_choice:-1}"

active_targets=()
case "$tool_choice" in
  2) active_targets=("claude-code") ;;
  3) active_targets=("opencode" "claude-code") ;;
  *) active_targets=("opencode") ;;
esac

echo ""

# ── Vérifier si une cible requiert Node.js ───────────────────────────────────
needs_node=false
for target in "${active_targets[@]}"; do
  load_adapter "$target"
  adapter_needs_node && needs_node=true && break
done

if [ "$needs_node" = true ]; then
  source "$LIB_DIR/node-installer.sh"
  ensure_node || exit 1
fi

# ── Dossiers requis ──────────────────────
mkdir -p "$HUB_DIR/projects" "$HUB_DIR/skills" "$HUB_DIR/agents" \
         "$HUB_DIR/.opencode/agents" "$HUB_DIR/config" \
         "$HUB_DIR/scripts/lib" "$HUB_DIR/scripts/adapters"

# ── Écrire config/hub.json (seulement si absent ou si l'utilisateur confirme) ──
targets_json=$(printf '"%s",' "${active_targets[@]}" | sed 's/,$//')
if [ -f "$HUB_DIR/config/hub.json" ]; then
  log_warn "config/hub.json existe déjà."
  read -rp "  Écraser avec les nouvelles cibles ? [y/N] : " overwrite_choice
  if [[ "${overwrite_choice:-N}" =~ ^[Yy]$ ]]; then
    _write_hub_json=true
  else
    log_info "config/hub.json conservé tel quel."
    _write_hub_json=false
  fi
else
  _write_hub_json=true
fi

if [ "$_write_hub_json" = true ]; then
  cat > "$HUB_DIR/config/hub.json" << HUBJSON
{
  "version": "2.0.0",
  "default_target": "${active_targets[0]}",
  "active_targets": [${targets_json}],
  "default_provider": {
    "name": "anthropic",
    "api_key": "",
    "base_url": "",
    "model": ""
  },
  "opencode": {
    "model": "${DEFAULT_MODEL}"
  }
}
HUBJSON
  log_success "config/hub.json créé (cibles : ${active_targets[*]})"
fi

# ── Fournisseur LLM par défaut ────────────────────────────────────────────────
# Cette section s'exécute APRÈS l'écriture de hub.json pour ne pas être écrasée
log_title "Fournisseur LLM"
echo ""
log_info "Quel fournisseur d'IA utiliser pour tous vos projets ?"
echo ""

# Construire le menu dynamiquement depuis providers.json
_provider_names=()
if [ -f "$PROVIDERS_FILE" ] && command -v jq &>/dev/null; then
  while IFS= read -r pname; do
    _provider_names+=("$pname")
  done < <(jq -r '.providers | keys[]' "$PROVIDERS_FILE")
fi

_provider_count="${#_provider_names[@]}"
if [ "$_provider_count" -gt 0 ]; then
  _i=1
  for pname in "${_provider_names[@]}"; do
    _label=$(get_provider_info "$pname" "label")
    if [ "$_i" -eq 1 ]; then
      printf "  %d. %s (recommandé)\n" "$_i" "$_label"
    else
      printf "  %d. %s\n" "$_i" "$_label"
    fi
    _i=$((_i + 1))
  done
  printf "  %d. Ignorer (configurer plus tard via ./oc.sh provider set-default)\n" "$((_provider_count + 1))"
  echo ""
  read -rp "Choisir (1-$((_provider_count + 1)), défaut: 1) : " _provider_choice
  _provider_choice="${_provider_choice:-1}"
else
  # Fallback sans providers.json : menu statique
  echo "  1. Anthropic (recommandé)"
  echo "  2. MammouthAI"
  echo "  3. GitHub Models"
  echo "  4. AWS Bedrock"
  echo "  5. Ollama (local)"
  echo "  6. Ignorer (configurer plus tard via ./oc.sh provider set-default)"
  echo ""
  read -rp "Choisir (1-6, défaut: 1) : " _provider_choice
  _provider_choice="${_provider_choice:-1}"
  _provider_names=("anthropic" "mammouth" "github-models" "bedrock" "ollama")
  _provider_count=5
fi

# Résoudre le fournisseur sélectionné
_selected_provider=""
if [[ "$_provider_choice" =~ ^[0-9]+$ ]] && [ "$_provider_choice" -ge 1 ] && [ "$_provider_choice" -le "$_provider_count" ]; then
  _selected_provider="${_provider_names[$((_provider_choice - 1))]}"
fi
# Si choix hors plage ou "Ignorer", _selected_provider reste vide

if [ -n "$_selected_provider" ]; then
  _selected_label=$(get_provider_info "$_selected_provider" "label" 2>/dev/null || echo "$_selected_provider")
  _requires_api_key=$(get_provider_info "$_selected_provider" "requires_api_key" 2>/dev/null || echo "true")
  _default_base_url=$(get_provider_info "$_selected_provider" "default_base_url" 2>/dev/null || echo "")
  _requires_base_url=$(get_provider_info "$_selected_provider" "requires_base_url" 2>/dev/null || echo "false")

  echo ""
  _provider_api_key=""
  _provider_base_url="$_default_base_url"

  if [ "$_requires_api_key" = "true" ]; then
    trap 'stty echo 2>/dev/null; echo ""; exit 130' INT TERM
    read -rsp "  Clé API ${_selected_label} (laisser vide pour ignorer) : " _provider_api_key
    stty echo 2>/dev/null
    trap - INT TERM
    echo ""
  fi

  if [ "$_requires_base_url" = "true" ] && [ -n "$_default_base_url" ]; then
    read -rp "  URL de base [${_default_base_url}] : " _input_base_url
    _provider_base_url="${_input_base_url:-$_default_base_url}"
  fi

  # Écrire dans hub.json seulement si une clé est fournie (ou si ollama, pas besoin de clé)
  _should_save=false
  [ -n "$_provider_api_key" ] && _should_save=true
  [ "$_requires_api_key" = "false" ] && _should_save=true

  if [ "$_should_save" = "true" ] && [ -f "$HUB_DIR/config/hub.json" ]; then
    _hub_json=$(jq \
      --arg name "$_selected_provider" \
      --arg key  "$_provider_api_key" \
      --arg url  "$_provider_base_url" \
      '.default_provider.name = $name | .default_provider.api_key = $key | .default_provider.base_url = $url' \
      "$HUB_DIR/config/hub.json")
    echo "$_hub_json" > "$HUB_DIR/config/hub.json"

    # Protéger hub.json si clé présente
    if [ -n "$_provider_api_key" ]; then
      if [ ! -f "$HUB_DIR/.gitignore" ] || ! grep -qx "config/hub.json" "$HUB_DIR/.gitignore"; then
        echo "config/hub.json" >> "$HUB_DIR/.gitignore"
      fi
    fi

    log_success "Fournisseur configuré : ${_selected_label}"
  else
    log_info "Fournisseur non configuré — utiliser : ./oc.sh provider set-default"
  fi
else
  log_info "Fournisseur non configuré — utiliser : ./oc.sh provider set-default"
fi

echo ""

# ── Installer chaque cible sélectionnée ──
for target in "${active_targets[@]}"; do
  load_adapter "$target"
  adapter_install
done

# ── Fichiers initiaux ────────────────────
ensure_projects_file
log_success "projects.md prêt"

if [ ! -f "$PATHS_FILE" ]; then
  echo "# Chemins locaux (ignoré par git)" > "$PATHS_FILE"
  log_success "paths.local.md créé"
fi

echo ""
log_info "Tip : Enrichissez vos agents avec des skills tiers via context7 :"
log_info "  ./oc.sh skills search <query>        # Rechercher"
log_info "  ./oc.sh skills add /owner/repo name  # Ajouter"

# ── Installer Beads (bd) ─────────────────
echo ""
log_title "Installation de Beads (bd)"
if command -v bd &>/dev/null; then
  bd_version=$(bd --version 2>/dev/null || bd version 2>/dev/null || echo '?')
  log_success "Beads déjà installé ($bd_version)"
else
  log_warn "Beads (bd) non détecté — requis pour la gestion des tickets"
  read -rp "  Installer Beads ? [Y/n] : " _beads_choice </dev/tty
  if [[ "${_beads_choice:-Y}" =~ ^[Yy]$ ]]; then
    if command -v brew &>/dev/null; then
      log_info "Installation de Beads via Homebrew..."
      if brew install beads; then
        log_success "Beads installé"
      else
        log_warn "Échec via Homebrew — tentative via curl..."
        if curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash; then
          log_success "Beads installé via curl"
        else
          log_warn "Échec installation Beads — installer manuellement : brew install beads"
        fi
      fi
    elif command -v curl &>/dev/null; then
      log_info "Installation de Beads via curl..."
      if curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash; then
        log_success "Beads installé"
      else
        log_warn "Échec installation Beads — installer manuellement :"
        log_info "  macOS  : brew install beads"
        log_info "  Linux  : curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash"
      fi
    else
      log_warn "Homebrew et curl introuvables — installer Beads manuellement :"
      log_info "  macOS  : brew install beads"
      log_info "  Linux  : curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash"
    fi
  else
    log_info "Beads non installé — à installer plus tard : brew install beads"
  fi
fi

echo ""
log_success "opencode-hub prêt !"
