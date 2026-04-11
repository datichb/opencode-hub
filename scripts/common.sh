#!/bin/bash

# ─────────────────────────────────────────
# PATHS
# ─────────────────────────────────────────
HUB_DIR="${HUB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECTS_FILE="${PROJECTS_FILE:-$HUB_DIR/projects/projects.md}"
PROJECTS_EXAMPLE_FILE="$HUB_DIR/projects/projects.example.md"
PATHS_FILE="${PATHS_FILE:-$HUB_DIR/projects/paths.local.md}"
API_KEYS_FILE="${API_KEYS_FILE:-$HUB_DIR/projects/api-keys.local.md}"
SKILLS_DIR="$HUB_DIR/skills"
SCRIPTS_DIR="${SCRIPTS_DIR:-$HUB_DIR/scripts}"

# Phase 2+ : sources canoniques (agents/ et config/)
CANONICAL_AGENTS_DIR="$HUB_DIR/agents"
HUB_CONFIG="$HUB_DIR/config/hub.json"
LIB_DIR="$HUB_DIR/scripts/lib"
ADAPTERS_DIR="$HUB_DIR/scripts/adapters"
EXTERNAL_SKILLS_DIR="$HUB_DIR/skills/external"

# Load i18n string table (bash 3.2 compatible)
# shellcheck source=scripts/lib/i18n.sh
[ -f "$HUB_DIR/scripts/lib/i18n.sh" ] && source "$HUB_DIR/scripts/lib/i18n.sh"

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
# Tolère l'EOF (stdin pipe) sans échouer — compatible set -e.
_prompt() {
  local _var="$1" _msg="$2"
  echo -e "${DIM}│${RESET}"
  # shellcheck disable=SC2229  # intentional: $_var holds the target variable name
  IFS= read -rp "  ${_msg}" $_var || true
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

# ─────────────────────────────────────────
# PROVIDERS — hub.json + providers.json
# ─────────────────────────────────────────

# Définition du fichier catalogue des providers
PROVIDERS_FILE="$HUB_DIR/config/providers.json"

# Lire le catalogue des providers
get_provider_info() {
  local provider_name="$1" field="$2"
  [ -f "$PROVIDERS_FILE" ] || return 1
  jq -r --arg n "$provider_name" --arg f "$field" '.providers[$n][$f] // empty' "$PROVIDERS_FILE" 2>/dev/null
}

# Vérifier si un provider existe dans le catalogue
provider_exists() {
  local provider_name="$1"
  [ -f "$PROVIDERS_FILE" ] || return 1
  jq -e --arg n "$provider_name" '.providers | has($n)' "$PROVIDERS_FILE" &>/dev/null
}

# Lister tous les providers du catalogue
list_all_providers() {
  [ -f "$PROVIDERS_FILE" ] || return 1
  jq -r '.providers | keys[]' "$PROVIDERS_FILE" 2>/dev/null
}

# Hub-level default provider (lecture depuis hub.json)
get_hub_default_provider() {
  [ -f "$HUB_CONFIG" ] || return 1
  jq -r '.default_provider.name // empty' "$HUB_CONFIG" 2>/dev/null
}

get_hub_default_api_key() {
  [ -f "$HUB_CONFIG" ] || return 1
  jq -r '.default_provider.api_key // empty' "$HUB_CONFIG" 2>/dev/null
}

get_hub_default_base_url() {
  [ -f "$HUB_CONFIG" ] || return 1
  jq -r '.default_provider.base_url // empty' "$HUB_CONFIG" 2>/dev/null
}

get_hub_default_model() {
  [ -f "$HUB_CONFIG" ] || return 1
  jq -r '.default_provider.model // empty' "$HUB_CONFIG" 2>/dev/null
}

# Résout le provider effectif pour un projet
# Priorité : api-keys.local.md projet > hub default > anthropic (fallback)
get_effective_provider() {
  local project_id="$1"
  local project_provider=""
  if [ -n "$project_id" ]; then
    project_provider=$(get_project_api_provider "$project_id")
  fi
  if [ -n "$project_provider" ]; then
    echo "$project_provider"
  else
    local hub_provider; hub_provider=$(get_hub_default_provider)
    echo "${hub_provider:-anthropic}"
  fi
}

# Résout le modèle effectif pour un projet (chaîne de priorité complète)
# Priorité : 1) api-keys projet  2) hub default  3) opencode.model de hub.json  4) DEFAULT_MODEL
get_effective_llm_model() {
  local project_id="${1:-}"
  local model=""
  
  # 1. api-keys.local.md du projet
  if [ -n "$project_id" ]; then
    model=$(get_project_api_model "$project_id")
    [ -n "$model" ] && echo "$model" && return 0
  fi
  
  # 2. hub default provider model
  local hub_model; hub_model=$(get_hub_default_model)
  [ -n "$hub_model" ] && echo "$hub_model" && return 0
  
  # 3. opencode.model de hub.json (comportement actuel)
  if command -v jq &>/dev/null && [ -f "$HUB_CONFIG" ]; then
    model=$(jq -r '.opencode.model // empty' "$HUB_CONFIG" 2>/dev/null)
    [ -n "$model" ] && echo "$model" && return 0
  fi
  
  # 4. Fallback : DEFAULT_MODEL
  echo "$DEFAULT_MODEL"
}

# ─────────────────────────────────────────
# NATIVE AGENTS — désactivation OpenCode
# ─────────────────────────────────────────

# Lit opencode.disabled_native_agents dans hub.json (tableau JSON → CSV)
# Retourne "" si le champ est absent ou si le tableau est vide
get_hub_disabled_native_agents() {
  [ -f "$HUB_CONFIG" ] || return 0
  command -v jq &>/dev/null || return 0
  local arr
  arr=$(jq -r '(.opencode.disabled_native_agents // []) | @csv' "$HUB_CONFIG" 2>/dev/null \
    | tr -d '"')
  echo "${arr:-}"
}

# Lit "- Disable agents :" dans projects.md pour un projet donné
# Retourne "" si le champ est absent
get_project_disabled_native_agents() {
  local raw
  raw=$(_get_project_field "$1" "Disable agents")
  echo "${raw:-}"
}

# Écrit/met à jour "- Disable agents :" dans le bloc d'un projet dans projects.md
# Si valeur vide → supprime le champ
# Insérer après "- Targets :" si présent, sinon après "- Agents :"
# @param $1 — PROJECT_ID
# @param $2 — valeur CSV (ou "" pour supprimer)
_set_project_disabled_native_agents() {
  local id="$1" new_val="$2"
  if [ -z "$new_val" ]; then
    # Supprimer le champ si valeur vide
    perl -i -0777pe "
      s{(^## \Q${id}\E\n.*?)- Disable agents : [^\n]+\n}{\$1}ms
    " "$PROJECTS_FILE" 2>/dev/null
    return 0
  fi
  # Remplacer si existant
  if perl -i -0777pe "
    s{(^## \Q${id}\E\n.*?)(- Disable agents : [^\n]+)}{\${1}- Disable agents : ${new_val}}ms
  " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Disable agents : ${new_val}" "$PROJECTS_FILE"; then
    return 0
  fi
  # Insérer après "- Targets :" si présent
  if perl -i -0777pe "
    s{(^## \Q${id}\E\n.*?- Targets : [^\n]+\n)}{\${1}- Disable agents : ${new_val}\n}ms
  " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Disable agents : ${new_val}" "$PROJECTS_FILE"; then
    return 0
  fi
  # Fallback : insérer après "- Agents :"
  if perl -i -0777pe "
    s{(^## \Q${id}\E\n.*?- Agents : [^\n]+\n)}{\${1}- Disable agents : ${new_val}\n}ms
  " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Disable agents : ${new_val}" "$PROJECTS_FILE"; then
    return 0
  fi
  log_error "Impossible d'insérer le champ 'Disable agents' dans le bloc $id de projects.md"
  return 1
}

# ─────────────────────────────────────────
# I18N — Language resolution
# ─────────────────────────────────────────

# Reads the global CLI language from hub.json (.cli.language)
# Returns "" if not set or jq unavailable
get_hub_language() {
  [ -f "$HUB_CONFIG" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '.cli.language // empty' "$HUB_CONFIG" 2>/dev/null
}

# Resolves and exports OC_LANG for the current invocation.
# Priority: project Langue field > global hub.json .cli.language > "en"
# Normalises french/English → fr/en.
# @param $1 — PROJECT_ID (optional)
resolve_oc_lang() {
  local project_id="${1:-}"
  local lang=""

  # 1. Per-project Langue field in projects.md
  if [ -n "$project_id" ]; then
    lang=$(get_project_language "$project_id")
  fi

  # 2. Global CLI language from hub.json
  if [ -z "$lang" ]; then
    lang=$(get_hub_language)
  fi

  # 3. Default to English
  lang="${lang:-en}"

  # Normalise: french → fr, english/anything else → en
  case "$lang" in
    french|fr) lang="fr" ;;
    *)         lang="en" ;;
  esac

  export OC_LANG="$lang"
}

# Resolves the human-readable language name to inject in agent prompts.
# Priority: per-project Langue field → OC_LANG code → empty (no injection)
# Maps language codes to human-readable names: fr → "français", en → "english"
# @param $1 — raw lang string from get_project_language (may be empty)
# Returns the human-readable name to pass to build_agent_content, or "" for none.
resolve_agent_lang() {
  local raw="${1:-}"
  if [ -n "$raw" ]; then
    # Per-project Langue field: return as-is (already human-readable)
    printf '%s' "$raw"
    return 0
  fi
  # Fall back to OC_LANG code → human-readable name
  local code="${OC_LANG:-}"
  case "$code" in
    fr) printf '%s' "français" ;;
    en) printf '%s' "english" ;;
    *)  printf '%s' "" ;;
  esac
}

# Auto-resolve language on source so t() works without explicit call
resolve_oc_lang

