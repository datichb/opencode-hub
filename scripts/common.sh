#!/bin/bash

# ─────────────────────────────────────────
# PATHS
# ─────────────────────────────────────────
HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_FILE="$HUB_DIR/projects/projects.md"
PATHS_FILE="$HUB_DIR/projects/paths.local.md"
SKILLS_DIR="$HUB_DIR/skills"
AGENTS_DIR="$HUB_DIR/.opencode/agents"
SCRIPTS_DIR="$HUB_DIR/scripts"

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
log_warn()    { echo -e "${YELLOW}⚠${RESET}  $*"; }
log_error()   { echo -e "${RED}✘${RESET}  $*" >&2; }
log_title()   { echo -e "\n${BOLD}$*${RESET}"; }

# ─────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────

# Vérifie qu'un PROJECT_ID est fourni
require_project_id() {
  local id="${1:-}"
  if [ -z "$id" ]; then
    log_error "PROJECT_ID requis"
    exit 1
  fi
}

# Retourne le chemin local d'un projet
get_project_path() {
  local id="$1"
  if [ ! -f "$PATHS_FILE" ]; then
    log_error "Fichier paths.local.md introuvable"
    exit 1
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

# Detect OS
detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    *)       echo "unknown" ;;
  esac
}
