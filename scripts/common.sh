#!/bin/bash

# ─────────────────────────────────────────
# PATHS
# ─────────────────────────────────────────
HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_FILE="$HUB_DIR/projects/projects.md"
PROJECTS_EXAMPLE_FILE="$HUB_DIR/projects/projects.example.md"
PATHS_FILE="$HUB_DIR/projects/paths.local.md"
SKILLS_DIR="$HUB_DIR/skills"
SCRIPTS_DIR="$HUB_DIR/scripts"

# Phase 2+ : sources canoniques (agents/ et config/)
CANONICAL_AGENTS_DIR="$HUB_DIR/agents"
HUB_CONFIG="$HUB_DIR/config/hub.json"
LIB_DIR="$HUB_DIR/scripts/lib"
ADAPTERS_DIR="$HUB_DIR/scripts/adapters"
EXTERNAL_SKILLS_DIR="$HUB_DIR/skills/external"

# ─────────────────────────────────────────
# COLORS
# ─────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ─────────────────────────────────────────
# LOGGERS
# ─────────────────────────────────────────
log_info()    { echo -e "${BLUE}ℹ${RESET}  $*"; }
log_success() { echo -e "${GREEN}✔${RESET}  $*"; }
log_warn()    { echo -e "${YELLOW}⚠${RESET}  $*" >&2; }
log_error()   { echo -e "${RED}✘${RESET}  $*" >&2; }
log_title()   { echo -e "\n${BOLD}$*${RESET}"; }

# ─────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────

# S'assure que projects.md existe localement (copié depuis projects.example.md si absent)
ensure_projects_file() {
  if [ ! -f "$PROJECTS_FILE" ]; then
    if [ -f "$PROJECTS_EXAMPLE_FILE" ]; then
      cp "$PROJECTS_EXAMPLE_FILE" "$PROJECTS_FILE"
      log_info "projects.md créé depuis projects.example.md"
    else
      mkdir -p "$(dirname "$PROJECTS_FILE")"
      cat > "$PROJECTS_FILE" <<'PROJEOF'
# Registre des projets

<!-- FORMAT
## <PROJECT_ID>
- Nom : <nom lisible>
- Stack : <technologies>
- Board Beads : <PROJECT_ID>
- Tracker : <jira|gitlab|none>
- Labels : <liste séparée par virgules>
-->

---

*Aucun projet enregistré pour l'instant.*
*Ajouter un projet : ./oc.sh init*
PROJEOF
      log_info "projects.md créé"
    fi
  fi
}

# Vérifie qu'un PROJECT_ID est fourni
require_project_id() {
  local id="${1:-}"
  if [ -z "$id" ]; then
    log_error "PROJECT_ID requis"
    exit 1
  fi
}

# Retourne le chemin local d'un projet
# Retourne 1 si paths.local.md est absent (ne fait pas exit pour permettre l'usage en subshell)
get_project_path() {
  local id="$1"
  if [ ! -f "$PATHS_FILE" ]; then
    log_warn "Fichier paths.local.md introuvable — chemin local non disponible" >&2
    return 1
  fi
  grep "^${id}=" "$PATHS_FILE" | cut -d'=' -f2- | tr -d ' '
}

# Vérifie qu'un projet existe dans projects.md
project_exists() {
  local id="$1"
  grep -q "^## ${id}$" "$PROJECTS_FILE" 2>/dev/null
}

# Vérifie qu'un chemin existe dans paths.local.md
path_exists() {
  local id="$1"
  grep -q "^${id}=" "$PATHS_FILE" 2>/dev/null
}

# Normalise un PROJECT_ID en majuscules
normalize_project_id() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Retourne le provider de tracker d'un projet (jira|gitlab|none)
# Lit le champ "Tracker :" dans projects.md
get_project_tracker() {
  local id="$1"
  local tracker
  tracker=$(awk "/^## ${id}$/{found=1} found && /^- Tracker :/{print; exit}" "$PROJECTS_FILE" \
    | sed 's/^- Tracker : *//' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
  echo "${tracker:-none}"
}

# Retourne la langue de travail d'un projet (ex: "english", "spanish")
# Lit le champ "Langue :" dans projects.md
# Retourne une chaîne vide si le champ est absent (comportement par défaut : français)
get_project_language() {
  local id="$1"
  local lang
  lang=$(awk "/^## ${id}$/{found=1} found && /^- Langue :/{print; exit}" "$PROJECTS_FILE" \
    | sed 's/^- Langue : *//' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
  echo "${lang:-}"
}

# Detect OS
detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    *)       echo "unknown" ;;
  esac
}
