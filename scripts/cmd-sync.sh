#!/bin/bash
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

log_title "Synchronisation des skills"

if [ ! -d "$AGENTS_DIR" ]; then
  log_error "Dossier agents introuvable : $AGENTS_DIR"
  exit 1
fi

synced=0

for agent_file in "$AGENTS_DIR"/*.md; do
  [ -f "$agent_file" ] || continue

  agent_name=$(basename "$agent_file")

  # Lire le marqueur <!-- SKILLS: skill1, skill2 -->
  skills_line=$(grep -o '<!-- SKILLS:.*-->' "$agent_file" | head -1 || true)
  [ -z "$skills_line" ] && continue

  # Extraire les noms de skills
  skills_raw=$(echo "$skills_line" | sed 's/<!-- SKILLS://;s/-->//' | tr -d ' ')
  IFS=',' read -ra skills <<< "$skills_raw"

  # Construire le bloc injecté
  skills_block="<!-- SKILLS_START -->"
  for skill in "${skills[@]}"; do
    skill_file="$SKILLS_DIR/${skill}.md"
    if [ -f "$skill_file" ]; then
      skills_block+=$'\n\n'"$(cat "$skill_file")"
    else
      log_warn "[$agent_name] Skill introuvable : $skill.md"
    fi
  done
  skills_block+=$'\n\n<!-- SKILLS_END -->'

  # Remplacer ou insérer le bloc
  if grep -q "<!-- SKILLS_START -->" "$agent_file"; then
    perl -i -0pe 's/<!-- SKILLS_START -->.*?<!-- SKILLS_END -->/'"$skills_block"'/s' "$agent_file"
  else
    echo -e "\n\n$skills_block" >> "$agent_file"
  fi

  log_success "[$agent_name] Skills injectés : ${skills[*]}"
  synced=$((synced + 1))
done

echo ""
if [ $synced -eq 0 ]; then
  log_warn "Aucun agent avec marqueur SKILLS trouvé"
else
  log_success "$synced agent(s) synchronisé(s)"
fi
