#!/bin/bash
# Affiche le statut de tous les projets enregistrés.
# Usage : ./oc.sh status
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
source "$LIB_DIR/adapter-manager.sh"

# ── Helpers d'affichage ───────────────────────────────────────────────────────

_status_ok()   { printf "    ${GREEN}✔${RESET}  %s\n" "$*"; }
_status_warn() { printf "    ${YELLOW}⚠${RESET}  %s\n" "$*"; }
_status_info() { printf "    ${BLUE}·${RESET}  %s\n" "$*"; }

# ── Lecture de tous les PROJECT_ID depuis projects.md ────────────────────────

_list_project_ids() {
  [ -f "$PROJECTS_FILE" ] || return 0
  grep '^## ' "$PROJECTS_FILE" | sed 's/^## //' | grep -v '^$'
}

# ── Statut d'un projet ───────────────────────────────────────────────────────

_show_project_status() {
  local id="$1"
  echo ""
  echo -e "  ${BOLD}${id}${RESET}"

  # ── Chemin local ──────────────────────────────────────────────────────────
  local path=""
  path=$(get_project_path "$id" 2>/dev/null || true)
  path="${path/#\~/$HOME}"

  if [ -z "$path" ]; then
    _status_warn "Chemin local non configuré (paths.local.md)"
  elif [ ! -d "$path" ]; then
    _status_warn "Dossier introuvable : $path"
    path=""
  else
    _status_info "Chemin : $path"
  fi

  # ── Beads initialisé ──────────────────────────────────────────────────────
  if [ -n "$path" ] && [ -d "$path/.beads" ]; then
    _status_ok "Beads initialisé"
  else
    _status_warn "Beads non initialisé  (./oc.sh beads init $id)"
  fi

  # ── Clé API configurée ────────────────────────────────────────────────────
  if api_keys_entry_exists "$id"; then
    local provider model
    provider=$(get_project_api_provider "$id")
    model=$(get_project_api_model "$id")
    local detail=""
    [ -n "$provider" ] && detail="${provider}"
    [ -n "$model" ]    && detail="${detail:+${detail} / }${model}"
    _status_ok "API configurée${detail:+ (${detail})}"
  else
    _status_warn "Clé API non configurée  (./oc.sh config $id)"
  fi

  # ── Tracker ───────────────────────────────────────────────────────────────
  local tracker
  tracker=$(get_project_tracker "$id")
  case "$tracker" in
    none|"") _status_info "Tracker : aucun" ;;
    *)       _status_ok   "Tracker : $tracker" ;;
  esac

  # ── Agents déployés (cible par défaut) ────────────────────────────────────
  if [ -n "$path" ]; then
    local default_target
    default_target=$(get_default_target)
    local agents_dir=""
    case "$default_target" in
      opencode)    agents_dir="$path/.opencode/agents" ;;
      claude-code) agents_dir="$path/.claude/agents" ;;
      vscode)      agents_dir="$path/.vscode/prompts" ;;
    esac

    if [ -n "$agents_dir" ] && [ -d "$agents_dir" ]; then
      local count
      count=$(find "$agents_dir" -name "*.md" -o -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
      _status_ok "Agents déployés (${default_target}) : ${count} fichier(s)"
    else
      _status_warn "Agents non déployés pour ${default_target}  (./oc.sh deploy all $id)"
    fi
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

ensure_projects_file

log_title "Statut des projets"

project_ids=$(_list_project_ids)

if [ -z "$project_ids" ]; then
  echo ""
  log_warn "Aucun projet enregistré — démarrer avec : ./oc.sh init"
  echo ""
  exit 0
fi

while IFS= read -r pid; do
  _show_project_status "$pid"
done <<< "$project_ids"

echo ""
