#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# lib/spinner.sh — Spinner braille animé (style opencode)
# ─────────────────────────────────────────────────────────────────────────────
# Usage :
#   source "$LIB_DIR/spinner.sh"
#   _spinner_start "Message affiché…"
#   do_long_work
#   _spinner_stop "Message de fin (succès ou erreur)"  [exit_code]
#
# Le spinner tourne dans un subshell background ; _spinner_stop le tue proprement.
# Compatible bash 3.2 (macOS).

_SPINNER_PID=""
_SPINNER_MSG=""

_spinner_start() {
  _SPINNER_MSG="${1:-Chargement…}"
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local blue='\033[94m' reset='\033[0m'

  # Lancer la boucle dans un subshell
  (
    local i=0
    while true; do
      printf "\r${blue}%s${reset}  %s  " "${frames[$i]}" "$_SPINNER_MSG"
      i=$(( (i + 1) % 10 ))
      sleep 0.1
    done
  ) &
  _SPINNER_PID=$!

  # Masquer le curseur si le terminal le supporte
  tput civis 2>/dev/null || true
}

_spinner_stop() {
  local msg="${1:-Terminé}"
  local code="${2:-0}"

  # Tuer le subshell spinner
  if [ -n "$_SPINNER_PID" ]; then
    kill "$_SPINNER_PID" 2>/dev/null
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
  fi

  # Restaurer le curseur
  tput cnorm 2>/dev/null || true

  # Effacer la ligne spinner + afficher le résultat
  printf "\r\033[2K"
  if [ "$code" -eq 0 ]; then
    echo -e "\033[92m◆\033[0m  ${msg}"
  else
    echo -e "\033[91m◆\033[0m  ${msg}"
  fi
}
