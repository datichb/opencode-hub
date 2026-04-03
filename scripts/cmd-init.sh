#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
source "$LIB_DIR/agent-picker.sh"
source "$LIB_DIR/target-picker.sh"

# S'assurer que projects.md existe avant toute opération
ensure_projects_file

PROJECT_ID="${1:-}"
PROJECT_PATH="${2:-}"

# ── Helper d'affichage wizard ──────────────────────────────────────────────────
_step() {
  local num="$1" total="$2" label="$3"
  local width=52
  local title="── Étape ${num}/${total} — ${label} "
  # Compléter jusqu'à width caractères avec des tirets
  local title_len=${#title}
  local pad=""
  local i=0
  while [ "$i" -lt $(( width - title_len )) ]; do
    pad="${pad}─"
    i=$(( i + 1 ))
  done
  echo ""
  echo -e "${BOLD}${title}${pad}${RESET}"
  echo ""
}

# ── Récapitulatif final ────────────────────────────────────────────────────────
_summary() {
  local id="$1" path="$2" name="$3" stack="$4" tracker="$5" beads_ok="$6"
  local width=54
  local bar=""
  local i=0
  while [ "$i" -lt "$width" ]; do bar="${bar}─"; i=$(( i + 1 )); done

  echo ""
  echo -e "${GREEN}┌─ ${BOLD}${id} initialisé${RESET}${GREEN} ${bar:0:$(( width - ${#id} - 14 ))}┐${RESET}"
  printf "${GREEN}│${RESET}  %-12s %-38s ${GREEN}│${RESET}\n" "Chemin"  "${path:0:38}"
  [ -n "$name"  ] && printf "${GREEN}│${RESET}  %-12s %-38s ${GREEN}│${RESET}\n" "Nom"    "${name:0:38}"
  [ -n "$stack" ] && printf "${GREEN}│${RESET}  %-12s %-38s ${GREEN}│${RESET}\n" "Stack"  "${stack:0:38}"
  printf "${GREEN}│${RESET}  %-12s %-38s ${GREEN}│${RESET}\n" "Tracker" "${tracker}"
  if [ "$beads_ok" = "1" ]; then
    printf "${GREEN}│${RESET}  %-12s %-38s ${GREEN}│${RESET}\n" "Beads" "✔ initialisé"
  else
    printf "${GREEN}│${RESET}  %-12s %-38s ${GREEN}│${RESET}\n" "Beads" "non initialisé  (./oc.sh beads init ${id})"
  fi
  echo -e "${GREEN}│${RESET}"
  printf "${GREEN}│${RESET}  %-52s ${GREEN}│${RESET}\n" "Prochain → ./oc.sh start ${id}"
  echo -e "${GREEN}└─${bar}┘${RESET}"
  echo ""
}

# ── Titre de la commande ───────────────────────────────────────────────────────
log_title "Initialisation d'un projet"

# ─────────────────────────────────────────────────────────────────────────────
# ÉTAPE 1 — Informations projet
# ─────────────────────────────────────────────────────────────────────────────
_step 1 4 "Informations projet"

if [ -z "$PROJECT_ID" ]; then
  read -rp "  PROJECT_ID (ex: MON-APP) : " PROJECT_ID
fi

PROJECT_ID=$(normalize_project_id "$PROJECT_ID")

# Validation du format PROJECT_ID : lettres, chiffres, tirets et underscores uniquement
if ! echo "$PROJECT_ID" | grep -qE '^[A-Z0-9_-]+$'; then
  log_error "PROJECT_ID invalide : '$PROJECT_ID'"
  log_info  "Caractères autorisés : lettres, chiffres, tirets (-) et underscores (_). Pas d'espaces ni de slashes."
  exit 1
fi

if [ -z "$PROJECT_PATH" ]; then
  read -rp "  Chemin local (ex: ~/workspace/mon-app) : " PROJECT_PATH
fi

# Expand ~ manuellement
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

if project_exists "$PROJECT_ID"; then
  log_warn "Le projet $PROJECT_ID existe déjà dans le registre"
  PROJECT_NAME=""
  PROJECT_STACK=""
  PROJECT_LABELS=""
  PROJECT_TRACKER="none"
else
  read -rp "  Nom complet : "                             PROJECT_NAME
  read -rp "  Stack (ex: Vue 3 + Laravel) : "            PROJECT_STACK
  read -rp "  Labels Beads (ex: feature,fix,front,back) : " PROJECT_LABELS

  echo ""
  echo -e "  ${BOLD}Tracker externe (optionnel) :${RESET}"
  echo   "    1) Aucun"
  echo   "    2) Jira"
  echo   "    3) GitLab"
  echo ""
  read -rp "  Choix [1] : " tracker_choice
  case "${tracker_choice:-1}" in
    2) PROJECT_TRACKER="jira" ;;
    3) PROJECT_TRACKER="gitlab" ;;
    *)  PROJECT_TRACKER="none" ;;
  esac

  # Ajouter dans projects.md
  cat >> "$PROJECTS_FILE" <<EOF

## $PROJECT_ID
- Nom : ${PROJECT_NAME:-$PROJECT_ID}
- Stack : ${PROJECT_STACK:-N/A}
- Board Beads : $PROJECT_ID
- Tracker : ${PROJECT_TRACKER}
- Labels : ${PROJECT_LABELS:-feature,fix}
- Agents : all
EOF

  log_success "Projet $PROJECT_ID ajouté dans projects.md"
fi

# ── Chemin local ───────────────────────────────────────────────────────────────
if path_exists "$PROJECT_ID"; then
  log_warn "Chemin déjà enregistré pour $PROJECT_ID"
else
  if [ ! -d "$PROJECT_PATH" ]; then
    read -rp "  Le dossier $PROJECT_PATH n'existe pas. Le créer ? [Y/n] : " create_dir
    if [[ "${create_dir:-Y}" =~ ^[Yy]$ ]]; then
      mkdir -p "$PROJECT_PATH"
      log_success "Dossier créé : $PROJECT_PATH"
    else
      log_warn "Le dossier $PROJECT_PATH n'existe pas encore — Beads et le déploiement seront ignorés"
    fi
  fi
  echo "${PROJECT_ID}=${PROJECT_PATH}" >> "$PATHS_FILE"
  log_success "Chemin enregistré dans paths.local.md"
fi

# ─────────────────────────────────────────────────────────────────────────────
# ÉTAPE 2 — Beads
# ─────────────────────────────────────────────────────────────────────────────
_step 2 4 "Beads & tracker"

BEADS_OK=0

# Vérifier que bd est disponible
if ! command -v bd &>/dev/null; then
  log_warn "Beads (bd) n'est pas installé — nécessaire pour la gestion des tickets"
  read -rp "  Installer Beads maintenant ? [Y/n] : " install_bd
  if [[ "${install_bd:-Y}" =~ ^[Yy]$ ]]; then
    if command -v brew &>/dev/null; then
      brew install bd && log_success "Beads installé" \
        || log_warn "Échec de l'installation — installer manuellement : brew install bd"
    else
      log_warn "Homebrew non disponible — installer manuellement"
      log_info "  macOS  : brew install bd"
      log_info "  Linux  : voir https://beads.sh/install"
    fi
  else
    log_info "Installer plus tard : ./oc.sh install"
  fi
fi

# Proposer bd init dans le projet
if command -v bd &>/dev/null && [ -d "$PROJECT_PATH" ] && [ ! -d "$PROJECT_PATH/.beads" ]; then
  echo ""
  read -rp "  Initialiser Beads dans le projet ? [Y/n] : " init_beads
  if [[ "${init_beads:-Y}" =~ ^[Yy]$ ]]; then
    if (cd "$PROJECT_PATH" && bd init); then
      log_success "Beads initialisé dans $PROJECT_PATH"
      BEADS_OK=1

      # Proposer de configurer l'upstream git si absent
      if ! (cd "$PROJECT_PATH" && git remote get-url upstream) &>/dev/null; then
        echo ""
        read -rp "  Configurer l'upstream Git (git remote add upstream) ? [Y/n] : " _setup_upstream
        if [[ "${_setup_upstream:-Y}" =~ ^[Yy]$ ]]; then
          read -rp "  URL du remote upstream : " _upstream_url
          if [ -n "$_upstream_url" ]; then
            if (cd "$PROJECT_PATH" && git remote add upstream "$_upstream_url"); then
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

      # Enregistrer les labels dans la config Beads
      _init_labels="${PROJECT_LABELS:-feature,fix}"
      if [ -n "$_init_labels" ]; then
        log_info "Enregistrement des labels dans la config Beads…"
        if (cd "$PROJECT_PATH" && bd config set custom.labels "$_init_labels"); then
          log_success "Labels enregistrés : $_init_labels"
        else
          log_warn "Échec enregistrement labels dans Beads"
        fi
      fi
    else
      log_warn "Échec de bd init — initialiser plus tard : ./oc.sh beads init $PROJECT_ID"
    fi
  else
    log_info "Initialiser plus tard : ./oc.sh beads init $PROJECT_ID"
  fi
elif [ -d "$PROJECT_PATH/.beads" ]; then
  BEADS_OK=1
  log_info "Beads déjà initialisé dans ce projet"
else
  log_info "Beads non configuré — dossier absent ou bd indisponible. Initialiser plus tard : ./oc.sh beads init $PROJECT_ID"
fi

# Proposer la configuration du tracker si non-none
if [ "${PROJECT_TRACKER:-none}" != "none" ]; then
  if command -v bd &>/dev/null; then
    echo ""
    read -rp "  Configurer $PROJECT_TRACKER maintenant ? [Y/n] : " setup_now
    if [[ "${setup_now:-Y}" =~ ^[Yy]$ ]]; then
      bash "$SCRIPTS_DIR/cmd-beads.sh" tracker setup "$PROJECT_ID"
    else
      log_info "Configurer plus tard : ./oc.sh beads tracker setup $PROJECT_ID"
    fi
  else
    log_info "Configurer le tracker plus tard (bd requis) : ./oc.sh beads tracker setup $PROJECT_ID"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# ÉTAPE 3 — Agents & cibles
# ─────────────────────────────────────────────────────────────────────────────
_step 3 4 "Agents & cibles"

read -rp "  Sélectionner les agents à déployer ? [y/N] : " select_agents
if [[ "$select_agents" =~ ^[Yy]$ ]]; then
  PICKED_AGENTS=""
  _pick_agents "all"
  if [ -n "$PICKED_AGENTS" ] && [ "$PICKED_AGENTS" != "all" ]; then
    _set_project_agents "$PROJECT_ID" "$PICKED_AGENTS"
    _agent_count=$(echo "$PICKED_AGENTS" | tr ',' '\n' | wc -l | tr -d ' ')
    log_success "$_agent_count agent(s) sélectionné(s) pour $PROJECT_ID"
  else
    log_info "Tous les agents seront déployés (par défaut)"
  fi
else
  log_info "Tous les agents seront déployés (par défaut)"
fi

echo ""
read -rp "  Sélectionner les cibles de déploiement ? [y/N] : " select_targets
if [[ "$select_targets" =~ ^[Yy]$ ]]; then
  PICKED_TARGETS=""
  _pick_project_targets "all"
  if [ -n "$PICKED_TARGETS" ] && [ "$PICKED_TARGETS" != "all" ]; then
    _set_project_targets "$PROJECT_ID" "$PICKED_TARGETS"
    _target_count=$(echo "$PICKED_TARGETS" | tr ',' '\n' | grep -v '^$' | wc -l | tr -d ' ')
    log_success "$_target_count cible(s) sélectionnée(s) pour $PROJECT_ID"
  else
    log_info "Toutes les cibles actives seront utilisées (par défaut)"
  fi
else
  log_info "Toutes les cibles actives seront utilisées (par défaut)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# ÉTAPE 4 — Déploiement
# ─────────────────────────────────────────────────────────────────────────────
_step 4 4 "Déploiement"

if [ -d "$PROJECT_PATH" ]; then
  read -rp "  Déployer les agents maintenant ? [Y/n] : " deploy_now
  if [[ "${deploy_now:-Y}" =~ ^[Yy]$ ]]; then
    bash "$SCRIPTS_DIR/cmd-deploy.sh" all "$PROJECT_ID"
  else
    log_info "Déployer plus tard : ./oc.sh deploy all $PROJECT_ID"
  fi
else
  log_warn "Déploiement impossible — dossier $PROJECT_PATH introuvable"
fi

# ─────────────────────────────────────────────────────────────────────────────
# RÉCAPITULATIF
# ─────────────────────────────────────────────────────────────────────────────
_summary \
  "$PROJECT_ID" \
  "$PROJECT_PATH" \
  "${PROJECT_NAME:-}" \
  "${PROJECT_STACK:-}" \
  "${PROJECT_TRACKER:-none}" \
  "$BEADS_OK"
