#!/bin/bash
# Adaptateur OpenCode — déploie vers .opencode/agents/ + opencode.json

source "$HUB_DIR/scripts/lib/prompt-builder.sh"

# Modèle résolu par priorité :
#   1. api-keys.local.md (clé project-level) si PROJECT_ID défini
#   2. variable d'env OPENCODE_MODEL
#   3. config/hub.json → opencode.model
#   4. fallback : claude-sonnet-4-5
_get_opencode_model() {
  local model=""
  # Niveau 1 : configuration projet (api-keys.local.md)
  if [ -n "${PROJECT_ID:-}" ]; then
    model=$(get_project_api_model "$PROJECT_ID")
  fi
  # Niveau 2 : variable d'environnement
  [ -z "$model" ] && model="${OPENCODE_MODEL:-}"
  # Niveau 3 : hub.json
  if [ -z "$model" ] && command -v jq &>/dev/null && [ -f "$HUB_DIR/config/hub.json" ]; then
    model=$(jq -r '.opencode.model // empty' "$HUB_DIR/config/hub.json" 2>/dev/null)
  fi
  echo "${model:-claude-sonnet-4-5}"
}

# Génère le bloc JSON "provider" selon le provider configuré
# Retourne une chaîne JSON partielle (sans virgule de tête) ou vide
_build_provider_block() {
  local project_id="${1:-}"
  [ -z "$project_id" ] && return 0

  local provider api_key base_url
  provider=$(get_project_api_provider "$project_id")
  api_key=$(get_project_api_key "$project_id")
  [ -z "$provider" ] || [ -z "$api_key" ] && return 0

  case "$provider" in
    anthropic)
      cat <<JSON
,
  "provider": {
    "anthropic": {
      "apiKey": "${api_key}"
    }
  }
JSON
      ;;
    litellm)
      base_url=$(get_project_api_base_url "$project_id")
      cat <<JSON
,
  "provider": {
    "litellm": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "apiKey": "${api_key}"$([ -n "$base_url" ] && echo ",
        \"baseURL\": \"${base_url}\"")
      }
    }
  }
JSON
      ;;
  esac
}

# Ajoute opencode.json au .gitignore du projet cible si une clé API est injectée
_gitignore_opencode_json() {
  local deploy_dir="$1"
  local gitignore="$deploy_dir/.gitignore"
  if [ ! -f "$gitignore" ] || ! grep -qx "opencode.json" "$gitignore"; then
    echo "opencode.json" >> "$gitignore"
    log_info "[opencode] opencode.json ajouté au .gitignore du projet (contient une clé API)"
  fi
}

adapter_validate() {
  command -v opencode &>/dev/null || { log_error "OpenCode non installé → oc install"; return 1; }
}

adapter_needs_node() { return 0; }

adapter_deploy() {
  local deploy_dir="${1:-$HUB_DIR}"
  local out_dir="$deploy_dir/.opencode/agents"
  mkdir -p "$out_dir"
  [ -d "$CANONICAL_AGENTS_DIR" ] || { log_error "[opencode] Dossier agents/ introuvable"; return 1; }

  # Lire la langue du projet si PROJECT_ID est défini (ADR-005)
  local lang=""
  if [ -n "${PROJECT_ID:-}" ]; then
    lang=$(get_project_language "$PROJECT_ID")
  fi

  local deployed=0

  while IFS= read -r agent_file; do
    [ -f "$agent_file" ] || continue
    agent_supports_target "$agent_file" "opencode" || { log_warn "[opencode] Ignoré : $(basename "$agent_file")"; continue; }

    local agent_id; agent_id=$(get_agent_id "$agent_file")
    log_info "[opencode] Génération : $agent_id"
    build_agent_content "$agent_file" "opencode" "$lang" > "$out_dir/${agent_id}.md"
    log_success "[opencode] $agent_id"
    deployed=$((deployed + 1))
  done < <(find "$CANONICAL_AGENTS_DIR" -name "*.md" | sort)

  # Générer opencode.json à la racine du projet
  local config_file="$deploy_dir/opencode.json"
  local model; model=$(_get_opencode_model)
  local provider_block=""
  local has_api_key=false

  # Construire le bloc provider si une clé est configurée pour ce projet
  if [ -n "${PROJECT_ID:-}" ] && api_keys_entry_exists "${PROJECT_ID}"; then
    provider_block=$(_build_provider_block "${PROJECT_ID}")
    [ -n "$provider_block" ] && has_api_key=true
  fi

  if [ ! -f "$config_file" ] || [ "$has_api_key" = true ]; then
    # Réécrire si : fichier absent OU clé API à injecter (toujours régénérer pour tenir à jour)
    printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "model": "%s"%s\n}\n' \
      "$model" "$provider_block" > "$config_file"
    if [ "$has_api_key" = true ]; then
      log_success "[opencode] opencode.json créé avec clé API (modèle : $model, provider : $(get_project_api_provider "${PROJECT_ID}"))"
      # Protéger le fichier (contient une clé) et l'exclure du commit projet
      chmod 600 "$config_file"
      _gitignore_opencode_json "$deploy_dir"
    else
      log_success "[opencode] opencode.json créé (modèle : $model)"
    fi
  else
    log_info "[opencode] opencode.json existant conservé"
  fi

  log_success "[opencode] $deployed agent(s) → ${deploy_dir}/.opencode/agents/"
}

adapter_install() {
  if ! command -v opencode &>/dev/null; then
    command -v npm &>/dev/null || { log_error "[opencode] npm non disponible — relancez le terminal et réessayez"; return 1; }
    log_info "Installation de OpenCode..."
    npm install -g opencode-ai
    log_success "OpenCode installé"
  else
    log_success "OpenCode déjà installé ($(opencode --version 2>/dev/null || echo '?'))"
  fi
}

adapter_update() {
  command -v npm &>/dev/null || { log_error "[opencode] npm non disponible — relancez le terminal et réessayez"; return 1; }
  log_info "Mise à jour OpenCode..."
  npm update -g opencode-ai && log_success "OpenCode mis à jour" || log_warn "Échec mise à jour OpenCode"
}

adapter_start() {
  local project_path="$1" prompt="${2:-}"
  cd "$project_path" || { log_error "[opencode] Impossible de naviguer vers $project_path"; exit 1; }
  [ -n "$prompt" ] && exec opencode --prompt "$prompt" || exec opencode
}
