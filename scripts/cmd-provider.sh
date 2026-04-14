#!/bin/bash
# Gestion des fournisseurs LLM — configuration hub et par-projet

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
resolve_oc_lang

# ────────────────────────────────────────────────────────────────────────────────
# Helper : affiche le menu numéroté des fournisseurs, retourne les noms dans un array
# Usage : _build_provider_menu <array_name>
# ────────────────────────────────────────────────────────────────────────────────
_build_provider_menu() {
  local -n _menu_array=$1
  _menu_array=()
  if [ -f "$PROVIDERS_FILE" ] && command -v jq &>/dev/null; then
    while IFS= read -r pname; do
      _menu_array+=("$pname")
    done < <(jq -r '.providers | keys[]' "$PROVIDERS_FILE")
  else
    _menu_array=("anthropic" "mammouth" "github-models" "bedrock" "ollama")
  fi

  local _i=1
  for pname in "${_menu_array[@]}"; do
    local _label; _label=$(get_provider_info "$pname" "label" 2>/dev/null || echo "$pname")
    printf "  ${BLUE}%d${RESET}. %s\n" "$_i" "$_label"
    _i=$((_i + 1))
  done
}

# ────────────────────────────────────────────────────────────────────────────────
# Helper : collecte les credentials pour un fournisseur sélectionné
# Sortie : _cred_api_key, _cred_base_url (variables globales du contexte appelant)
# ────────────────────────────────────────────────────────────────────────────────
_collect_credentials() {
  local provider_name="$1"
  local provider_label="$2"
  local requires_api_key; requires_api_key=$(get_provider_info "$provider_name" "requires_api_key" 2>/dev/null || echo "true")
  local requires_base_url; requires_base_url=$(get_provider_info "$provider_name" "requires_base_url" 2>/dev/null || echo "false")
  local default_base_url; default_base_url=$(get_provider_info "$provider_name" "default_base_url" 2>/dev/null || echo "")

  _cred_api_key=""
  _cred_base_url="$default_base_url"

  if [ "$requires_api_key" = "true" ]; then
    echo ""
    trap 'stty echo 2>/dev/null; echo ""; exit 130' INT TERM
    read -rsp "  Clé API ${provider_label} : " _cred_api_key
    stty echo 2>/dev/null
    trap - INT TERM
    echo ""
  fi

  if [ "$requires_base_url" = "true" ] && [ -n "$default_base_url" ]; then
    echo ""
    read -rp "  URL de base [${default_base_url}] : " _input_url
    _cred_base_url="${_input_url:-$default_base_url}"
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# Subcommande : oc provider list
# Affiche tous les fournisseurs du catalogue avec leur statut
# ────────────────────────────────────────────────────────────────────────────────
cmd_list() {
  log_title "$(t provider.title)"
  echo ""

  [ ! -f "$PROVIDERS_FILE" ] && { log_error "$(t provider.no_catalog)"; exit 1; }

  local hub_provider; hub_provider=$(get_hub_default_provider)
  local hub_api_key; hub_api_key=$(get_hub_default_api_key)

  jq -r '.providers | keys[]' "$PROVIDERS_FILE" | while read -r pname; do
    local label; label=$(get_provider_info "$pname" "label")
    local desc; desc=$(get_provider_info "$pname" "description")
    local targets_raw; targets_raw=$(jq -r --arg n "$pname" '.providers[$n].supported_targets[]' "$PROVIDERS_FILE" 2>/dev/null | paste -sd ',' -)

    # Statut hub
    local status=""
    if [ "$pname" = "$hub_provider" ]; then
      if [ -n "$hub_api_key" ]; then
        status=" ${GREEN}◆ fournisseur du hub${RESET}"
      else
        status=" ${YELLOW}◆ fournisseur du hub (clé non configurée)${RESET}"
      fi
    fi

    printf "  ${BOLD}%s${RESET}%b\n" "$label" "$status"
    printf "    %s\n" "$desc"
    [ -n "$targets_raw" ] && printf "    Cibles : %s\n" "$targets_raw"
    echo ""
  done
}

# ────────────────────────────────────────────────────────────────────────────────
# Subcommande : oc provider set-default
# Configure le fournisseur par défaut au niveau hub
# ────────────────────────────────────────────────────────────────────────────────
cmd_set_default() {
  log_title "$(t provider.default_title)"

  [ ! -f "$PROVIDERS_FILE" ] && { log_error "$(t provider.no_catalog)"; exit 1; }
  [ ! -f "$HUB_CONFIG" ] && { log_error "$(t provider.hub_json_missing)"; exit 1; }

  # Afficher le fournisseur actuel comme contexte
  local current_provider; current_provider=$(get_hub_default_provider)
  local current_api_key; current_api_key=$(get_hub_default_api_key)
  echo ""
  if [ -n "$current_provider" ]; then
    local current_label; current_label=$(get_provider_info "$current_provider" "label" 2>/dev/null || echo "$current_provider")
    if [ -n "$current_api_key" ]; then
      local masked="${current_api_key:0:4}***"
      echo -e "  Fournisseur actuel : ${BOLD}${current_label}${RESET} (clé : ${masked})"
    else
      echo -e "  Fournisseur actuel : ${BOLD}${current_label}${RESET} ${YELLOW}(clé non configurée)${RESET}"
    fi
    echo ""
  fi

  log_info "$(t provider.choose_default)"
  echo ""

  local providers_array=()
  _build_provider_menu providers_array
  echo ""

  read -rp "  Numéro (1-${#providers_array[@]}) : " choice

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#providers_array[@]}" ]; then
    log_error "Choix invalide : '$choice'"
    exit 1
  fi

  local selected_provider="${providers_array[$((choice - 1))]}"
  local selected_label; selected_label=$(get_provider_info "$selected_provider" "label")
  local requires_api_key; requires_api_key=$(get_provider_info "$selected_provider" "requires_api_key")

  echo ""
  log_info "$(t provider.selected) ${BOLD}${selected_label}${RESET}"

  _cred_api_key=""
  _cred_base_url=""
  _collect_credentials "$selected_provider" "$selected_label"

  # Vérification clé si requise
  if [ "$requires_api_key" = "true" ] && [ -z "$_cred_api_key" ]; then
    log_warn "$(t provider.api_key_empty_warn)"
  fi

  # Mettre à jour hub.json
  local tmp; tmp=$(mktemp)
  jq \
    --arg name "$selected_provider" \
    --arg key  "$_cred_api_key" \
    --arg url  "$_cred_base_url" \
    '.default_provider.name = $name | .default_provider.api_key = $key | .default_provider.base_url = $url' \
    "$HUB_CONFIG" > "$tmp"
  mv "$tmp" "$HUB_CONFIG"

  # Protéger hub.json si clé présente
  if [ -n "$_cred_api_key" ]; then
    local gitignore="$HUB_DIR/.gitignore"
    if [ ! -f "$gitignore" ] || ! grep -qx "config/hub.json" "$gitignore"; then
      echo "config/hub.json" >> "$gitignore"
      log_info "$(t provider.hub_json_added_gitignore)"
    fi
  fi

  echo ""
  log_success "$(t provider.saved) ${selected_label}"
  [ -n "$_cred_base_url" ] && log_info "URL de base : ${_cred_base_url}"

  # Régénérer opencode.json du hub immédiatement pour que la config soit active
  source "$HUB_DIR/scripts/lib/adapter-manager.sh"
  local active_targets
  active_targets=$(get_active_targets)
  local _synced=false
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    load_adapter "$target"
    if declare -F adapter_deploy &>/dev/null; then
      log_info "Mise à jour de ${target} (opencode.json)..."
      adapter_deploy "$HUB_DIR" ""
      _synced=true
    fi
  done <<< "$active_targets"
  [ "$_synced" = false ] && log_info "$(t provider.apply_hint)"
}

# ────────────────────────────────────────────────────────────────────────────────
# Subcommande : oc provider set <PROJECT_ID>
# Configure le fournisseur pour un projet spécifique
# ────────────────────────────────────────────────────────────────────────────────
cmd_set() {
  local project_id="${1:-}"
  # Paramètres optionnels pour usage non-interactif (ex: depuis cmd-init.sh)
  local direct_provider="${2:-}"
  local direct_api_key="${3:-}"
  local direct_base_url="${4:-}"

  [ -z "$project_id" ] && { log_error "$(t project_id.required)"; exit 1; }
  project_id=$(normalize_project_id "$project_id")

  if ! project_exists "$project_id"; then
    log_error "$(t project_id.required) : $project_id"
    exit 1
  fi

  [ ! -f "$PROVIDERS_FILE" ] && { log_error "$(t provider.no_catalog)"; exit 1; }

  # Mode non-interactif si tous les paramètres directs sont fournis
  if [ -n "$direct_provider" ]; then
    local direct_label; direct_label=$(get_provider_info "$direct_provider" "label" 2>/dev/null || echo "$direct_provider")
    _write_project_provider "$project_id" "$direct_provider" "$direct_api_key" "$direct_base_url"
    log_success "Fournisseur configuré pour ${project_id} : ${direct_label}"
    return 0
  fi

  # Mode interactif
  log_title "$(t provider.project_title) ${project_id}"

  # Afficher le fournisseur actuel du projet et du hub
  local cur_provider; cur_provider=$(get_project_api_provider "$project_id")
  local hub_provider; hub_provider=$(get_hub_default_provider)
  echo ""
  if [ -n "$cur_provider" ]; then
    local cur_label; cur_label=$(get_provider_info "$cur_provider" "label" 2>/dev/null || echo "$cur_provider")
    echo -e "  $(t provider.current_project) ${BOLD}${cur_label}${RESET}"
  elif [ -n "$hub_provider" ]; then
    local hub_label; hub_label=$(get_provider_info "$hub_provider" "label" 2>/dev/null || echo "$hub_provider")
    echo -e "  $(t provider.hub_default) ${BOLD}${hub_label}${RESET}"
  fi
  echo ""

  log_info "$(t provider.choose_project)"
  echo ""

  local providers_array=()
  _build_provider_menu providers_array
  echo ""

  read -rp "  Numéro (1-${#providers_array[@]}) : " choice

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#providers_array[@]}" ]; then
    log_error "Choix invalide : $choice"
    exit 1
  fi

  local selected_provider="${providers_array[$((choice - 1))]}"
  local selected_label; selected_label=$(get_provider_info "$selected_provider" "label")
  local requires_api_key; requires_api_key=$(get_provider_info "$selected_provider" "requires_api_key")

  echo ""
  log_info "$(t provider.selected) ${BOLD}${selected_label}${RESET}"

  _cred_api_key=""
  _cred_base_url=""
  _collect_credentials "$selected_provider" "$selected_label"

  if [ "$requires_api_key" = "true" ] && [ -z "$_cred_api_key" ]; then
    log_error "$(t provider.api_key_required)"
    exit 1
  fi

  _write_project_provider "$project_id" "$selected_provider" "$_cred_api_key" "$_cred_base_url"

  echo ""
  log_success "$(t provider.set_done) ${project_id} : ${selected_label}"
  [ -n "$_cred_base_url" ] && log_info "URL de base : ${_cred_base_url}"
  log_info "$(t provider.apply_hint)"
}

# ────────────────────────────────────────────────────────────────────────────────
# Helper : écriture atomique dans api-keys.local.md
# ────────────────────────────────────────────────────────────────────────────────
_write_project_provider() {
  local project_id="$1" provider="$2" api_key="$3" base_url="$4"
  local api_keys_file="$API_KEYS_FILE"
  mkdir -p "$(dirname "$API_KEYS_FILE")"

  if [ ! -f "$api_keys_file" ]; then
    cat > "$api_keys_file" <<'HEADER'
# Clés API et modèles par projet — NE PAS COMMITTER
# Format :
#   [PROJECT_ID]
#   model=claude-sonnet-4-5
#   provider=anthropic
#   api_key=sk-ant-...
#   base_url=https://...   (optionnel)

HEADER
  fi

  # Supprimer l'entrée existante
  if grep -q "^\[${project_id}\]" "$api_keys_file"; then
    local tmp; tmp=$(mktemp)
    awk -v section="[${project_id}]" '
      BEGIN { skip=0 }
      $0 == section { skip=1; next }
      skip && /^\[/ { skip=0 }
      !skip { print }
    ' "$api_keys_file" > "$tmp"
    mv "$tmp" "$api_keys_file"
  fi

  # Récupérer le modèle existant si présent, sinon default du provider
  local existing_model; existing_model=$(get_project_api_model "$project_id" 2>/dev/null || echo "")
  local default_model; default_model=$(get_provider_info "$provider" "default_model" 2>/dev/null || echo "$DEFAULT_MODEL")
  local model="${existing_model:-$default_model}"

  {
    echo ""
    echo "[${project_id}]"
    echo "model=${model}"
    echo "provider=${provider}"
    echo "api_key=${api_key}"
    [ -n "$base_url" ] && echo "base_url=${base_url}"
  } >> "$api_keys_file"

  # S'assurer que api-keys.local.md est dans .gitignore
  local gitignore; gitignore="$(dirname "$API_KEYS_FILE")/.gitignore"
  if [ ! -f "$gitignore" ] || ! grep -qx "api-keys.local.md" "$gitignore"; then
    mkdir -p "$(dirname "$gitignore")"
    echo "api-keys.local.md" >> "$gitignore"
  fi
}

# ────────────────────────────────────────────────────────────────────────────────
# Subcommande : oc provider get <PROJECT_ID>
# Affiche la configuration effective d'un projet
# ────────────────────────────────────────────────────────────────────────────────
cmd_get() {
  local project_id="${1:-}"
  [ -z "$project_id" ] && { log_error "$(t project_id.required)"; exit 1; }
  project_id=$(normalize_project_id "$project_id")

  if ! project_exists "$project_id"; then
    log_error "$(t project_id.required) : $project_id"
    exit 1
  fi

  log_title "$(t provider.project_title) ${project_id}"
  echo ""

  local project_provider; project_provider=$(get_project_api_provider "$project_id")
  local project_api_key; project_api_key=$(get_project_api_key "$project_id")
  local project_base_url; project_base_url=$(get_project_api_base_url "$project_id")
  local project_model; project_model=$(get_project_api_model "$project_id")

  if [ -n "$project_provider" ]; then
    local proj_label; proj_label=$(get_provider_info "$project_provider" "label" 2>/dev/null || echo "$project_provider")
    echo -e "  $(t provider.source_project)"
    echo ""
    printf "  %-18s %s\n" "$(t provider.current)" "$proj_label"
    [ -n "$project_model" ] && printf "  %-18s %s\n" "Modèle :" "$project_model"
    [ -n "$project_base_url" ] && printf "  %-18s %s\n" "URL de base :" "$project_base_url"
    if [ -n "$project_api_key" ]; then
      printf "  %-18s %s\n" "Clé API :" "${project_api_key:0:4}***"
    else
      printf "  %-18s %s\n" "Clé API :" "(non configurée)"
    fi
  else
    local hub_provider; hub_provider=$(get_hub_default_provider)
    local hub_api_key; hub_api_key=$(get_hub_default_api_key)
    local hub_base_url; hub_base_url=$(get_hub_default_base_url)
    local hub_model; hub_model=$(get_hub_default_model)

    echo -e "  $(t provider.source_hub)"
    echo ""
    if [ -n "$hub_provider" ]; then
      local hub_label; hub_label=$(get_provider_info "$hub_provider" "label" 2>/dev/null || echo "$hub_provider")
      printf "  %-18s %s\n" "$(t provider.current)" "$hub_label"
      [ -n "$hub_model" ] && printf "  %-18s %s\n" "Modèle :" "$hub_model"
      [ -n "$hub_base_url" ] && printf "  %-18s %s\n" "URL de base :" "$hub_base_url"
      if [ -n "$hub_api_key" ]; then
        printf "  %-18s %s\n" "Clé API :" "${hub_api_key:0:4}***"
      else
        printf "  %-18s %s\n" "Clé API :" "(non configurée)"
      fi
    else
      echo -e "  ${YELLOW}$(t provider.no_provider)${RESET}"
      echo ""
      echo "  Configurer au niveau hub    : ./oc.sh provider set-default"
      echo "  Configurer pour ce projet   : ./oc.sh provider set ${project_id}"
    fi
  fi

  echo ""
  echo -e "  ${DIM}Modifier : ./oc.sh provider set ${project_id}${RESET}"
  echo ""
}

# ────────────────────────────────────────────────────────────────────────────────
# Main dispatcher
# ────────────────────────────────────────────────────────────────────────────────

SUBCOMMAND="${1:-list}"
case "$SUBCOMMAND" in
  list)        cmd_list "${@:2}" ;;
  set-default) cmd_set_default "${@:2}" ;;
  set)         cmd_set "${@:2}" ;;
  get)         cmd_get "${@:2}" ;;
  *)
    log_error "$(t subcmd.unknown) : $SUBCOMMAND"
    echo ""
    echo "$(t provider.usage)"
    echo ""
    echo "  $(t provider.list_cmd)"
    echo "  $(t provider.set_default_cmd)"
    echo "  $(t provider.set_cmd)"
    echo "  $(t provider.get_cmd)"
    exit 1
    ;;
esac
