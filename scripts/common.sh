#!/bin/bash

# ─────────────────────────────────────────
# PATHS
# ─────────────────────────────────────────
HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_FILE="${PROJECTS_FILE:-$HUB_DIR/projects/projects.md}"
PROJECTS_EXAMPLE_FILE="$HUB_DIR/projects/projects.example.md"
PATHS_FILE="${PATHS_FILE:-$HUB_DIR/projects/paths.local.md}"
API_KEYS_FILE="${API_KEYS_FILE:-$HUB_DIR/projects/api-keys.local.md}"
SKILLS_DIR="$HUB_DIR/skills"
SCRIPTS_DIR="$HUB_DIR/scripts"

# Phase 2+ : sources canoniques (agents/ et config/)
CANONICAL_AGENTS_DIR="$HUB_DIR/agents"
HUB_CONFIG="$HUB_DIR/config/hub.json"
LIB_DIR="$HUB_DIR/scripts/lib"
ADAPTERS_DIR="$HUB_DIR/scripts/adapters"
EXTERNAL_SKILLS_DIR="$HUB_DIR/skills/external"

# ─────────────────────────────────────────
# DEFAULTS
# ─────────────────────────────────────────
DEFAULT_MODEL="claude-sonnet-4-5"

# ─────────────────────────────────────────
# COLORS
# ─────────────────────────────────────────
RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[94m'
CYAN='\033[96m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─────────────────────────────────────────
# LOGGERS
# ─────────────────────────────────────────
log_info()    { echo -e "${BLUE}◆${RESET}  $*"; }
log_success() { echo -e "${GREEN}◆${RESET}  $*"; }
log_warn()    { echo -e "${YELLOW}◆${RESET}  $*" >&2; }
log_error()   { echo -e "${RED}◆${RESET}  $*" >&2; }
log_title()   { echo -e "\n${BOLD}$*${RESET}"; }

# ─────────────────────────────────────────
# TUI HELPERS — style opencode (@clack/prompts)
# ─────────────────────────────────────────

# Ouvre une commande : titre en gras + ligne de gouttière
# Usage : _intro "Titre de la commande"
_intro() {
  echo ""
  echo -e "${BOLD}◆  $*${RESET}"
  echo -e "${DIM}│${RESET}"
}

# Ferme une commande : ligne de clôture
# Usage : _outro "Message de fin"
_outro() {
  echo -e "${DIM}└${RESET}  $*"
  echo ""
}

# Affiche la gouttière + un prompt interactif
# Usage : _prompt VAR_NAME "Libellé du prompt : "
_prompt() {
  local _var="$1" _msg="$2"
  echo -e "${DIM}│${RESET}"
  IFS= read -rp "  ${_msg}" "$_var"
}

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
    log_warn "Fichier paths.local.md introuvable — chemin local non disponible"
    return 1
  fi
  # || true : évite que pipefail propage exit 1 si grep ne matche rien
  # head -1 : protection contre doublons dans paths.local.md
  # ^ : ancrage en début de ligne pour éviter les faux positifs (PROJ vs PROJ-FULL)
  grep "^${id}=" "$PATHS_FILE" | head -1 | cut -d'=' -f2- | tr -d ' ' || true
}

# Vérifie qu'un projet existe dans projects.md
# Utilise une comparaison de ligne exacte pour éviter les faux positifs
# (ex: "## PROJ" ne doit pas matcher "## PROJ-FR")
project_exists() {
  local id="$1"
  awk -v section="## ${id}" '$0 == section { found=1; exit } END { exit !found }' "$PROJECTS_FILE" 2>/dev/null
}

# Vérifie qu'un chemin existe dans paths.local.md
# ^ : ancrage en début de ligne pour éviter les faux positifs (PROJ vs PROJ-FULL)
path_exists() {
  local id="$1"
  grep -q "^${id}=" "$PATHS_FILE" 2>/dev/null
}

# Normalise un PROJECT_ID en majuscules
normalize_project_id() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Résout le chemin local d'un projet : normalise l'ID, vérifie l'existence,
# lit paths.local.md, expand ~, vérifie le dossier. Imprime le chemin sur stdout.
# Exit 1 avec message d'erreur si une étape échoue.
# @param $1 — PROJECT_ID (sera normalisé en majuscules)
resolve_project_path() {
  local id
  id=$(normalize_project_id "$1")

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

# Lit un champ "- <field> : <value>" dans le bloc d'un projet de projects.md
# Usage interne — utiliser les fonctions publiques ci-dessous
# @param $1 — PROJECT_ID
# @param $2 — nom du champ (ex: "Tracker", "Langue", "Labels")
_get_project_field() {
  local id="$1" field="$2"
  # -v section : évite l'injection regex via $id (caractères spéciaux dans l'identifiant)
  awk -v section="## ${id}" -v field="$field" '
    $0 == section {found=1; next}
    found && /^## /{exit}
    found && $0 ~ "^- " field " :" {print; exit}
  ' "$PROJECTS_FILE" \
    | sed "s/^- ${field} : *//"
}

# Retourne le provider de tracker d'un projet (jira|gitlab|none)
get_project_tracker() {
  local raw
  raw=$(_get_project_field "$1" "Tracker")
  raw=$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
  echo "${raw:-none}"
}

# Retourne la langue de travail d'un projet (ex: "english", "spanish")
# Retourne une chaîne vide si le champ est absent (comportement par défaut : français)
get_project_language() {
  local raw
  raw=$(_get_project_field "$1" "Langue")
  raw=$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
  echo "${raw:-}"
}

# Retourne la liste des labels d'un projet (ex: "feature,fix,front,back")
# Retourne une chaîne vide si le champ est absent
get_project_labels() {
  local raw
  raw=$(_get_project_field "$1" "Labels")
  echo "${raw:-}"
}

# Retourne la liste CSV des agents sélectionnés pour un projet
# Retourne "all" si le champ est absent ou vide (= déployer tous les agents)
get_project_agents() {
  local raw
  raw=$(_get_project_field "$1" "Agents")
  echo "${raw:-all}"
}

# Retourne la liste CSV des cibles sélectionnées pour un projet
# Retourne "" si le champ est absent (= utiliser les active_targets de hub.json)
# Strip les \r (fichiers CRLF) et les espaces parasites
get_project_targets() {
  local raw
  raw=$(_get_project_field "$1" "Targets")
  echo "${raw:-}" | tr -d '\r' | sed 's/^ *//;s/ *$//'
}

# Retourne la liste CSV des overrides de mode pour un projet
# Format : "agent-id:mode,agent-id:mode,..."
# Retourne "" si le champ est absent (= utiliser les modes du frontmatter agent)
get_project_modes() {
  local raw
  raw=$(_get_project_field "$1" "Modes")
  echo "${raw:-}"
}

# Met à jour le champ "- Modes :" dans le bloc d'un projet dans projects.md
# @param $1 — PROJECT_ID
# @param $2 — valeur CSV "agent-id:mode,..." (ou "" pour supprimer)
_set_project_modes() {
  local id="$1" new_modes="$2"
  if [ -z "$new_modes" ]; then
    # Supprimer le champ si valeur vide
    perl -i -0777pe "
      s{(^## \Q${id}\E\n.*?)- Modes : [^\n]+\n}{\$1}ms
    " "$PROJECTS_FILE" 2>/dev/null
    return 0
  fi
  # Remplacer si existant
  if perl -i -0777pe "
    s{(^## \Q${id}\E\n.*?)(- Modes : [^\n]+)}{\${1}- Modes : ${new_modes}}ms
  " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Modes : ${new_modes}" "$PROJECTS_FILE"; then
    return 0
  fi
  # Insérer après "- Targets :" si présent
  if perl -i -0777pe "
    s{(^## \Q${id}\E\n.*?- Targets : [^\n]+\n)}{\${1}- Modes : ${new_modes}\n}ms
  " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Modes : ${new_modes}" "$PROJECTS_FILE"; then
    return 0
  fi
  # Fallback : insérer après "- Agents :"
  if perl -i -0777pe "
    s{(^## \Q${id}\E\n.*?- Agents : [^\n]+\n)}{\${1}- Modes : ${new_modes}\n}ms
  " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Modes : ${new_modes}" "$PROJECTS_FILE"; then
    return 0
  fi
  log_error "Impossible d'insérer le champ Modes dans le bloc $id de projects.md"
  return 1
}

# Retourne le mode effectif d'un agent pour un projet donné
# Priorité : override projet > frontmatter agent > "primary" (défaut)
# @param $1 — agent_file (chemin vers le .md canonique)
# @param $2 — project_id (peut être vide)
get_effective_agent_mode() {
  local agent_file="$1" project_id="${2:-}"
  local agent_id
  agent_id=$(get_agent_id "$agent_file" 2>/dev/null || basename "$agent_file" .md)

  # Chercher un override dans le projet
  if [ -n "$project_id" ]; then
    local modes_csv
    modes_csv=$(get_project_modes "$project_id")
    if [ -n "$modes_csv" ]; then
      # Chercher "agent-id:mode" dans le CSV
      local override
      override=$(printf '%s\n' "$modes_csv" | tr ',' '\n' | grep "^${agent_id}:" | head -1 | cut -d: -f2)
      if [ -n "$override" ]; then
        echo "$override"
        return
      fi
    fi
  fi

  # Fallback : lire le frontmatter agent (inline pour éviter dépendance prompt-builder)
  local mode
  mode=$(grep '^mode:' "$agent_file" 2>/dev/null | head -1 | sed 's/^mode:[[:space:]]*//')
  echo "${mode:-primary}"
}

# Vérifie si un agent doit être déployé pour un project_id donné
# Retourne 0 si oui, 1 si non
# Si project_id vide ou agents=all → toujours déployer
should_deploy_agent() {
  local project_id="$1" agent_id="$2"
  [ -z "$project_id" ] && return 0
  local agents_csv
  agents_csv=$(get_project_agents "$project_id")
  [ -z "$agents_csv" ] || [ "$agents_csv" = "all" ] && return 0
  echo ",$agents_csv," | grep -qF ",$agent_id,"
}

# Detect OS
detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    *)       echo "unknown" ;;
  esac
}

# ─────────────────────────────────────────
# API KEYS — parser INI-like (api-keys.local.md)
# ─────────────────────────────────────────
# Format attendu dans api-keys.local.md :
#   [PROJECT_ID]
#   model=claude-opus-4-5
#   provider=anthropic
#   api_key=sk-ant-...
#   base_url=https://...    # optionnel

# Lit une clé INI pour une section donnée
# Usage : _api_keys_get <PROJECT_ID> <key>
_api_keys_get() {
  local id="$1" key="$2"
  [ -f "$API_KEYS_FILE" ] || return 0
  awk -v section="[${id}]" -v key="${key}" '
    $0 == section { found=1; next }
    found && /^\[/ { found=0 }
    found && $0 ~ "^" key "=" { sub(/^[^=]+=/, ""); print; exit }
  ' "$API_KEYS_FILE"
}

# Retourne le modèle configuré pour un projet (vide si absent)
get_project_api_model() {
  _api_keys_get "$1" "model"
}

# Retourne le provider configuré pour un projet (vide si absent)
get_project_api_provider() {
  _api_keys_get "$1" "provider"
}

# Retourne la clé API configurée pour un projet (vide si absent)
get_project_api_key() {
  _api_keys_get "$1" "api_key"
}

# Retourne la base URL configurée pour un projet (vide si absent)
get_project_api_base_url() {
  _api_keys_get "$1" "base_url"
}

# Vérifie si une section [PROJECT_ID] existe dans api-keys.local.md
# Utilise une comparaison de ligne exacte pour éviter les faux positifs
# (ex: "[PROJ]" ne doit pas matcher "[PROJ-FULL]")
api_keys_entry_exists() {
  local id="$1"
  [ -f "$API_KEYS_FILE" ] || return 1
  awk -v section="[${id}]" '$0 == section { found=1; exit } END { exit !found }' "$API_KEYS_FILE"
}

# Supprime une section [PROJECT_ID] complète de api-keys.local.md
# (ligne vide précédente incluse)
remove_api_keys_section() {
  local id="$1"
  [ -f "$API_KEYS_FILE" ] || return 0
  api_keys_entry_exists "$id" || return 0
  local tmp; tmp=$(mktemp)
  awk -v section="[${id}]" '
    BEGIN { skip=0; pending_blank=0 }
    /^$/ { if (!skip) { pending_blank=1 }; next }
    $0 == section { pending_blank=0; skip=1; next }
    skip && /^\[/ { skip=0 }
    !skip {
      if (pending_blank) { print ""; pending_blank=0 }
      print
    }
    skip { next }
  ' "$API_KEYS_FILE" > "$tmp"
  mv "$tmp" "$API_KEYS_FILE"
}
