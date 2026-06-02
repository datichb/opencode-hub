#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# colors.sh — Constantes de couleurs ANSI, loggers et helpers TUI
# Sourcé par common.sh — ne pas sourcer directement.
# ─────────────────────────────────────────────────────────────────────────────
[ -n "${_COLORS_LOADED:-}" ] && return 0
_COLORS_LOADED=1

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
export RED GREEN YELLOW BLUE CYAN BOLD DIM RESET

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
  # Mode non-interactif explicite (CI / tests via variable d'environnement)
  if [ "${OC_NON_INTERACTIVE:-0}" = "1" ]; then
    printf -v "$_var" '%s' ''
    return 0
  fi
  # Stdin n'est pas un TTY (pipe, redirection fichier) :
  #   - pipe avec données disponibles  → read consomme les données immédiatement
  #   - /dev/null (EOF)                → read retourne non-zero, var reste vide
  #   - pipe ouvert sans données       → read -t 1 expire après 1s, var reste vide
  # Dans tous les cas : pas de prompt affiché, pas de blocage.
  if [ ! -t 0 ]; then
    # shellcheck disable=SC2229
    IFS= read -t 1 -r $_var 2>/dev/null || printf -v "$_var" '%s' ''
    return 0
  fi
  echo -e "${DIM}│${RESET}"
  # shellcheck disable=SC2229  # intentional: $_var holds the target variable name
  IFS= read -rp "  ${_msg}" $_var || true
}
