#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# ── Parsing des arguments ─────────────────
CLEAN_MODE=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN_MODE=true ;;
    *)       ARGS+=("$arg") ;;
  esac
done

PROJECT_ID="${ARGS[0]:-}"
require_project_id "$PROJECT_ID"
PROJECT_ID=$(normalize_project_id "$PROJECT_ID")

# ── Confirmation ──────────────────────────
if ! project_exists "$PROJECT_ID"; then
  log_error "Projet $PROJECT_ID introuvable dans le registre"
  exit 1
fi

# Résoudre le chemin AVANT suppression du registre (nécessaire pour --clean)
PROJECT_PATH=""
if [ "$CLEAN_MODE" = true ]; then
  PROJECT_PATH=$(get_project_path "$PROJECT_ID" 2>/dev/null || true)
  PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"
  if [ -z "$PROJECT_PATH" ] || [ ! -d "$PROJECT_PATH" ]; then
    log_warn "Chemin local introuvable pour $PROJECT_ID — --clean ignoré"
    CLEAN_MODE=false
  fi
fi

if [ "$CLEAN_MODE" = true ]; then
  read -rp "$(echo -e "  ${YELLOW}⚠${RESET}  Supprimer $PROJECT_ID du registre ET nettoyer les fichiers déployés dans $PROJECT_PATH ? [y/N] ")" confirm
else
  read -rp "$(echo -e "  ${YELLOW}⚠${RESET}  Supprimer $PROJECT_ID ? [y/N] ")" confirm
fi
[[ "$confirm" =~ ^[Yy]$ ]] || { log_info "Annulé"; exit 0; }

# ── Nettoyage des fichiers déployés (--clean) ─────────────────────────────
if [ "$CLEAN_MODE" = true ]; then
  source "$LIB_DIR/adapter-manager.sh"

  # Déterminer les cibles actives
  local_targets=""
  local_targets=$(get_active_targets 2>/dev/null || echo "opencode")

  log_info "Nettoyage des fichiers déployés dans $PROJECT_PATH…"

  while IFS= read -r tgt; do
    case "$tgt" in
      opencode)
        # .opencode/agents/ et opencode.json
        if [ -d "$PROJECT_PATH/.opencode/agents" ]; then
          rm -rf "$PROJECT_PATH/.opencode/agents"
          log_success "Supprimé : .opencode/agents/"
        fi
        if [ -f "$PROJECT_PATH/opencode.json" ]; then
          rm -f "$PROJECT_PATH/opencode.json"
          log_success "Supprimé : opencode.json"
        fi
        ;;
      claude-code)
        if [ -d "$PROJECT_PATH/.claude/agents" ]; then
          rm -rf "$PROJECT_PATH/.claude/agents"
          log_success "Supprimé : .claude/agents/"
        fi
        if [ -f "$PROJECT_PATH/.github/copilot-instructions.md" ]; then
          rm -f "$PROJECT_PATH/.github/copilot-instructions.md"
          log_success "Supprimé : .github/copilot-instructions.md"
        fi
        ;;
      vscode)
        if [ -d "$PROJECT_PATH/.vscode/prompts" ]; then
          rm -rf "$PROJECT_PATH/.vscode/prompts"
          log_success "Supprimé : .vscode/prompts/"
        fi
        ;;
    esac
  done <<< "$local_targets"
fi

# ── Supprimer du projects.md ──────────────
# Supprime le bloc ## PROJECT_ID jusqu'au prochain ## ou fin de fichier
command -v perl &>/dev/null || { log_error "perl requis pour cette opération"; exit 1; }
perl -i.bak -0pe 's/\n## \Q'"${PROJECT_ID}"'\E\n.*?(?=\n## |\z)//s' "$PROJECTS_FILE" \
  && rm -f "${PROJECTS_FILE}.bak"
log_success "Projet $PROJECT_ID supprimé de projects.md"

# ── Supprimer du paths.local.md ───────────
if path_exists "$PROJECT_ID"; then
  sed -i.bak "/^${PROJECT_ID}=/d" "$PATHS_FILE" && rm -f "${PATHS_FILE}.bak"
  log_success "Chemin supprimé de paths.local.md"
fi

# ── Supprimer de api-keys.local.md ────────
if api_keys_entry_exists "$PROJECT_ID"; then
  remove_api_keys_section "$PROJECT_ID"
  log_success "Clé API supprimée de api-keys.local.md"
fi

echo ""
log_success "$PROJECT_ID retiré du registre"
