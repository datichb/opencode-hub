#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

SUBCMD="${1:-}"
# NOTE : pour la sous-commande "tracker", $2 vaut la sous-sous-commande (setup/status/switch),
# pas le PROJECT_ID. Le PROJECT_ID est alors $3. Voir le dispatch ci-dessous.
PROJECT_ID="${2:-}"

# ── Aide interne ──────────────────────────
_beads_usage() {
  echo ""
  echo -e "${BOLD}Usage :${RESET} ./oc.sh beads <sous-commande> [PROJECT_ID]"
  echo ""
  echo -e "${BOLD}Gestion Beads :${RESET}"
  echo "  status         [PROJECT_ID]   Vérifie si Beads est initialisé dans le projet"
  echo "  init           <PROJECT_ID>   Initialise .beads/ dans le répertoire du projet"
  echo "  list           <PROJECT_ID>   Liste les tickets ouverts du projet"
  echo "  open           <PROJECT_ID>   Affiche le chemin pour utiliser bd manuellement"
  echo ""
  echo -e "${BOLD}Synchronisation tracker (Jira / GitLab) :${RESET}"
  echo "  sync           <PROJECT_ID> [--pull-only|--push-only|--dry-run]"
  echo "                               Synchronise avec le tracker configuré"
  echo "  tracker status <PROJECT_ID>  Affiche le tracker configuré et son état de sync"
  echo "  tracker setup  <PROJECT_ID>  Configure le tracker du projet (interactif)"
  echo "  tracker switch <PROJECT_ID>  Change le tracker d'un projet"
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

# ── Vérifier que .beads/ existe ───────────
_require_beads_init() {
  local path="$1" id="$2"
  if [ ! -d "$path/.beads" ]; then
    log_error "Beads non initialisé dans $id → ./oc.sh beads init $id"
    exit 1
  fi
}

# ── Résoudre le tracker d'un projet ───────
_resolve_tracker() {
  local id="$1"
  local tracker
  tracker=$(get_project_tracker "$id")
  if [ "$tracker" = "none" ] || [ -z "$tracker" ]; then
    log_error "Aucun tracker configuré pour $id"
    log_info  "Configurer : ./oc.sh beads tracker setup $id"
    exit 1
  fi
  echo "$tracker"
}

# ── Mettre à jour le champ Tracker dans projects.md ──
_set_project_tracker() {
  local id="$1" new_tracker="$2"
  # Tente de remplacer une ligne "- Tracker : *" existante dans le bloc du projet
  if perl -i -0pe "
    s{(^## \Q${id}\E\$.*?)(- Tracker : \S+)}{\${1}- Tracker : ${new_tracker}}ms
  " "$PROJECTS_FILE" 2>/dev/null && grep -q "- Tracker : ${new_tracker}" "$PROJECTS_FILE"; then
    return 0
  fi
  # Si le champ n'existe pas encore, l'ajouter après "- Labels :"
  perl -i -0pe "
    s{(^## \Q${id}\E\$.*?- Labels : [^\n]+\n)}{\${1}- Tracker : ${new_tracker}\n}ms
  " "$PROJECTS_FILE"
}

# ══════════════════════════════════════════
# Sous-commande : status
# ══════════════════════════════════════════
cmd_status() {
  local id="${1:-}"

  if [ -z "$id" ]; then
    log_title "Statut Beads — tous les projets"
    echo ""
    while IFS= read -r pid; do
      local path tracker
      path=$(get_project_path "$pid" 2>/dev/null)
      path="${path/#\~/$HOME}"
      tracker=$(get_project_tracker "$pid")
      local beads_icon tracker_str
      [ -d "$path/.beads" ] && beads_icon="${GREEN}✔${RESET}" || beads_icon="${YELLOW}✘${RESET}"
      [ "$tracker" = "none" ] && tracker_str="" || tracker_str="  [${BLUE}${tracker}${RESET}]"
      echo -e "  ${beads_icon}  $pid${tracker_str}  ${path}"
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

  local tracker
  tracker=$(get_project_tracker "$id")
  if [ "$tracker" != "none" ]; then
    log_info "Tracker : $tracker"
  else
    log_info "Tracker : aucun  (configurer : ./oc.sh beads tracker setup $id)"
  fi
}

# ══════════════════════════════════════════
# Sous-commande : init
# ══════════════════════════════════════════
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

# ══════════════════════════════════════════
# Sous-commande : list
# ══════════════════════════════════════════
cmd_list() {
  require_project_id "$1"
  _require_bd

  local id
  id=$(normalize_project_id "$1")
  local path
  path=$(_resolve_project_path "$id")
  _require_beads_init "$path" "$id"

  log_title "Tickets ouverts — $id"
  echo ""
  (cd "$path" && bd list --status open) || { log_error "Échec de bd list"; exit 1; }
}

# ══════════════════════════════════════════
# Sous-commande : open
# ══════════════════════════════════════════
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

# ══════════════════════════════════════════
# Sous-commande : sync
# ══════════════════════════════════════════
cmd_sync() {
  require_project_id "$1"
  _require_bd

  local id
  id=$(normalize_project_id "$1")
  shift
  local extra_flags=("$@")   # --pull-only, --push-only, --dry-run, etc.

  local path
  path=$(_resolve_project_path "$id")
  _require_beads_init "$path" "$id"

  local tracker
  tracker=$(_resolve_tracker "$id")

  log_info "Sync $tracker ← → Beads  [$id]"
  # Protection bash 3.2 : ${extra_flags[@]+...} évite le crash si le tableau est vide avec set -u
  (cd "$path" && bd "$tracker" sync ${extra_flags[@]+"${extra_flags[@]}"}) \
    || { log_error "Échec du sync $tracker"; exit 1; }
  log_success "Sync $tracker terminé pour $id"
}

# ══════════════════════════════════════════
# Sous-commandes : tracker *
# ══════════════════════════════════════════

# tracker status — affiche le tracker et l'état bd <tracker> status
cmd_tracker_status() {
  require_project_id "$1"
  _require_bd

  local id
  id=$(normalize_project_id "$1")
  local path
  path=$(_resolve_project_path "$id")
  _require_beads_init "$path" "$id"

  local tracker
  tracker=$(_resolve_tracker "$id")

  log_info "Tracker : $tracker  [$id]"
  echo ""
  (cd "$path" && bd "$tracker" status) || { log_error "Échec de bd $tracker status"; exit 1; }
}

# tracker setup — configuration interactive des credentials
cmd_tracker_setup() {
  require_project_id "$1"
  _require_bd

  local id
  id=$(normalize_project_id "$1")
  local path
  path=$(_resolve_project_path "$id")
  _require_beads_init "$path" "$id"

  local tracker
  tracker=$(get_project_tracker "$id")

  # Si pas de tracker défini, proposer le choix
  if [ "$tracker" = "none" ] || [ -z "$tracker" ]; then
    echo ""
    echo -e "${BOLD}Choisir un tracker pour $id :${RESET}"
    echo "  1) Jira"
    echo "  2) GitLab"
    echo ""
    read -rp "  Choix : " choice
    case "$choice" in
      1) tracker="jira" ;;
      2) tracker="gitlab" ;;
      *) log_error "Choix invalide"; exit 1 ;;
    esac
    _set_project_tracker "$id" "$tracker"
    log_success "Tracker $tracker enregistré pour $id"
  fi

  echo ""
  log_info "Configuration de $tracker pour le projet $id"
  echo ""

  case "$tracker" in
    jira)
      _setup_jira "$path" "$id"
      ;;
    gitlab)
      _setup_gitlab "$path" "$id"
      ;;
  esac
}

# tracker switch — changer de tracker
cmd_tracker_switch() {
  require_project_id "$1"
  _require_bd

  local id
  id=$(normalize_project_id "$1")
  local path
  path=$(_resolve_project_path "$id")

  local current
  current=$(get_project_tracker "$id")
  log_info "Tracker actuel : ${current}"
  echo ""
  echo -e "${BOLD}Nouveau tracker pour $id :${RESET}"
  echo "  1) Jira"
  echo "  2) GitLab"
  echo "  3) Aucun"
  echo ""
  read -rp "  Choix : " choice
  local new_tracker
  case "$choice" in
    1) new_tracker="jira" ;;
    2) new_tracker="gitlab" ;;
    3) new_tracker="none" ;;
    *) log_error "Choix invalide"; exit 1 ;;
  esac

  # Vérifier que Beads est initialisé avant d'appliquer le changement
  if [ "$new_tracker" != "none" ]; then
    _require_beads_init "$path" "$id"
  fi

  _set_project_tracker "$id" "$new_tracker"
  log_success "Tracker mis à jour : $current → $new_tracker"

  if [ "$new_tracker" != "none" ]; then
    echo ""
    read -rp "  Configurer $new_tracker maintenant ? [Y/n] : " setup_now
    if [[ "${setup_now:-Y}" =~ ^[Yy]$ ]]; then
      cmd_tracker_setup "$id"
    else
      log_info "Configurer plus tard : ./oc.sh beads tracker setup $id"
    fi
  fi
}

# ── Helpers de configuration ──────────────

_setup_jira() {
  local path="$1" id="$2"

  read -rp "  URL Jira (ex: https://company.atlassian.net) : " jira_url
  read -rp "  Clé de projet Jira (ex: PROJ) : " jira_project
  read -rp "  Email / username Jira : " jira_user
  trap 'stty echo 2>/dev/null; echo ""; exit 130' INT TERM
  read -rsp "  API token Jira (masqué) : " jira_token
  stty echo 2>/dev/null; trap - INT TERM
  echo ""

  (
    cd "$path"
    bd config set jira.url "$jira_url"
    bd config set jira.project "$jira_project"
    bd config set jira.username "$jira_user"
    bd config set jira.api_token "$jira_token"
  ) || { log_error "Échec de la configuration Jira"; exit 1; }

  log_success "Jira configuré pour $id"
  echo ""
  log_info "Tester la connexion : ./oc.sh beads tracker status $id"
  log_info "Synchroniser        : ./oc.sh beads sync $id --pull-only --dry-run"
}

_setup_gitlab() {
  local path="$1" id="$2"

  read -rp "  URL GitLab (ex: https://gitlab.com ou instance privée) : " gl_url
  trap 'stty echo 2>/dev/null; echo ""; exit 130' INT TERM
  read -rsp "  Token d'accès personnel GitLab (masqué) : " gl_token
  stty echo 2>/dev/null; trap - INT TERM
  echo ""

  # Lister les projets accessibles pour aider à trouver l'ID
  echo ""
  log_info "Récupération des projets accessibles avec ce token..."
  (cd "$path" && bd config set gitlab.url "$gl_url" && bd config set gitlab.token "$gl_token" \
    && bd gitlab projects) 2>/dev/null && echo "" || log_warn "Impossible de lister les projets (vérifier l'URL et le token)"

  read -rp "  ID ou chemin du projet GitLab (ex: 12345 ou namespace/project) : " gl_project_id

  (
    cd "$path"
    bd config set gitlab.url "$gl_url"
    bd config set gitlab.token "$gl_token"
    bd config set gitlab.project_id "$gl_project_id"
  ) || { log_error "Échec de la configuration GitLab"; exit 1; }

  log_success "GitLab configuré pour $id"
  echo ""
  log_info "Tester la connexion : ./oc.sh beads tracker status $id"
  log_info "Synchroniser        : ./oc.sh beads sync $id --pull-only --dry-run"
}

# ── Dispatch ──────────────────────────────
case "$SUBCMD" in
  status)  cmd_status  "$PROJECT_ID" ;;
  init)    cmd_init    "$PROJECT_ID" ;;
  list)    cmd_list    "$PROJECT_ID" ;;
  open)    cmd_open    "$PROJECT_ID" ;;
  sync)    cmd_sync    "$PROJECT_ID" "${@:3}" ;;
  tracker)
    TRACKER_SUBCMD="${2:-}"
    TRACKER_PROJECT="${3:-}"
    case "$TRACKER_SUBCMD" in
      status) cmd_tracker_status "$TRACKER_PROJECT" ;;
      setup)  cmd_tracker_setup  "$TRACKER_PROJECT" ;;
      switch) cmd_tracker_switch "$TRACKER_PROJECT" ;;
      ""|--help|-h)
        echo ""
        echo -e "${BOLD}Usage :${RESET} ./oc.sh beads tracker <status|setup|switch> <PROJECT_ID>"
        ;;
      *) log_error "Sous-commande tracker inconnue : $TRACKER_SUBCMD"; exit 1 ;;
    esac
    ;;
  ""|--help|-h) _beads_usage ;;
  *)
    log_error "Sous-commande inconnue : $SUBCMD"
    _beads_usage
    exit 1
    ;;
esac

