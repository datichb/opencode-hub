#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# lib/metrics.sh — Logging des métriques de vélocité workflow
# ─────────────────────────────────────────────────────────────────────────────
# Usage :
#   source "$LIB_DIR/metrics.sh"
#   metrics_ticket_start "bd-42" "developer-backend"
#   metrics_ticket_complete "bd-42" "developer-backend" 900
#   metrics_review_cycle "bd-42" 1
#   metrics_correction "bd-42" "lint errors"
#
# Les événements sont loggés dans .opencode/metrics.jsonl (format JSONL).
# Le fichier est créé au premier événement si inexistant.
# Compatible bash 3.2 (macOS).
# ─────────────────────────────────────────────────────────────────────────────
[ -n "${_METRICS_LOADED:-}" ] && return 0
_METRICS_LOADED=1

# ─────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────
_METRICS_DIR=".opencode"
_METRICS_FILE="${_METRICS_DIR}/metrics.jsonl"

# ─────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────

# Génère un timestamp ISO8601 UTC
# Usage : ts=$(_metrics_timestamp)
_metrics_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Échappe une chaîne pour JSON (backslashes, guillemets, newlines, tabs)
# Usage : escaped=$(_metrics_escape "valeur")
# Note : utilise printf %s et substitution bash — compatible bash 3.2 (macOS)
_metrics_escape() {
  local s
  # printf %s évite l'interprétation de \n, \t, etc. dans l'argument
  s=$(printf '%s' "$1")
  # Ordre important : d'abord les backslashes, puis les autres caractères
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  # shellcheck disable=SC2016
  s=${s//$'\n'/'\n'}
  # shellcheck disable=SC2016
  s=${s//$'\t'/'\t'}
  printf '%s' "$s"
}

# S'assure que le dossier et fichier metrics existent
# Usage : _metrics_ensure_file
_metrics_ensure_file() {
  if [ ! -d "$_METRICS_DIR" ]; then
    mkdir -p "$_METRICS_DIR"
  fi
  if [ ! -f "$_METRICS_FILE" ]; then
    touch "$_METRICS_FILE"
  fi
}

# ─────────────────────────────────────────
# CORE — Logging générique
# ─────────────────────────────────────────

# Log un événement générique dans metrics.jsonl
# Usage : metrics_log_event "event_type" "ticket_id" ["agent"] ["duration_seconds"] ["extra_json_fields"]
# @param $1 — event type (required)
# @param $2 — ticket_id (required)
# @param $3 — agent (optional, empty string to skip)
# @param $4 — duration_seconds (optional, empty string to skip)
# @param $5 — extra JSON fields as raw JSON object content (optional, without braces)
#             Example: '"reason":"lint errors","count":3'
metrics_log_event() {
  local event_type="$1"
  local ticket_id="$2"
  local agent="${3:-}"
  local duration="${4:-}"
  local extra="${5:-}"

  [ -z "$event_type" ] && return 1
  [ -z "$ticket_id" ] && return 1

  _metrics_ensure_file

  local ts
  ts=$(_metrics_timestamp)

  # Build JSON line
  local json
  json="{\"timestamp\":\"${ts}\",\"event\":\"$(_metrics_escape "$event_type")\",\"ticket_id\":\"$(_metrics_escape "$ticket_id")\""

  if [ -n "$agent" ]; then
    json="${json},\"agent\":\"$(_metrics_escape "$agent")\""
  fi

  if [ -n "$duration" ]; then
    if [[ "$duration" =~ ^[0-9]+$ ]]; then
      json="${json},\"duration_seconds\":${duration}"
    fi
  fi

  if [ -n "$extra" ]; then
    json="${json},${extra}"
  fi

  json="${json}}"

  # Append to file
  echo "$json" >> "$_METRICS_FILE"
}

# ─────────────────────────────────────────
# TIMER FUNCTIONS
# ─────────────────────────────────────────

# Répertoire temporaire pour stocker les timestamps de démarrage
_METRICS_TIMER_DIR="${TMPDIR:-/tmp}/opencode-metrics-timers"

# Démarre un timer pour un ticket
# Usage : metrics_start_timer "bd-42"
# @param $1 — ticket_id (required)
# Stocke l'epoch timestamp dans un fichier temporaire
metrics_start_timer() {
  local ticket_id="$1"
  [ -z "$ticket_id" ] && return 1

  # Créer le répertoire des timers s'il n'existe pas
  if [ ! -d "$_METRICS_TIMER_DIR" ]; then
    mkdir -p "$_METRICS_TIMER_DIR"
  fi

  # Stocker l'epoch timestamp
  local timer_file
  timer_file="${_METRICS_TIMER_DIR}/${ticket_id}.timer"
  date +%s > "$timer_file"
}

# Calcule la durée en secondes depuis le start d'un ticket
# Usage : duration=$(metrics_get_duration "bd-42")
# @param $1 — ticket_id (required)
# Retourne : durée en secondes, ou chaîne vide si pas de timer
metrics_get_duration() {
  local ticket_id="$1"
  [ -z "$ticket_id" ] && return 1

  local timer_file
  timer_file="${_METRICS_TIMER_DIR}/${ticket_id}.timer"
  if [ ! -f "$timer_file" ]; then
    echo ""
    return 1
  fi

  local start_time
  start_time=$(cat "$timer_file")
  local now
  now=$(date +%s)

  local duration
  duration=$((now - start_time))
  echo "$duration"
}

# Nettoie le timer d'un ticket (optionnel, appelé après ticket_complete)
# Usage : metrics_clear_timer "bd-42"
# @param $1 — ticket_id (required)
metrics_clear_timer() {
  local ticket_id="$1"
  [ -z "$ticket_id" ] && return 1

  local timer_file
  timer_file="${_METRICS_TIMER_DIR}/${ticket_id}.timer"
  if [ -f "$timer_file" ]; then
    rm -f "$timer_file"
  fi
}

# ─────────────────────────────────────────
# EVENT-SPECIFIC FUNCTIONS
# ─────────────────────────────────────────

# Log le démarrage d'un ticket
# Usage : metrics_ticket_start "bd-42" ["developer-backend"]
# @param $1 — ticket_id (required)
# @param $2 — agent (optional)
metrics_ticket_start() {
  local ticket_id="$1"
  local agent="${2:-}"
  metrics_log_event "ticket_start" "$ticket_id" "$agent"
}

# Log la complétion d'un ticket avec durée
# Usage : metrics_ticket_complete "bd-42" ["developer-backend"] [900]
# @param $1 — ticket_id (required)
# @param $2 — agent (optional)
# @param $3 — duration_seconds (optional)
metrics_ticket_complete() {
  local ticket_id="$1"
  local agent="${2:-}"
  local duration="${3:-}"
  metrics_log_event "ticket_complete" "$ticket_id" "$agent" "$duration"
}

# Log un cycle de review
# Usage : metrics_review_cycle "bd-42" [1]
# @param $1 — ticket_id (required)
# @param $2 — cycle_number (optional)
metrics_review_cycle() {
  local ticket_id="$1"
  local cycle="${2:-}"
  local extra=""
  if [ -n "$cycle" ]; then
    if [[ "$cycle" =~ ^[0-9]+$ ]]; then
      extra="\"cycle\":${cycle}"
    fi
  fi
  metrics_log_event "review_cycle" "$ticket_id" "" "" "$extra"
}

# Log une correction avec raison
# Usage : metrics_correction "bd-42" "lint errors"
# @param $1 — ticket_id (required)
# @param $2 — reason (optional)
metrics_correction() {
  local ticket_id="$1"
  local reason="${2:-}"
  local extra=""
  if [ -n "$reason" ]; then
    extra="\"reason\":\"$(_metrics_escape "$reason")\""
  fi
  metrics_log_event "correction" "$ticket_id" "" "" "$extra"
}
