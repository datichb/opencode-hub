#!/bin/bash
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

log_title "Projets enregistrés"

if [ ! -f "$PROJECTS_FILE" ]; then
  log_warn "Aucun fichier projects.md trouvé"
  exit 0
fi

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
  local_path=$(get_project_path "$id")
  local_path="${local_path:-${YELLOW}non défini${RESET}}"

  if [ -d "${local_path/#\~/$HOME}" ]; then
    status="${GREEN}✔ accessible${RESET}"
  elif [ "$local_path" = "${YELLOW}non défini${RESET}" ]; then
    status="${YELLOW}⚠ sans chemin${RESET}"
  else
    status="${RED}✘ introuvable${RESET}"
  fi

  printf "  %-20s %-30s " "$id" "$local_path"
  echo -e "$status"
done

echo ""
