#!/bin/bash
set -euo pipefail

# ── Aide interne ──────────────────────────
_beads_usage() {
  echo ""
  echo -e "${BOLD}$(t beads.title)${RESET}"
  echo "  $(t help.beads_status)"
  echo "  $(t help.beads_init)"
  echo "  $(t help.beads_list)"
  echo "  $(t help.beads_create)"
  echo "  $(t help.beads_create_desc)"
  echo "  $(t help.beads_open)"
  echo ""
  echo -e "${BOLD}$(t beads.tracker.title)${RESET}"
  echo "  $(t help.beads_sync)"
  echo "  $(t help.beads_sync_desc)"
  echo "  $(t help.beads_tracker_status)"
  echo "  $(t help.beads_tracker_setup)"
  echo "  $(t help.beads_tracker_switch)"
  echo ""
}

# ── Vérifier que bd est disponible ────────
_require_bd() {
  if ! command -v bd &>/dev/null; then
    log_error "$(t beads.not_installed)"
    log_info  "$(t beads.install_hint)"
    exit 1
  fi
}

# ── Vérifier que .beads/ existe ───────────
_require_beads_init() {
  local path="$1" id="$2"
  if [ ! -d "$path/.beads" ]; then
    log_error "$(t beads.not_initialized) $id → ./oc.sh beads init $id"
    exit 1
  fi
}

# ── Résoudre le tracker d'un projet ───────
_resolve_tracker() {
  local id="$1"
  local tracker
  tracker=$(get_project_tracker "$id")
  # Normaliser en minuscules (protection contre casse incorrecte dans projects.md)
  tracker=$(echo "$tracker" | tr '[:upper:]' '[:lower:]')
  if [ "$tracker" = "none" ] || [ -z "$tracker" ]; then
    log_error "$(t beads.no_tracker) $id"
    log_info  "$(t beads.tracker.configure) $id"
    exit 1
  fi
  echo "$tracker"
}

# ── Mettre à jour le champ Tracker dans projects.md ──
_set_project_tracker() {
  local id="$1" new_tracker="$2"
  # Whitelist stricte — protège aussi contre l'injection Perl
  case "$new_tracker" in
    jira|gitlab|none) ;;
    *) log_error "Tracker invalide : $new_tracker (jira | gitlab | none)"; exit 1 ;;
  esac
  # Tente de remplacer une ligne "- Tracker : *" existante dans le bloc du projet
  if perl -i -0777pe "
    s{(^## \Q${id}\E\n.*?)(- Tracker : \S+)}{\${1}- Tracker : ${new_tracker}}ms
  " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Tracker : ${new_tracker}" "$PROJECTS_FILE"; then
    return 0
  fi
  # Si le champ n'existe pas encore, l'ajouter après "- Labels :"
  if perl -i -0777pe "
    s{(^## \Q${id}\E\n.*?- Labels : [^\n]+\n)}{\${1}- Tracker : ${new_tracker}\n}ms
  " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Tracker : ${new_tracker}" "$PROJECTS_FILE"; then
    return 0
  fi
  # Fallback : si "- Labels :" absent, ajouter après le dernier champ "- " du bloc projet
  if perl -i -0777pe "
    s{(^## \Q${id}\E\n.*?- [^\n]+\n)}{\${1}- Tracker : ${new_tracker}\n}ms
  " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Tracker : ${new_tracker}" "$PROJECTS_FILE"; then
    return 0
  fi
  log_error "Impossible d'insérer le champ Tracker dans le bloc $id de projects.md"
  return 1
}

# ══════════════════════════════════════════
# Sous-commande : status
# ══════════════════════════════════════════
cmd_status() {
  local id="${1:-}"

  if [ -z "$id" ]; then
    log_title "$(t beads.status.all)"
    echo ""
    while IFS= read -r pid; do
      local path tracker
      path=$(get_project_path "$pid" 2>/dev/null)
      path="${path/#\~/$HOME}"
      tracker=$(get_project_tracker "$pid")
      local beads_icon tracker_str
      # Protection : si path vide, ne pas tester /.beads (racine)
      if [ -n "$path" ] && [ -d "$path/.beads" ]; then
        beads_icon="${GREEN}✔${RESET}"
      else
        beads_icon="${YELLOW}✘${RESET}"
      fi
      [ "$tracker" = "none" ] && tracker_str="" || tracker_str="  [${BLUE}${tracker}${RESET}]"
      echo -e "  ${beads_icon}  $pid${tracker_str}  ${path}"
    done < <(grep "^## " "$PROJECTS_FILE" | sed 's/^## //')
    echo ""
    return
  fi

  id=$(normalize_project_id "$id")
  local path
  path=$(resolve_project_path "$id")

  if [ -d "$path/.beads" ]; then
    log_success "$(t beads.initialized) $id ($path/.beads)"
  else
    log_warn "$(t beads.not_initialized) $id"
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
  path=$(resolve_project_path "$id")

  if [ -d "$path/.beads" ]; then
    log_warn "$(t beads.already_initialized) $id ($path/.beads)"
    exit 0
  fi

  log_info "Initialisation de Beads dans : $path"
  (cd "$path" && bd init) || { log_error "$(t beads.init_failed)"; exit 1; }
  log_success "$(t beads.initialized) $id ($path/.beads)"

  # Proposer de configurer l'upstream git si absent (ni upstream ni origin trouvé)
  if ! (cd "$path" && git remote get-url upstream) &>/dev/null && \
     ! (cd "$path" && git remote get-url origin) &>/dev/null; then
    echo ""
    read -rp "  Configurer l'upstream Git (git remote add upstream) ? [Y/n] : " _setup_upstream || true
    if [[ "${_setup_upstream:-Y}" =~ ^[Yy]$ ]]; then
      read -rp "  URL du remote upstream : " _upstream_url || true
      if [ -n "$_upstream_url" ]; then
        if (cd "$path" && git remote add upstream "$_upstream_url"); then
          log_success "Remote upstream configuré : $_upstream_url"
        else
          log_warn "Échec de la configuration upstream — configurer manuellement"
        fi
      else
        log_warn "URL vide — configurer plus tard : git remote add upstream <url>"
      fi
    else
      log_info "Configurer plus tard : git remote add upstream <url>"
    fi
  fi

  # Enregistrer les labels de projects.md dans la config bd
  local labels
  labels=$(get_project_labels "$id")
  if [ -n "$labels" ]; then
    log_info "Enregistrement des labels dans la config Beads…"
    local _labels_ok=1
    while IFS= read -r _lbl; do
      _lbl=$(printf '%s' "$_lbl" | sed 's/^ *//;s/ *$//')
      [ -z "$_lbl" ] && continue
      if ! (cd "$path" && bd label add "$_lbl"); then
        _labels_ok=0
      fi
    done < <(printf '%s\n' "$labels" | tr ',' '\n')
    if [ "$_labels_ok" = "1" ]; then
      log_success "$(t beads.labels.registered) $labels"
    else
      log_warn "$(t beads.labels.failed)"
    fi
  fi
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
  path=$(resolve_project_path "$id")
  _require_beads_init "$path" "$id"

  log_title "$(t beads.status.open_tickets) $id"
  echo ""
  (cd "$path" && bd list -s open) || { log_error "Échec de bd list"; exit 1; }
}

# ══════════════════════════════════════════
# Sous-commande : open
# ══════════════════════════════════════════
cmd_open() {
  require_project_id "$1"

  local id
  id=$(normalize_project_id "$1")
  local path
  path=$(resolve_project_path "$id")

  log_info "Répertoire du projet $id : $path"
  if ! command -v bd &>/dev/null; then
    log_warn "$(t beads.not_installed) — $(t beads.install_hint)"
  fi
  log_info "$(t beads.open_hint)"
  echo ""
  echo "  cd $path"
  echo "  bd list -s open"
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
  path=$(resolve_project_path "$id")
  _require_beads_init "$path" "$id"

  local tracker
  tracker=$(_resolve_tracker "$id")

  log_info "Sync $tracker ← → Beads  [$id]"
  # Protection bash 3.2 : ${extra_flags[@]+...} évite le crash si le tableau est vide avec set -u
  (cd "$path" && bd "$tracker" sync ${extra_flags[@]+"${extra_flags[@]}"}) \
    || { log_error "$(t beads.sync.failed) $tracker"; exit 1; }
  log_success "$(t beads.sync.done) $id"
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
  path=$(resolve_project_path "$id")
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
  path=$(resolve_project_path "$id")
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
      *) log_error "$(t beads.tracker.invalid)"; exit 1 ;;
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
  path=$(resolve_project_path "$id")

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
    *) log_error "$(t beads.tracker.invalid)"; exit 1 ;;
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
  [ -z "$jira_url" ] && { log_error "URL Jira requise"; exit 1; }
  read -rp "  Clé de projet Jira (ex: PROJ) : " jira_project
  [ -z "$jira_project" ] && { log_error "Clé de projet Jira requise"; exit 1; }
  read -rp "  Email / username Jira : " jira_user
  [ -z "$jira_user" ] && { log_error "Email / username Jira requis"; exit 1; }
  trap 'stty echo 2>/dev/null; echo ""; exit 130' INT TERM
  read -rsp "  API token Jira (masqué) : " jira_token
  stty echo 2>/dev/null; trap - INT TERM
  echo ""
  [ -z "$jira_token" ] && { log_error "Token Jira requis"; exit 1; }

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
  [ -z "$gl_url" ] && { log_error "URL GitLab requise"; exit 1; }
  trap 'stty echo 2>/dev/null; echo ""; exit 130' INT TERM
  read -rsp "  Token d'accès personnel GitLab (masqué) : " gl_token
  stty echo 2>/dev/null; trap - INT TERM
  echo ""
  [ -z "$gl_token" ] && { log_error "Token GitLab requis"; exit 1; }

  # Lister les projets accessibles pour aider à trouver l'ID
  echo ""
  log_info "Récupération des projets accessibles avec ce token..."
  (cd "$path" && bd config set gitlab.url "$gl_url" && bd config set gitlab.token "$gl_token" \
    && bd gitlab projects) 2>/dev/null && echo "" || log_warn "Impossible de lister les projets (vérifier l'URL et le token)"

  read -rp "  ID ou chemin du projet GitLab (ex: 12345 ou namespace/project) : " gl_project_id
  [ -z "$gl_project_id" ] && { log_error "ID de projet GitLab requis"; exit 1; }

  # url et token déjà configurés ci-dessus — ajouter uniquement project_id
  (cd "$path" && bd config set gitlab.project_id "$gl_project_id") \
    || { log_error "Échec de la configuration GitLab"; exit 1; }

  log_success "GitLab configuré pour $id"
  echo ""
  log_info "Tester la connexion : ./oc.sh beads tracker status $id"
  log_info "Synchroniser        : ./oc.sh beads sync $id --pull-only --dry-run"
}

# ══════════════════════════════════════════
# Sous-commande : create
# ══════════════════════════════════════════
cmd_create() {
  require_project_id "$1"
  _require_bd

  local id
  id=$(normalize_project_id "$1")
  shift  # consommer PROJECT_ID — les args restants sont titre + flags

  local path
  path=$(resolve_project_path "$id")
  _require_beads_init "$path" "$id"

  # ── Parser les flags optionnels ────────────────────────────────────────────
  local title="" label="" type="" desc=""
  local positional_done=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --label) shift; label="${1:-}"; shift ;;
      --type)  shift; type="${1:-}";  shift ;;
      --desc)  shift; desc="${1:-}";  shift ;;
      --*)     log_error "Flag inconnu : $1"; exit 1 ;;
      *)
        if [ "$positional_done" = false ]; then
          title="$1"
          positional_done=true
        fi
        shift
        ;;
    esac
  done

  # ── Mode non-interactif (titre fourni) ─────────────────────────────────────
  if [ -n "$title" ]; then
    local bd_args=("create" "$title")
    [ -n "$label" ] && bd_args+=("--label" "$label")
    [ -n "$type"  ] && bd_args+=("--type"  "$type")
    [ -n "$desc"  ] && bd_args+=("--desc"  "$desc")

    log_info "$(t beads.create.creating) ${id}…"
    (cd "$path" && bd "${bd_args[@]}") || { log_error "$(t beads.create.failed)"; exit 1; }
    return 0
  fi

  # ── Mode interactif minimal ────────────────────────────────────────────────
  log_title "$(t beads.create.title) $id"
  echo ""

  read -rp "  Titre : " title
  [ -z "$title" ] && { log_error "$(t beads.create.title_required)"; exit 1; }

  if [ -z "$label" ]; then
    read -rp "  Label (laisser vide pour ignorer) : " label
  fi

  if [ -z "$type" ]; then
    read -rp "  Type (feature|fix|chore, laisser vide pour ignorer) : " type
  fi

  local bd_args=("create" "$title")
  [ -n "$label" ] && bd_args+=("--label" "$label")
  [ -n "$type"  ] && bd_args+=("--type"  "$type")
  [ -n "$desc"  ] && bd_args+=("--desc"  "$desc")

  echo ""
  log_info "$(t beads.create.creating) ${id}…"
  (cd "$path" && bd "${bd_args[@]}") || { log_error "$(t beads.create.failed)"; exit 1; }
}

# ── Dispatch (exécuté seulement si le script est lancé directement) ────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  source "$(cd "$(dirname "$0")" && pwd)/common.sh"
  resolve_oc_lang

  SUBCMD="${1:-}"
  # NOTE : pour la sous-commande "tracker", $2 vaut la sous-sous-commande (setup/status/switch),
  # pas le PROJECT_ID. Le PROJECT_ID est alors $3. Voir le dispatch ci-dessous.
  PROJECT_ID="${2:-}"

  case "$SUBCMD" in
    status)  cmd_status  "$PROJECT_ID" ;;
    init)    cmd_init    "$PROJECT_ID" ;;
    list)    cmd_list    "$PROJECT_ID" ;;
    create)  cmd_create  "$PROJECT_ID" "${@:3}" ;;
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
          echo -e "${BOLD}$(t beads.tracker.usage)${RESET}"
          ;;
        *) log_error "$(t beads.tracker.unknown_subcmd) $TRACKER_SUBCMD"; exit 1 ;;
      esac
      ;;
    ""|--help|-h) _beads_usage ;;
    *)
      log_error "Sous-commande inconnue : $SUBCMD"
      _beads_usage
      exit 1
      ;;
  esac
fi

