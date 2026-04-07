#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ensure_projects_file

# ── Parsing des arguments (--dev, --onboard, --label, --assignee sont des flags libres) ───
DEV_MODE=false
ONBOARD_MODE=false
DEV_LABEL=""
DEV_ASSIGNEE=""
AGENT_NAME=""
ARGS=()
_prev=""
for arg in "$@"; do
  case "$_prev" in
    --label)    DEV_LABEL="$arg";    _prev=""; continue ;;
    --assignee) DEV_ASSIGNEE="$arg"; _prev=""; continue ;;
    --agent)    AGENT_NAME="$arg";   _prev=""; continue ;;
  esac
  case "$arg" in
    --dev)      DEV_MODE=true ;;
    --onboard)  ONBOARD_MODE=true ;;
    --label|--assignee|--agent) _prev="$arg" ;;
    *)          ARGS+=("$arg") ;;
  esac
done
PROJECT_ID="${ARGS[0]:-}"
PROMPT="${ARGS[1]:-}"

# --dev et --onboard sont mutuellement exclusifs
if [ "$DEV_MODE" = true ] && [ "$ONBOARD_MODE" = true ]; then
  log_error "--dev et --onboard sont mutuellement exclusifs"
  exit 1
fi

# --label et --assignee nécessitent --dev
if { [ -n "$DEV_LABEL" ] || [ -n "$DEV_ASSIGNEE" ]; } && [ "$DEV_MODE" = false ]; then
  log_error "--label et --assignee nécessitent --dev"
  exit 1
fi

# --label et --assignee sont mutuellement exclusifs
if [ -n "$DEV_LABEL" ] && [ -n "$DEV_ASSIGNEE" ]; then
  log_error "--label et --assignee sont mutuellement exclusifs"
  exit 1
fi

# ── Sélection interactive si pas d'ID ─────
if [ -z "$PROJECT_ID" ]; then
  ids=()
  while IFS= read -r line; do ids+=("$line"); done < <(grep "^## " "$PROJECTS_FILE" | sed 's/^## //')

  if [ ${#ids[@]} -eq 0 ]; then
    log_error "Aucun projet enregistré → ./oc.sh init"
    exit 1
  fi

  echo -e "${BOLD}Choisir un projet :${RESET}"
  echo ""
  for i in "${!ids[@]}"; do
    printf "  ${BLUE}%d${RESET}) %s\n" "$((i+1))" "${ids[$i]}"
  done
  echo ""
  read -rp "  Numéro : " choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#ids[@]}" ]; then
    log_error "Choix invalide : $choice (attendu 1-${#ids[@]})"
    exit 1
  fi
  PROJECT_ID="${ids[$((choice-1))]}"
fi

PROJECT_ID=$(normalize_project_id "$PROJECT_ID")

# ── Validation + résolution du chemin ─────
PROJECT_PATH=$(resolve_project_path "$PROJECT_ID")

# ── Résolution de la cible ────────────────
source "$LIB_DIR/adapter-manager.sh"
default_target=$(get_default_target)

load_adapter "$default_target"
adapter_validate || { log_error "Cible '$default_target' non disponible → oc install (puis sélectionner $default_target)"; exit 1; }

# ── Vérifier que les agents sont déployés ──────────────
case "$default_target" in
  opencode)    agents_dir="$PROJECT_PATH/.opencode/agents" ;;
  claude-code) agents_dir="$PROJECT_PATH/.claude/agents" ;;
  vscode)      agents_dir="$PROJECT_PATH/.vscode/prompts" ;;
  *)           agents_dir="" ;;
esac

# ── Bloc contextuel ───────────────────────────────────────────────────────────
_intro "${PROJECT_ID}"
printf "${DIM}│${RESET}  %-10s %s\n" "Chemin"  "$PROJECT_PATH"
printf "${DIM}│${RESET}  %-10s %s\n" "Cible"   "$default_target"

# Agents non déployés : proposer le déploiement
if [ -n "$agents_dir" ] && [ ! -d "$agents_dir" ]; then
  echo -e "${DIM}│${RESET}"
  log_warn "Agents non déployés pour ${default_target}"
  _prompt _deploy_now "Déployer maintenant ? [Y/n] : "
  if [[ "${_deploy_now:-Y}" =~ ^[Yy]$ ]]; then
    echo ""
    bash "$SCRIPTS_DIR/cmd-deploy.sh" "$default_target" "$PROJECT_ID"
    echo ""
  else
    log_info "Déployer plus tard : ./oc.sh deploy ${default_target} ${PROJECT_ID}"
  fi
fi

# Suggestion onboarder si les agents sont déployés
if [ -n "$agents_dir" ] && [ -d "$agents_dir" ] && [ "$ONBOARD_MODE" = false ]; then
  echo -e "${DIM}│${RESET}"
  echo -e "${DIM}│${RESET}  ${CYAN}→${RESET} Nouveau sur ce projet ? Invoke l'agent ${BOLD}onboarder${RESET}"
  echo -e "${DIM}│${RESET}    \"Onboarde-toi sur ce projet\""
  echo -e "${DIM}│${RESET}  ${CYAN}→${RESET} Ou lance directement : ${BOLD}./oc.sh start --onboard $PROJECT_ID${RESET}"
fi

echo -e "${DIM}│${RESET}"

# ── Vérifier que Beads est initialisé dans le projet ───
if [ ! -d "$PROJECT_PATH/.beads" ]; then
  if [ "$DEV_MODE" = true ]; then
    log_error "--dev requiert Beads initialisé dans ce projet"
    log_error "Lancez d'abord : ./oc.sh beads init $PROJECT_ID"
    exit 1
  elif command -v bd &>/dev/null; then
    echo ""
    log_warn "Beads non initialisé dans ce projet (aucun .beads/ trouvé)"
    _prompt _init_beads "Initialiser Beads maintenant ? [Y/n] : "
    if [[ "${_init_beads:-Y}" =~ ^[Yy]$ ]]; then
      if (cd "$PROJECT_PATH" && bd init); then
        log_success "Beads initialisé dans $PROJECT_PATH"
        # Proposer de configurer l'upstream git si absent (ni upstream ni origin trouvé)
        if ! (cd "$PROJECT_PATH" && git remote get-url upstream) &>/dev/null && \
           ! (cd "$PROJECT_PATH" && git remote get-url origin) &>/dev/null; then
          echo ""
          _prompt _setup_upstream "Configurer l'upstream Git (git remote add upstream) ? [Y/n] : "
          if [[ "${_setup_upstream:-Y}" =~ ^[Yy]$ ]]; then
            _prompt _upstream_url "URL du remote upstream : "
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
        # Enregistrer les labels depuis projects.md dans la config Beads
        _start_labels=$(get_project_labels "$PROJECT_ID")
        if [ -n "$_start_labels" ]; then
          log_info "Enregistrement des labels dans la config Beads…"
          if (cd "$PROJECT_PATH" && bd config set custom.labels "$_start_labels"); then
            log_success "Labels enregistrés : $_start_labels"
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
  else
    echo ""
    log_warn "Beads non initialisé dans ce projet (aucun .beads/ trouvé)"
    log_warn "Pour utiliser les tickets : ./oc.sh beads init $PROJECT_ID"
  fi
fi

# ── Mode --dev : sync auto + bootstrap prompt ai-delegated ──
if [ "$DEV_MODE" = true ]; then
  if ! command -v bd &>/dev/null; then
    log_error "--dev requiert bd (Beads) : brew install bd"
    exit 1
  fi

  # Sync non-bloquant : pull les derniers tickets avant injection
  _tracker=$(get_project_tracker "$PROJECT_ID")
  if [ "$_tracker" != "none" ]; then
    echo ""
    log_info "Sync ${_tracker} --pull-only avant démarrage…"
    if (cd "$PROJECT_PATH" && bd "$_tracker" sync --pull-only) 2>/dev/null; then
      log_success "Sync $_tracker terminé"
    else
      log_warn "Sync $_tracker échoué — les tickets locaux seront utilisés"
    fi
  fi

  if [ "$default_target" = "vscode" ]; then
    log_warn "--dev ignoré pour la cible vscode (pas de support prompt)"
  else
    source "$LIB_DIR/prompt-builder.sh"
    PROMPT=$(build_dev_bootstrap_prompt "$PROJECT_PATH" "$DEV_LABEL" "$DEV_ASSIGNEE")
    AGENT_NAME="${AGENT_NAME:-orchestrator-dev}"
    echo ""
    if [ -n "$DEV_ASSIGNEE" ]; then
      log_info "Mode --dev  tickets assignés à '${DEV_ASSIGNEE}'  agent: ${AGENT_NAME}"
    elif [ -n "$DEV_LABEL" ]; then
      log_info "Mode --dev  tickets label '${DEV_LABEL}'  agent: ${AGENT_NAME}"
    else
      log_info "Mode --dev  tickets ai-delegated  agent: ${AGENT_NAME}"
    fi
  fi
fi

# ── Mode --onboard : prompt de découverte projet ────────────────────────────
if [ "$ONBOARD_MODE" = true ]; then
  if [ "$default_target" = "vscode" ]; then
    log_warn "--onboard ignoré pour la cible vscode (pas de support prompt)"
  else
    source "$LIB_DIR/prompt-builder.sh"
    PROMPT=$(build_onboard_bootstrap_prompt "$PROJECT_PATH" "$PROJECT_ID" "$HUB_DIR")
    AGENT_NAME="${AGENT_NAME:-onboarder}"
    echo ""
    log_info "Mode --onboard  découverte projet activée  agent: ${AGENT_NAME}"
  fi
fi

# ── Confirmation avant lancement ──────────────────────────────────────────────
_outro "Lancement de ${default_target}…"
IFS= read -rp "" _

adapter_start "$PROJECT_PATH" "$PROMPT" "$PROJECT_ID" "${AGENT_NAME:-}"
