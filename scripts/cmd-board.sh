#!/bin/bash
set -euo pipefail

# ── Board kanban terminal — oc beads board ─────────────────────────────────────
# Affiche un tableau kanban dans le terminal avec les 4 colonnes actives :
# OPEN | IN PROGRESS | REVIEW | BLOCKED
#
# Usage :
#   cmd_board <PROJECT_ID> [--watch] [--interval <sec>]
#
# Options :
#   --watch              Rafraîchissement automatique (Ctrl+C pour quitter)
#   --interval <sec>     Intervalle en secondes entre rafraîchissements (défaut : 5)

# ── Helpers internes ──────────────────────────────────────────────────────────

# Tronque une chaîne à N caractères, ajoute "…" si tronqué
_trunc() {
  local str="$1" max="$2"
  if [ "${#str}" -gt "$max" ]; then
    printf '%s…' "${str:0:$((max-1))}"
  else
    printf '%s' "$str"
  fi
}

# Répète un caractère N fois
_repeat() {
  local char="$1" n="$2"
  printf '%*s' "$n" '' | tr ' ' "$char"
}

# Pad une chaîne à N caractères (sans codes ANSI dans le comptage)
_pad() {
  local str="$1" width="$2"
  local visible_len=${#str}
  local pad=$(( width - visible_len ))
  [ $pad -lt 0 ] && pad=0
  printf '%s%*s' "$str" "$pad" ''
}

# Badge de priorité coloré (1 char de large + reset)
_priority_badge() {
  local p="$1"
  case "$p" in
    0) printf "${RED}${BOLD}P0${RESET}" ;;
    1) printf "${YELLOW}P1${RESET}" ;;
    2) printf "${DIM}P2${RESET}" ;;
    3) printf "${DIM}P3${RESET}" ;;
    *) printf "${DIM}??${RESET}" ;;
  esac
}

# Type en CYAN tronqué à 7 chars
_type_badge() {
  local t="$1"
  printf "${CYAN}%s${RESET}" "$(_trunc "$t" 7)"
}

# ── Rendu d'une colonne ───────────────────────────────────────────────────────
# @param $1 — label de la colonne (ex: "OPEN")
# @param $2 — couleur de la bordure (variable ANSI, ex: "$DIM")
# @param $3 — tickets JSON (tableau jq, peut être vide "[]")
# @param $4 — largeur de colonne (inner width, sans les bordures)
# Imprime les lignes dans un tableau bash (référence passée par nom)
# Retourne les lignes dans la variable globale _COL_LINES
_render_column() {
  local label="$1"
  local col_color="$2"
  local tickets_json="$3"
  local inner_w="$4"

  _COL_LINES=()

  # ── en-tête ──
  local header_text=" ${label} "
  local dashes_total=$(( inner_w - ${#header_text} ))
  [ $dashes_total -lt 0 ] && dashes_total=0
  local dashes
  dashes=$(_repeat '─' "$dashes_total")
  _COL_LINES+=("${col_color}┌─${RESET}${BOLD}${header_text}${RESET}${col_color}${dashes}┐${RESET}")

  # ── lignes de tickets ──
  local count
  count=$(echo "$tickets_json" | jq 'length' 2>/dev/null || echo "0")

  if [ "$count" -eq 0 ]; then
    # Colonne vide
    local empty_msg="— aucun ticket —"
    local pad_left=$(( (inner_w - ${#empty_msg}) / 2 ))
    local pad_right=$(( inner_w - ${#empty_msg} - pad_left ))
    [ $pad_left -lt 0 ] && pad_left=0
    [ $pad_right -lt 0 ] && pad_right=0
    _COL_LINES+=("${col_color}│${RESET}$(printf '%*s' $pad_left '')${DIM}${empty_msg}${RESET}$(printf '%*s' $pad_right '')${col_color}│${RESET}")
    _COL_LINES+=("${col_color}│${RESET}$(printf '%*s' $inner_w '')${col_color}│${RESET}")
  else
    local i
    for (( i=0; i<count; i++ )); do
      local ticket
      ticket=$(echo "$tickets_json" | jq -r ".[$i]" 2>/dev/null || continue)

      local id title priority type
      id=$(echo "$ticket"    | jq -r '.id    // "?"' 2>/dev/null)
      title=$(echo "$ticket" | jq -r '.title // "?"' 2>/dev/null)
      priority=$(echo "$ticket" | jq -r '.priority // "2"' 2>/dev/null)
      type=$(echo "$ticket"  | jq -r '.type  // ""' 2>/dev/null)

      # Ligne 1 : id + priorité + type  (ex: "bd-12  P1  feature")
      local meta_raw="${id}"
      local meta_color="${BOLD}${id}${RESET}"
      local p_badge; p_badge=$(_priority_badge "$priority")
      local t_badge; t_badge=$(_type_badge "$type")

      # Calcul de la longueur visible de la ligne meta (sans ANSI)
      local meta_visible="${id}  $(printf 'P%s' "$priority")  ${type}"
      local meta_len=${#meta_visible}
      local meta_pad=$(( inner_w - meta_len - 2 ))  # -2 pour les espaces de marge
      [ $meta_pad -lt 0 ] && meta_pad=0

      _COL_LINES+=("${col_color}│${RESET} ${meta_color}  ${p_badge}  ${t_badge}$(printf '%*s' $meta_pad '')${col_color}│${RESET}")

      # Ligne 2 : titre tronqué
      local title_max=$(( inner_w - 2 ))
      local title_trunc
      title_trunc=$(_trunc "$title" "$title_max")
      local title_pad=$(( title_max - ${#title_trunc} ))
      [ $title_pad -lt 0 ] && title_pad=0
      _COL_LINES+=("${col_color}│${RESET} ${title_trunc}$(printf '%*s' $title_pad '')${col_color}│${RESET}")

      # Ligne 3 : séparation entre tickets (vide)
      _COL_LINES+=("${col_color}│${RESET}$(printf '%*s' $inner_w '')${col_color}│${RESET}")
    done
  fi

  # ── pied ──
  local bottom_line
  bottom_line=$(_repeat '─' "$inner_w")
  _COL_LINES+=("${col_color}└${bottom_line}┘${RESET}")
}

# ── Rendu complet du board ────────────────────────────────────────────────────
_render_board() {
  local project_id="$1"
  local project_path="$2"

  # Vérifier que bd est disponible et que .beads existe
  _require_bd
  _require_beads_init "$project_path" "$project_id"

  # Récupérer les tickets par statut
  local t_open t_inprog t_review t_blocked
  t_open=$(cd "$project_path" && bd list -s open --json 2>/dev/null || echo "[]")
  t_inprog=$(cd "$project_path" && bd list -s in_progress --json 2>/dev/null || echo "[]")
  t_review=$(cd "$project_path" && bd list -s review --json 2>/dev/null || echo "[]")
  t_blocked=$(cd "$project_path" && bd list -s blocked --json 2>/dev/null || echo "[]")

  # ── Layout adaptatif ──
  local term_w
  term_w=$(tput cols 2>/dev/null || echo 100)

  # 4 colonnes, 3 espaces entre chaque, 2 chars de bordure par colonne (│…│)
  # total_borders = 4 * 2 = 8, total_gaps = 3 * 2 = 6
  local gaps=6
  local borders=8
  local available=$(( term_w - gaps - borders ))
  local col_inner=$(( available / 4 ))
  [ $col_inner -lt 18 ] && col_inner=18

  # ── Compter les tickets pour le footer ──
  local cnt_open cnt_inprog cnt_review cnt_blocked
  cnt_open=$(echo "$t_open"    | jq 'length' 2>/dev/null || echo "0")
  cnt_inprog=$(echo "$t_inprog" | jq 'length' 2>/dev/null || echo "0")
  cnt_review=$(echo "$t_review" | jq 'length' 2>/dev/null || echo "0")
  cnt_blocked=$(echo "$t_blocked" | jq 'length' 2>/dev/null || echo "0")

  # ── Titre ──
  local now
  now=$(date '+%A %d %B %Y' 2>/dev/null || date)
  echo ""
  echo -e "${BOLD}◆  Board — ${project_id}${RESET}  ${DIM}${now}${RESET}"
  echo ""

  # ── Rendre les 4 colonnes ──
  local col_w=$(( col_inner + 2 ))  # +2 pour les bordures

  declare -a lines_open lines_inprog lines_review lines_blocked

  _COL_LINES=()
  _render_column "OPEN"        "$DIM"    "$t_open"    "$col_inner"
  lines_open=("${_COL_LINES[@]}")

  _COL_LINES=()
  _render_column "IN PROGRESS" "$BLUE"   "$t_inprog"  "$col_inner"
  lines_inprog=("${_COL_LINES[@]}")

  _COL_LINES=()
  _render_column "REVIEW"      "$YELLOW" "$t_review"  "$col_inner"
  lines_review=("${_COL_LINES[@]}")

  _COL_LINES=()
  _render_column "BLOCKED"     "$RED"    "$t_blocked" "$col_inner"
  lines_blocked=("${_COL_LINES[@]}")

  # ── Fusionner les colonnes ligne par ligne ──
  local max_lines="${#lines_open[@]}"
  [ "${#lines_inprog[@]}"  -gt "$max_lines" ] && max_lines="${#lines_inprog[@]}"
  [ "${#lines_review[@]}"  -gt "$max_lines" ] && max_lines="${#lines_review[@]}"
  [ "${#lines_blocked[@]}" -gt "$max_lines" ] && max_lines="${#lines_blocked[@]}"

  local i
  for (( i=0; i<max_lines; i++ )); do
    local l0="${lines_open[$i]:-}"
    local l1="${lines_inprog[$i]:-}"
    local l2="${lines_review[$i]:-}"
    local l3="${lines_blocked[$i]:-}"

    # Padding des lignes manquantes (colonne plus courte que les autres)
    [ -z "$l0" ] && l0="$(printf '%*s' $(( col_inner + 2 )) '')"
    [ -z "$l1" ] && l1="$(printf '%*s' $(( col_inner + 2 )) '')"
    [ -z "$l2" ] && l2="$(printf '%*s' $(( col_inner + 2 )) '')"
    [ -z "$l3" ] && l3="$(printf '%*s' $(( col_inner + 2 )) '')"

    printf '  %b  %b  %b  %b\n' "$l0" "$l1" "$l2" "$l3"
  done

  # ── Footer : compteurs ──
  echo ""
  printf '  '
  printf "${DIM}%-${col_w}s${RESET}  " "$(_pad "${cnt_open} open" $(( col_w )))"
  printf "${BLUE}%-${col_w}s${RESET}  " "$(_pad "${cnt_inprog} in progress" $(( col_w )))"
  printf "${YELLOW}%-${col_w}s${RESET}  " "$(_pad "${cnt_review} review" $(( col_w )))"
  printf "${RED}%-${col_w}s${RESET}" "$(_pad "${cnt_blocked} blocked" $(( col_w )))"
  echo ""
  echo ""
}

# ── Point d'entrée ────────────────────────────────────────────────────────────
cmd_board() {
  local raw_id="${1:-}"
  local watch=false
  local interval=5

  # Parser les flags supplémentaires
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --watch)             watch=true ;;
      --interval)          shift; interval="${1:-5}" ;;
      --interval=*)        interval="${1#*=}" ;;
      *) ;;
    esac
    shift
  done

  # Résoudre le projet
  local id path
  if [ -n "$raw_id" ]; then
    id=$(normalize_project_id "$raw_id")
    path=$(resolve_project_path "$id")
  else
    # Auto-découverte : cherche .beads/ dans le répertoire courant et ses parents
    local current_dir="$PWD"
    path=""
    id="."
    while [ "$current_dir" != "/" ]; do
      if [ -d "${current_dir}/.beads" ]; then
        path="$current_dir"
        id=$(basename "$current_dir" | tr '[:lower:]' '[:upper:]')
        break
      fi
      current_dir=$(dirname "$current_dir")
    done
    if [ -z "$path" ]; then
      log_error "$(t board.no_project)"
      log_info  "$(t board.usage_hint)"
      exit 1
    fi
  fi

  if [ "$watch" = true ]; then
    log_info "$(t board.watch_mode) (Ctrl+C $(t board.watch_quit))"
    while true; do
      clear
      _render_board "$id" "$path"
      sleep "$interval"
    done
  else
    _render_board "$id" "$path"
  fi
}
