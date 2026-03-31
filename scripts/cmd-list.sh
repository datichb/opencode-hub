#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

log_title "Projets enregistrés"

ensure_projects_file

# Extraire les PROJECT_IDs
ids=()
while IFS= read -r line; do ids+=("$line"); done < <(grep "^## " "$PROJECTS_FILE" | sed 's/^## //')

if [ ${#ids[@]} -eq 0 ]; then
  log_warn "Aucun projet enregistré"
  exit 0
fi

echo ""
printf "  ${BOLD}%-20s %-30s %-15s${RESET}\n" "ID" "Chemin local" "Statut"
printf "  %s\n" "────────────────────────────────────────────────────────────"

for id in "${ids[@]}"; do
  local_path=$(get_project_path "$id" 2>/dev/null || true)

  if [ -z "$local_path" ]; then
    status="${YELLOW}⚠ sans chemin${RESET}"
    display_path="non défini"
    display_color="$YELLOW"
  elif [ -d "${local_path/#\~/$HOME}" ]; then
    status="${GREEN}✔ accessible${RESET}"
    display_path="$local_path"
    display_color=""
  else
    status="${RED}✘ introuvable${RESET}"
    display_path="$local_path"
    display_color=""
  fi

  # Utiliser printf pour le padding, puis injecter la couleur via %b
  if [ -n "$display_color" ]; then
    printf "  %-20s ${display_color}%-30s${RESET} " "$id" "$display_path"
  else
    printf "  %-20s %-30s " "$id" "$display_path"
  fi
  echo -e "$status"
done

echo ""
