#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

log_title "$(t list.title)"

ensure_projects_file

# Extraire les PROJECT_IDs
ids=()
while IFS= read -r line; do ids+=("$line"); done < <(grep "^## " "$PROJECTS_FILE" | sed 's/^## //')

if [ ${#ids[@]} -eq 0 ]; then
  log_warn "$(t list.no_projects)"
  exit 0
fi

echo ""
  printf "  ${BOLD}%-20s %-30s %-15s${RESET}\n" "$(t list.col_id)" "$(t list.col_path)" "$(t list.col_status)"
printf "  %s\n" "────────────────────────────────────────────────────────────"

for id in "${ids[@]}"; do
  local_path=$(get_project_path "$id" 2>/dev/null || true)

  if [ -z "$local_path" ]; then
    status="${YELLOW}$(t list.status_no_path)${RESET}"
    display_path="$(t list.path_undefined)"
    display_color="$YELLOW"
  elif [ -d "${local_path/#\~/$HOME}" ]; then
    status="${GREEN}$(t list.status_ok)${RESET}"
    display_path="$local_path"
    display_color=""
  else
    status="${RED}$(t list.status_missing)${RESET}"
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
