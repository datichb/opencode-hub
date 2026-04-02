#!/bin/bash
# Composant TUI réutilisable : sélecteur générique (flèches + espace).
# Compatible bash 3.2 (macOS).
#
# Utilisé par cmd-agent.sh et cmd-init.sh.

[ "${_TUI_PICKER_LOADED:-}" = "1" ] && return 0
_TUI_PICKER_LOADED=1

##
# Lit une touche depuis /dev/tty (mode raw déjà actif).
# Gère les séquences ESC (flèches, SS3). Résultat dans $KEY.
# Retourne 1 si ESC seul (annulation).
##
_read_key() {
  local byte1 byte2 byte3
  IFS= read -rsn1 byte1 </dev/tty
  KEY="$byte1"

  if [ "$byte1" = $'\x1b' ]; then
    IFS= read -rsn1 -t 1 byte2 </dev/tty || byte2=""
    if [ "$byte2" = "[" ] || [ "$byte2" = "O" ]; then
      IFS= read -rsn1 -t 1 byte3 </dev/tty || byte3=""
      KEY="${byte1}${byte2}${byte3}"
    elif [ -z "$byte2" ]; then
      # ESC seul
      KEY=$'\x1b'
      return 1
    else
      KEY="${byte1}${byte2}"
    fi
  fi
  return 0
}

##
# Sélecteur générique avec navigation flèches + espace.
# Compatible bash 3.2 (macOS). Résultat dans $_PICK_RESULT (CSV).
#
# Interface (dynamic scoping bash — les variables sont partagées avec le caller) :
#   _pick_items[]          — tableau des éléments à afficher
#   _pick_checked[]        — tableau booléen de sélection (0/1)
#   _pick_cursor           — index courant du curseur
#   _pick_total            — nombre total d'éléments
#   _pick_render_fn        — nom de la fonction de rendu (appelée à chaque frame)
#   _pick_allow_zero       — "1" pour activer la touche 0 (tout décocher)
#   _pick_allow_star       — "1" pour activer la touche * (tout cocher)
#   _pick_allow_family_toggle — "1" pour activer la touche c (toggle catégorie courante)
#   _pick_families[]       — tableau parallèle des familles (requis si family_toggle actif)
#
# @param {string} $1 — sélection courante (CSV)
# @param {string} $2 — valeur à retourner si annulation (par défaut: $1)
##
_pick_from_list() {
  local current_csv="${1:-}"
  local cancel_value="${2:-$current_csv}"

  # Rien à choisir
  if [ "$_pick_total" -eq 0 ]; then
    _PICK_RESULT="$current_csv"
    return
  fi

  _pick_cursor=0

  # Sauvegarde état terminal et passage en mode raw
  local old_stty
  old_stty=$(stty -g </dev/tty 2>/dev/null)
  trap '[ -n "$old_stty" ] && stty "$old_stty" </dev/tty 2>/dev/null' EXIT INT TERM
  stty -echo -icanon min 1 time 0 </dev/tty 2>/dev/null

  local _picker_cancelled=0

  while true; do
    # Appeler la fonction de rendu (accède aux variables partagées)
    "$_pick_render_fn"

    # Lecture d'une touche
    local key
    if ! _read_key; then
      _picker_cancelled=1
      break
    fi
    key="$KEY"

    case "$key" in
      $'\x1b[A'|$'\x1bOA')  # flèche haut
        [ "$_pick_cursor" -gt 0 ] && _pick_cursor=$((_pick_cursor - 1))
        ;;
      $'\x1b[B'|$'\x1bOB')  # flèche bas
        [ "$_pick_cursor" -lt $((_pick_total - 1)) ] && _pick_cursor=$((_pick_cursor + 1))
        ;;
      " ")  # espace — toggle
        if [ "${_pick_checked[$_pick_cursor]}" = "1" ]; then
          _pick_checked[$_pick_cursor]="0"
        else
          _pick_checked[$_pick_cursor]="1"
        fi
        ;;
      ""| $'\n'| $'\r')  # entrée — valider
        break
        ;;
      "0")
        if [ "${_pick_allow_zero:-0}" = "1" ]; then
          local _z=0
          while [ "$_z" -lt "$_pick_total" ]; do _pick_checked[$_z]="0"; _z=$((_z+1)); done
        fi
        ;;
      "*")
        if [ "${_pick_allow_star:-0}" = "1" ]; then
          local _s=0
          while [ "$_s" -lt "$_pick_total" ]; do _pick_checked[$_s]="1"; _s=$((_s+1)); done
        fi
        ;;
      "c")
        if [ "${_pick_allow_family_toggle:-0}" = "1" ] && [ -n "${_pick_families[*]+x}" ]; then
          local _cur_family="${_pick_families[$_pick_cursor]}"
          # Vérifier si tous les agents de la famille sont cochés
          local _all_fam_checked=1
          local _fi=0
          while [ "$_fi" -lt "$_pick_total" ]; do
            if [ "${_pick_families[$_fi]}" = "$_cur_family" ] && [ "${_pick_checked[$_fi]}" != "1" ]; then
              _all_fam_checked=0
              break
            fi
            _fi=$((_fi+1))
          done
          # Cocher tous si incomplet, sinon décocher tous
          local _new_state="1"
          [ "$_all_fam_checked" = "1" ] && _new_state="0"
          local _fi2=0
          while [ "$_fi2" -lt "$_pick_total" ]; do
            if [ "${_pick_families[$_fi2]}" = "$_cur_family" ]; then
              _pick_checked[$_fi2]="$_new_state"
            fi
            _fi2=$((_fi2+1))
          done
        fi
        ;;
    esac
  done

  # Restaurer le terminal
  trap - EXIT INT TERM
  [ -n "$old_stty" ] && stty "$old_stty" </dev/tty 2>/dev/null

  # Annulation par ESC
  if [ "$_picker_cancelled" = "1" ]; then
    printf "\033[2J\033[H"
    _PICK_RESULT="$cancel_value"
    return
  fi

  printf "\033[2J\033[H"

  # Reconstruire le CSV final
  local chosen=()
  local _r=0
  while [ "$_r" -lt "$_pick_total" ]; do
    [ "${_pick_checked[$_r]}" = "1" ] && chosen+=("${_pick_items[$_r]}")
    _r=$((_r + 1))
  done

  if [ ${#chosen[@]} -eq 0 ]; then
    _PICK_RESULT=""
  else
    _PICK_RESULT=$(printf '%s\n' "${chosen[@]}" | tr '\n' ',' | sed 's/,$//')
  fi
}
