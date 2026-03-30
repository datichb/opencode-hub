#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# ─────────────────────────────────────────────────────────────────
# oc config — gestion des clés API et modèles par projet
# Stockage : projects/api-keys.local.md (non versionné)
# ─────────────────────────────────────────────────────────────────

SUBCOMMAND="${1:-}"
shift || true

# ── Helpers internes ──────────────────────────────────────────────

# Assure que api-keys.local.md existe
_ensure_api_keys_file() {
  if [ ! -f "$API_KEYS_FILE" ]; then
    mkdir -p "$(dirname "$API_KEYS_FILE")"
    cat > "$API_KEYS_FILE" <<'EOF'
# Clés API et modèles par projet — NE PAS COMMITTER
# Format :
#   [PROJECT_ID]
#   model=claude-opus-4-5
#   provider=anthropic
#   api_key=sk-ant-...
#   base_url=https://...   (optionnel — litellm uniquement)
EOF
    log_info "api-keys.local.md créé"
  fi
}

# Supprime une section [PROJECT_ID] complète du fichier (délègue à common.sh)
_remove_section() {
  remove_api_keys_section "$1"
}

# Écrit ou remplace une section complète (atomique via tmpfile + mv)
_write_section() {
  local id="$1" model="$2" provider="$3" api_key="$4" base_url="$5"
  _ensure_api_keys_file
  # Supprimer l'entrée existante si présente
  if api_keys_entry_exists "$id"; then
    _remove_section "$id"
  fi
  # Construire la nouvelle entrée dans un tmpfile, puis l'appendre atomiquement
  local tmp; tmp=$(mktemp)
  {
    echo ""
    echo "[${id}]"
    echo "model=${model}"
    echo "provider=${provider}"
    echo "api_key=${api_key}"
    [ -n "$base_url" ] && echo "base_url=${base_url}"
  } > "$tmp"
  cat "$tmp" >> "$API_KEYS_FILE"
  rm -f "$tmp"
}

# Affiche la configuration d'un projet (masque la clé)
_display_entry() {
  local id="$1"
  local model provider api_key base_url masked
  model=$(get_project_api_model "$id")
  provider=$(get_project_api_provider "$id")
  api_key=$(get_project_api_key "$id")
  base_url=$(get_project_api_base_url "$id")
  # Masquer la clé API : conserver les 8 premiers caractères + ***
  if [ -n "$api_key" ] && [ "${#api_key}" -gt 8 ]; then
    masked="${api_key:0:8}***"
  elif [ -n "$api_key" ]; then
    masked="***"
  else
    masked="(non définie)"
  fi
  echo -e "  ${BOLD}${id}${RESET}"
  echo "    model    : ${model:-(défaut hub)}"
  echo "    provider : ${provider:-(non défini)}"
  echo "    api_key  : ${masked}"
  [ -n "$base_url" ] && echo "    base_url : ${base_url}"
}

# ── Sous-commandes ─────────────────────────────────────────────────

cmd_set() {
  local id="${1:-}"
  shift || true

  # Flags optionnels
  local flag_model="" flag_provider="" flag_api_key="" flag_base_url=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --model)    flag_model="$2";    shift 2 ;;
      --provider) flag_provider="$2"; shift 2 ;;
      --api-key)  flag_api_key="$2";  shift 2 ;;
      --base-url) flag_base_url="$2"; shift 2 ;;
      *) log_error "Option inconnue : $1"; exit 1 ;;
    esac
  done

  [ -z "$id" ] && { read -rp "  PROJECT_ID : " id; }
  id=$(normalize_project_id "$id")
  require_project_id "$id"

  # Valeurs actuelles (si entrée existe déjà)
  local cur_model cur_provider cur_api_key cur_base_url
  cur_model=$(get_project_api_model "$id")
  cur_provider=$(get_project_api_provider "$id")
  cur_api_key=$(get_project_api_key "$id")
  cur_base_url=$(get_project_api_base_url "$id")

  echo -e "\n${BOLD}Configuration API — $id${RESET}\n"

  # Modèle
  if [ -z "$flag_model" ]; then
    local default_model="${cur_model:-claude-sonnet-4-5}"
    read -rp "  Modèle [${default_model}] : " flag_model
    flag_model="${flag_model:-$default_model}"
  fi

  # Provider
  if [ -z "$flag_provider" ]; then
    local default_provider="${cur_provider:-anthropic}"
    echo "  Providers disponibles : anthropic / litellm"
    read -rp "  Provider [${default_provider}] : " flag_provider
    flag_provider="${flag_provider:-$default_provider}"
  fi
  # Normaliser
  flag_provider=$(echo "$flag_provider" | tr '[:upper:]' '[:lower:]')
  if [ "$flag_provider" != "anthropic" ] && [ "$flag_provider" != "litellm" ]; then
    log_error "Provider non supporté : $flag_provider (anthropic | litellm)"
    exit 1
  fi

  # Clé API (saisie masquée)
  if [ -z "$flag_api_key" ]; then
    local masked_cur=""
    [ -n "$cur_api_key" ] && masked_cur=" [actuelle : ${cur_api_key:0:8}***]"
    # Restaurer l'écho terminal si l'utilisateur interrompt (Ctrl+C)
    trap 'stty echo 2>/dev/null; echo ""; exit 130' INT TERM
    read -rsp "  Clé API${masked_cur} : " flag_api_key
    stty echo 2>/dev/null
    trap - INT TERM
    echo ""
    # Si aucune nouvelle saisie et qu'une ancienne existe, conserver l'ancienne
    if [ -z "$flag_api_key" ] && [ -n "$cur_api_key" ]; then
      flag_api_key="$cur_api_key"
      log_info "Clé API inchangée"
    fi
  fi
  if [ -z "$flag_api_key" ]; then
    log_error "Clé API requise"
    exit 1
  fi

  # Base URL (litellm uniquement)
  if [ "$flag_provider" = "litellm" ] && [ -z "$flag_base_url" ]; then
    local default_url="${cur_base_url:-}"
    local prompt_url="  Base URL${default_url:+ [${default_url}]} : "
    read -rp "$prompt_url" flag_base_url
    flag_base_url="${flag_base_url:-$default_url}"
  fi

  # Écriture
  _ensure_api_keys_file
  _write_section "$id" "$flag_model" "$flag_provider" "$flag_api_key" "$flag_base_url"
  log_success "Configuration enregistrée pour $id"

  # Proposer un re-déploiement uniquement si le chemin du projet est connu
  echo ""
  if path_exists "$id"; then
    read -rp "  Appliquer maintenant au projet (re-déployer opencode.json) ? [Y/n] : " apply_now
    if [[ "${apply_now:-Y}" =~ ^[Yy]$ ]]; then
      PROJECT_ID="$id" bash "$SCRIPTS_DIR/cmd-deploy.sh" all "$id"
    else
      log_info "Appliquer plus tard : ./oc.sh deploy opencode $id"
    fi
  else
    log_info "Chemin non enregistré pour $id — appliquer via : ./oc.sh deploy opencode $id"
  fi
}

cmd_get() {
  local id="${1:-}"
  [ -z "$id" ] && { log_error "Usage : oc config get <PROJECT_ID>"; exit 1; }
  id=$(normalize_project_id "$id")
  if ! api_keys_entry_exists "$id"; then
    log_warn "Aucune configuration pour $id"
    exit 0
  fi
  echo ""
  _display_entry "$id"
  echo ""
}

cmd_list() {
  if [ ! -f "$API_KEYS_FILE" ]; then
    log_info "Aucune configuration enregistrée (api-keys.local.md absent)"
    exit 0
  fi
  local sections
  sections=$(grep -E '^\[.+\]$' "$API_KEYS_FILE" | tr -d '[]' || true)
  if [ -z "$sections" ]; then
    log_info "Aucune entrée dans api-keys.local.md"
    exit 0
  fi
  echo -e "\n${BOLD}Configurations API enregistrées :${RESET}\n"
  while IFS= read -r id; do
    _display_entry "$id"
    echo ""
  done <<< "$sections"
}

cmd_unset() {
  local id="${1:-}"
  [ -z "$id" ] && { log_error "Usage : oc config unset <PROJECT_ID>"; exit 1; }
  id=$(normalize_project_id "$id")
  if ! api_keys_entry_exists "$id"; then
    log_warn "Aucune configuration pour $id"
    exit 0
  fi
  read -rp "  Supprimer la configuration de $id ? [y/N] : " confirm
  if [[ "${confirm:-N}" =~ ^[Yy]$ ]]; then
    _remove_section "$id"
    log_success "Configuration supprimée pour $id"
  else
    log_info "Annulé"
  fi
}

# ── Dispatcher ─────────────────────────────────────────────────────

case "$SUBCOMMAND" in
  set)   cmd_set "$@" ;;
  get)   cmd_get "$@" ;;
  list)  cmd_list ;;
  unset) cmd_unset "$@" ;;
  "")
    echo -e "${BOLD}Usage :${RESET} ./oc.sh config <sous-commande> [options]"
    echo ""
    echo "  set <PROJECT_ID> [--model m] [--provider p] [--api-key k] [--base-url u]"
    echo "  get <PROJECT_ID>"
    echo "  list"
    echo "  unset <PROJECT_ID>"
    exit 0
    ;;
  *)
    log_error "Sous-commande inconnue : $SUBCOMMAND"
    exit 1
    ;;
esac
