#!/bin/bash
# Gestion des fournisseurs LLM (providers) — configuration hub et par-projet

set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# ────────────────────────────────────────────────────────────────────────────────
# Subcommande : oc provider list
# Affiche tous les providers du catalogue avec leur statut
# ────────────────────────────────────────────────────────────────────────────────
cmd_list() {
  log_title "Fournisseurs LLM disponibles"
  echo ""
  
  [ ! -f "$PROVIDERS_FILE" ] && { log_error "Catalogue providers.json introuvable"; exit 1; }
  
  local hub_provider; hub_provider=$(get_hub_default_provider)
  
  jq -r '.providers | keys[]' "$PROVIDERS_FILE" | while read -r provider_name; do
    local label; label=$(get_provider_info "$provider_name" "label")
    local desc; desc=$(get_provider_info "$provider_name" "description")
    local targets; targets=$(get_provider_info "$provider_name" "supported_targets" | tr ',' ' ')
    
    # Ajouter un marqueur si c'est le default du hub
    local marker=""
    if [ "$provider_name" = "$hub_provider" ]; then
      marker=" ${GREEN}◆ (hub default)${RESET}"
    fi
    
    printf "  ${BOLD}%-15s${RESET}$marker\n" "$label"
    printf "    %s\n" "$desc"
    printf "    Cibles: %s\n" "$targets"
    echo ""
  done
}

# ────────────────────────────────────────────────────────────────────────────────
# Subcommande : oc provider set-default
# Configure le fournisseur par défaut au niveau hub
# ────────────────────────────────────────────────────────────────────────────────
cmd_set_default() {
  log_title "Configuration du fournisseur par défaut (hub.json)"
  
  [ ! -f "$PROVIDERS_FILE" ] && { log_error "Catalogue providers.json introuvable"; exit 1; }
  [ ! -f "$HUB_CONFIG" ] && { log_error "hub.json introuvable — lancez d'abord : ./oc.sh install"; exit 1; }
  
  echo ""
  log_info "Choisir le fournisseur par défaut pour tous les projets :"
  echo ""
  
  local providers=()
  local labels=()
  local i=1
  jq -r '.providers | keys[]' "$PROVIDERS_FILE" | while read -r pname; do
    local label; label=$(get_provider_info "$pname" "label")
    printf "  ${BLUE}%d${RESET}) %s\n" "$i" "$label"
    i=$((i + 1))
  done | tee /tmp/provider_list.txt
  
  echo ""
  read -rp "  Numéro : " choice
  
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    log_error "Choix invalide : '$choice'"
    exit 1
  fi
  
  local providers_array=()
  while IFS= read -r pname; do
    providers_array+=("$pname")
  done < <(jq -r '.providers | keys[]' "$PROVIDERS_FILE")
  
  if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#providers_array[@]}" ]; then
    log_error "Choix hors limites : $choice (attendu 1-${#providers_array[@]})"
    exit 1
  fi
  
  local selected_provider="${providers_array[$((choice - 1))]}"
  local selected_label; selected_label=$(get_provider_info "$selected_provider" "label")
  local requires_api_key; requires_api_key=$(get_provider_info "$selected_provider" "requires_api_key")
  local requires_base_url; requires_base_url=$(get_provider_info "$selected_provider" "requires_base_url")
  local default_model; default_model=$(get_provider_info "$selected_provider" "default_model")
  local default_base_url; default_base_url=$(get_provider_info "$selected_provider" "default_base_url")
  
  echo ""
  log_info "Fournisseur sélectionné : $selected_label"
  
  # Demander les paramètres
  local api_key="" base_url="" model="$default_model"
  
  if [ "$requires_api_key" = "true" ]; then
    echo ""
    read -rsp "Clé API : " api_key
    echo ""
    if [ -z "$api_key" ]; then
      log_warn "Clé API vide — le fournisseur par défaut aura une clé vide"
    fi
  fi
  
  if [ "$requires_base_url" = "true" ]; then
    echo ""
    read -rp "URL de base [${default_base_url}] : " input_base_url
    base_url="${input_base_url:-$default_base_url}"
  fi
  
  echo ""
  read -rp "Modèle [$default_model] : " input_model
  model="${input_model:-$default_model}"
  
  # Construire le bloc JSON pour default_provider
  local provider_block
  provider_block=$(cat <<EOF
  "default_provider": {
    "name": "${selected_provider}",
    "api_key": "${api_key}",
    "base_url": "${base_url}",
    "model": "${model}"
  }
EOF
)
  
  # Mettre à jour hub.json — remplacer ou insérer le bloc default_provider
  local tmp; tmp=$(mktemp)
  if jq -e '.default_provider' "$HUB_CONFIG" &>/dev/null; then
    # Remplacer le bloc existant
    jq --argjson provider "$(echo "$provider_block" | sed 's/^  "default_provider": //' )" \
      '.default_provider = $provider' "$HUB_CONFIG" > "$tmp"
  else
    # Insérer le bloc (avant le champ "opencode" ou à la fin)
    jq --argjson provider "$(echo "$provider_block" | sed 's/^  "default_provider": //')" \
      '. + {default_provider: $provider}' "$HUB_CONFIG" > "$tmp"
  fi
  
  mv "$tmp" "$HUB_CONFIG"
  
  # Si la clé est présente, ajouter hub.json au .gitignore
  if [ -n "$api_key" ]; then
    local gitignore="$HUB_DIR/.gitignore"
    if [ ! -f "$gitignore" ] || ! grep -qx "config/hub.json" "$gitignore"; then
      echo "config/hub.json" >> "$gitignore"
      log_info "hub.json ajouté au .gitignore (contient une clé API)"
    fi
  fi
  
  echo ""
  log_success "Fournisseur par défaut configuré : $selected_label"
  log_info "Modèle : $model"
  [ -n "$base_url" ] && log_info "URL de base : $base_url"
}

# ────────────────────────────────────────────────────────────────────────────────
# Subcommande : oc provider set <PROJECT_ID>
# Configure le fournisseur pour un projet spécifique
# ────────────────────────────────────────────────────────────────────────────────
cmd_set() {
  local project_id="${1:-}"
  
  if [ -z "$project_id" ]; then
    log_error "PROJECT_ID requis"
    exit 1
  fi
  
  project_id=$(normalize_project_id "$project_id")
  
  if ! project_exists "$project_id"; then
    log_error "Projet introuvable : $project_id"
    exit 1
  fi
  
  log_title "Configuration du fournisseur pour $project_id"
  
  [ ! -f "$PROVIDERS_FILE" ] && { log_error "Catalogue providers.json introuvable"; exit 1; }
  
  echo ""
  log_info "Choisir le fournisseur pour ce projet :"
  echo ""
  
  local i=1
  local providers_array=()
  while IFS= read -r pname; do
    providers_array+=("$pname")
    local label; label=$(get_provider_info "$pname" "label")
    printf "  ${BLUE}%d${RESET}) %s\n" "$i" "$label"
    i=$((i + 1))
  done < <(jq -r '.providers | keys[]' "$PROVIDERS_FILE")
  
  echo ""
  read -rp "  Numéro : " choice
  
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#providers_array[@]}" ]; then
    log_error "Choix invalide : $choice"
    exit 1
  fi
  
  local selected_provider="${providers_array[$((choice - 1))]}"
  local selected_label; selected_label=$(get_provider_info "$selected_provider" "label")
  local requires_api_key; requires_api_key=$(get_provider_info "$selected_provider" "requires_api_key")
  local requires_base_url; requires_base_url=$(get_provider_info "$selected_provider" "requires_base_url")
  local default_model; default_model=$(get_provider_info "$selected_provider" "default_model")
  local default_base_url; default_base_url=$(get_provider_info "$selected_provider" "default_base_url")
  
  echo ""
  log_info "Fournisseur sélectionné : $selected_label"
  
  local api_key="" base_url="" model="$default_model"
  
  if [ "$requires_api_key" = "true" ]; then
    echo ""
    read -rsp "Clé API : " api_key
    echo ""
    if [ -z "$api_key" ]; then
      log_error "Clé API requise pour ce fournisseur"
      exit 1
    fi
  fi
  
  if [ "$requires_base_url" = "true" ]; then
    echo ""
    read -rp "URL de base [${default_base_url}] : " input_base_url
    base_url="${input_base_url:-$default_base_url}"
  fi
  
  echo ""
  read -rp "Modèle [$default_model] : " input_model
  model="${input_model:-$default_model}"
  
  # Écrire dans api-keys.local.md
  local api_keys_file="$PROJECTS_DIR/api-keys.local.md"
  mkdir -p "$PROJECTS_DIR"
  
  # Créer le fichier s'il n'existe pas
  if [ ! -f "$api_keys_file" ]; then
    cat > "$api_keys_file" <<'HEADER'
# Clés API et modèles par projet — NE PAS COMMITTER
# Format :
#   [PROJECT_ID]
#   model=claude-sonnet-4-5
#   provider=anthropic
#   api_key=sk-ant-...
#   base_url=https://...   (optionnel — litellm uniquement)

HEADER
  fi
  
  # Supprimer l'entrée existante si elle existe
  if grep -q "^\[$project_id\]" "$api_keys_file"; then
    local tmp; tmp=$(mktemp)
    awk -v section="[$project_id]" '
      BEGIN { skip=0 }
      $0 == section { skip=1; next }
      skip && /^\[/ { skip=0 }
      !skip { print }
    ' "$api_keys_file" > "$tmp"
    mv "$tmp" "$api_keys_file"
  fi
  
  # Ajouter la nouvelle entrée
  cat >> "$api_keys_file" <<EOF

[$project_id]
model=${model}
provider=${selected_provider}
api_key=${api_key}
base_url=${base_url}
EOF
  
  # Si clé API, ajouter au .gitignore
  local gitignore="$PROJECTS_DIR/.gitignore"
  if [ ! -f "$gitignore" ] || ! grep -qx "api-keys.local.md" "$gitignore"; then
    mkdir -p "$(dirname "$gitignore")"
    echo "api-keys.local.md" >> "$gitignore"
  fi
  
  echo ""
  log_success "Fournisseur configuré pour $project_id"
  log_info "Provider : $selected_label"
  log_info "Modèle : $model"
  [ -n "$base_url" ] && log_info "URL de base : $base_url"
}

# ────────────────────────────────────────────────────────────────────────────────
# Subcommande : oc provider get <PROJECT_ID>
# Affiche la configuration effective d'un projet
# ────────────────────────────────────────────────────────────────────────────────
cmd_get() {
  local project_id="${1:-}"
  
  if [ -z "$project_id" ]; then
    log_error "PROJECT_ID requis"
    exit 1
  fi
  
  project_id=$(normalize_project_id "$project_id")
  
  if ! project_exists "$project_id"; then
    log_error "Projet introuvable : $project_id"
    exit 1
  fi
  
  log_title "Configuration du fournisseur pour $project_id"
  echo ""
  
  # Résoudre provider effectif
  local effective_provider; effective_provider=$(get_effective_provider "$project_id")
  local effective_model; effective_model=$(get_effective_llm_model "$project_id")
  
  local project_provider; project_provider=$(get_project_api_provider "$project_id")
  local project_api_key; project_api_key=$(get_project_api_key "$project_id")
  local project_base_url; project_base_url=$(get_project_api_base_url "$project_id")
  local project_model; project_model=$(get_project_api_model "$project_id")
  
  if [ -z "$project_provider" ]; then
    # Utilise le default du hub
    local hub_provider; hub_provider=$(get_hub_default_provider)
    local hub_api_key; hub_api_key=$(get_hub_default_api_key)
    local hub_base_url; hub_base_url=$(get_hub_default_base_url)
    local hub_model; hub_model=$(get_hub_default_model)
    
    echo -e "  ${DIM}(Utilise le fournisseur par défaut du hub)${RESET}"
    echo ""
    [ -n "$hub_provider" ] && printf "  %-15s %s\n" "Provider :" "$hub_provider"
    [ -n "$hub_model" ] && printf "  %-15s %s\n" "Modèle :" "$hub_model"
    [ -n "$hub_base_url" ] && printf "  %-15s %s\n" "URL de base :" "$hub_base_url"
    if [ -n "$hub_api_key" ]; then
      local masked_key; masked_key="${hub_api_key:0:4}***${hub_api_key: -4}"
      printf "  %-15s %s\n" "Clé API :" "$masked_key"
    else
      printf "  %-15s %s\n" "Clé API :" "(vide)"
    fi
  else
    # Configuration au niveau du projet
    echo -e "  ${BOLD}Configuration projet${RESET}"
    echo ""
    printf "  %-15s %s\n" "Provider :" "$project_provider"
    [ -n "$project_model" ] && printf "  %-15s %s\n" "Modèle :" "$project_model"
    [ -n "$project_base_url" ] && printf "  %-15s %s\n" "URL de base :" "$project_base_url"
    if [ -n "$project_api_key" ]; then
      local masked_key; masked_key="${project_api_key:0:4}***${project_api_key: -4}"
      printf "  %-15s %s\n" "Clé API :" "$masked_key"
    else
      printf "  %-15s %s\n" "Clé API :" "(vide)"
    fi
  fi
  
  echo ""
}

# ────────────────────────────────────────────────────────────────────────────────
# Main dispatcher
# ────────────────────────────────────────────────────────────────────────────────

SUBCOMMAND="${1:-list}"
case "$SUBCOMMAND" in
  list)       cmd_list "${@:2}" ;;
  set-default) cmd_set_default "${@:2}" ;;
  set)        cmd_set "${@:2}" ;;
  get)        cmd_get "${@:2}" ;;
  *)
    log_error "Subcommande inconnue : $SUBCOMMAND"
    echo ""
    echo "Usage :"
    echo "  oc provider list                — Liste les fournisseurs disponibles"
    echo "  oc provider set-default         — Configure le fournisseur par défaut (hub)"
    echo "  oc provider set <PROJECT_ID>    — Configure le fournisseur pour un projet"
    echo "  oc provider get <PROJECT_ID>    — Affiche la config du projet"
    exit 1
    ;;
esac
