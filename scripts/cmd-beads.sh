#!/bin/bash
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

SUBCMD="${1:-}"
PROJECT_ID="${2:-}"

# ── Aide interne ──────────────────────────
_beads_usage() {
  echo ""
  echo -e "${BOLD}Usage :${RESET} ./oc.sh beads <sous-commande> [PROJECT_ID]"
  echo ""
  echo -e "${BOLD}Sous-commandes :${RESET}"
  echo "  status  [PROJECT_ID]   Vérifie si Beads est initialisé dans le projet"
  echo "  init    <PROJECT_ID>   Initialise .beads/ dans le répertoire du projet"
  echo "  list    <PROJECT_ID>   Liste les tickets ouverts du projet"
  echo "  open    <PROJECT_ID>   Ouvre le répertoire du projet (pour utiliser bd manuellement)"
  echo ""
}

# ── Résoudre le chemin du projet ──────────
_resolve_project_path() {
  local id="$1"
  id=$(normalize_project_id "$id")

  if ! project_exists "$id"; then
    log_error "Projet $id introuvable → ./oc.sh list"
    exit 1
  fi

  local path
  path=$(get_project_path "$id")
  path="${path/#\~/$HOME}"

  if [ -z "$path" ]; then
    log_error "Aucun chemin local pour $id → ./oc.sh init $id"
    exit 1
  fi

  if [ ! -d "$path" ]; then
    log_error "Dossier introuvable : $path"
    exit 1
  fi

  echo "$path"
}

# ── Vérifier que bd est disponible ────────
_require_bd() {
  if ! command -v bd &>/dev/null; then
    log_error "bd (Beads) n'est pas installé"
    log_info  "Installation : brew install bd"
    exit 1
  fi
}

# ── Sous-commande : status ─────────────────
cmd_status() {
  local id="${1:-}"

  if [ -z "$id" ]; then
    # Afficher le statut de tous les projets
    log_title "Statut Beads — tous les projets"
    echo ""
    while IFS= read -r pid; do
      local path
      path=$(get_project_path "$pid" 2>/dev/null)
      path="${path/#\~/$HOME}"
      if [ -d "$path/.beads" ]; then
        echo -e "  ${GREEN}✔${RESET}  $pid  ${path}"
      else
        echo -e "  ${YELLOW}✘${RESET}  $pid  ${path}  ${YELLOW}(non initialisé)${RESET}"
      fi
    done < <(grep "^## " "$PROJECTS_FILE" | sed 's/^## //')
    echo ""
    return
  fi

  id=$(normalize_project_id "$id")
  local path
  path=$(_resolve_project_path "$id")

  if [ -d "$path/.beads" ]; then
    log_success "Beads initialisé dans $id ($path/.beads)"
  else
    log_warn "Beads non initialisé dans $id"
    log_info  "Lancez : ./oc.sh beads init $id"
  fi
}

# ── Sous-commande : init ───────────────────
cmd_init() {
  require_project_id "$1"
  _require_bd

  local id
  id=$(normalize_project_id "$1")
  local path
  path=$(_resolve_project_path "$id")

  if [ -d "$path/.beads" ]; then
    log_warn "Beads déjà initialisé dans $id ($path/.beads)"
    exit 0
  fi

  log_info "Initialisation de Beads dans : $path"
  (cd "$path" && bd init) || { log_error "Échec de bd init"; exit 1; }
  log_success "Beads initialisé dans $id ($path/.beads)"
}

# ── Sous-commande : list ───────────────────
cmd_list() {
  require_project_id "$1"
  _require_bd

  local id
  id=$(normalize_project_id "$1")
  local path
  path=$(_resolve_project_path "$id")

  if [ ! -d "$path/.beads" ]; then
    log_error "Beads non initialisé dans $id → ./oc.sh beads init $id"
    exit 1
  fi

  log_title "Tickets ouverts — $id"
  echo ""
  (cd "$path" && bd list --status open) || { log_error "Échec de bd list"; exit 1; }
}

# ── Sous-commande : open ───────────────────
cmd_open() {
  require_project_id "$1"

  local id
  id=$(normalize_project_id "$1")
  local path
  path=$(_resolve_project_path "$id")

  log_info "Répertoire du projet $id : $path"
  log_info "Vous pouvez maintenant utiliser bd directement dans ce répertoire"
  echo ""
  echo "  cd $path"
  echo "  bd list --status open"
}

# ── Dispatch ──────────────────────────────
case "$SUBCMD" in
  status) cmd_status "$PROJECT_ID" ;;
  init)   cmd_init   "$PROJECT_ID" ;;
  list)   cmd_list   "$PROJECT_ID" ;;
  open)   cmd_open   "$PROJECT_ID" ;;
  ""|--help|-h) _beads_usage ;;
  *)
    log_error "Sous-commande inconnue : $SUBCMD"
    _beads_usage
    exit 1
    ;;
esac
