#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# ── Parsing des arguments (--dev est un flag libre) ───
DEV_MODE=false
ARGS=()
for arg in "$@"; do
  [ "$arg" = "--dev" ] && DEV_MODE=true || ARGS+=("$arg")
done
PROJECT_ID="${ARGS[0]:-}"
PROMPT="${ARGS[1]:-}"

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

# ── Validations ───────────────────────────
if ! project_exists "$PROJECT_ID"; then
  log_error "Projet $PROJECT_ID introuvable → ./oc.sh list"
  exit 1
fi

PROJECT_PATH=$(get_project_path "$PROJECT_ID")
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

if [ -z "$PROJECT_PATH" ]; then
  log_error "Aucun chemin local pour $PROJECT_ID → ./oc.sh init $PROJECT_ID"
  exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
  log_error "Dossier introuvable : $PROJECT_PATH"
  exit 1
fi

# ── Lancement via adaptateur ─────────────
log_info "Projet   : $PROJECT_ID"
log_info "Dossier  : $PROJECT_PATH"

source "$LIB_DIR/adapter-manager.sh"
default_target=$(get_default_target)
log_info "Cible    : $default_target"
echo ""

load_adapter "$default_target"
adapter_validate || { log_error "Cible '$default_target' non disponible → oc install (puis sélectionner $default_target)"; exit 1; }

# ── Vérifier que les agents sont déployés ──────────────
case "$default_target" in
  opencode)    agents_dir="$PROJECT_PATH/.opencode/agents" ;;
  claude-code) agents_dir="$PROJECT_PATH/.claude/agents" ;;
  vscode)      agents_dir="$PROJECT_PATH/.vscode/prompts" ;;
  *)           agents_dir="" ;;
esac

if [ -n "$agents_dir" ] && [ ! -d "$agents_dir" ]; then
  log_warn "Agents non déployés dans ce projet pour la cible $default_target"
  log_warn "Lancez d'abord : ./oc.sh deploy $default_target $PROJECT_ID"
fi

# ── Vérifier que Beads est initialisé dans le projet ───
if [ ! -d "$PROJECT_PATH/.beads" ]; then
  if [ "$DEV_MODE" = true ]; then
    log_error "--dev requiert Beads initialisé dans ce projet"
    log_error "Lancez d'abord : ./oc.sh beads init $PROJECT_ID"
    exit 1
  else
    log_warn "Beads non initialisé dans ce projet (aucun .beads/ trouvé)"
    log_warn "Pour utiliser les tickets : ./oc.sh beads init $PROJECT_ID"
  fi
fi

# ── Mode --dev : bootstrap prompt ai-delegated ─────────
if [ "$DEV_MODE" = true ]; then
  if ! command -v bd &>/dev/null; then
    log_error "--dev requiert bd (Beads) : brew install bd"
    exit 1
  fi
  if [ "$default_target" = "vscode" ]; then
    log_warn "--dev ignoré pour la cible vscode (pas de support prompt)"
  else
    source "$LIB_DIR/prompt-builder.sh"
    PROMPT=$(build_dev_bootstrap_prompt "$PROJECT_PATH")
    log_info "Mode --dev : bootstrap tickets ai-delegated activé"
  fi
fi

adapter_start "$PROJECT_PATH" "$PROMPT"
