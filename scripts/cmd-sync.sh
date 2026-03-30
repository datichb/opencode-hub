#!/bin/bash
# Synchronise les agents déployés sur tous les projets enregistrés localement.
# Usage : oc sync [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
source "$LIB_DIR/adapter-manager.sh"
source "$LIB_DIR/prompt-builder.sh"

DRY_RUN=false
for arg in "$@"; do
  [ "$arg" = "--dry-run" ] && DRY_RUN=true
done

if [ "$DRY_RUN" = true ]; then
  log_title "Vérification globale des agents déployés (dry-run)"
else
  log_title "Synchronisation des agents sur tous les projets"
fi

# S'assurer que projects.md existe
ensure_projects_file

# Extraire tous les PROJECT_IDs enregistrés
project_ids=()
while IFS= read -r line; do project_ids+=("$line"); done \
  < <(grep "^## " "$PROJECTS_FILE" 2>/dev/null | sed 's/^## //' || true)

if [ ${#project_ids[@]} -eq 0 ]; then
  log_warn "Aucun projet enregistré — lancez : ./oc.sh init"
  exit 0
fi

# Résoudre les cibles actives
active_targets=()
while IFS= read -r t; do active_targets+=("$t"); done < <(get_active_targets)

deployed_count=0
skipped_count=0
stale_count=0   # utilisé uniquement en dry-run
ok_count=0      # utilisé uniquement en dry-run

echo ""

for project_id in "${project_ids[@]}"; do
  echo -e "${BOLD}── Projet : $project_id${RESET}"

  # Résoudre le chemin local
  local_path=$(get_project_path "$project_id" 2>/dev/null || true)

  if [ -z "$local_path" ]; then
    log_info "  path non défini localement, ignoré"
    skipped_count=$((skipped_count + 1))
    echo ""
    continue
  fi

  # Expand ~ si nécessaire
  local_path="${local_path/#\~/$HOME}"

  if [ ! -d "$local_path" ]; then
    log_warn "  dossier introuvable : $local_path — ignoré"
    skipped_count=$((skipped_count + 1))
    echo ""
    continue
  fi

  if [ "$DRY_RUN" = true ]; then
    # ── Mode dry-run : vérifier la fraîcheur sans déployer ────────────────────
    project_stale=0
    project_ok=0

    for tgt in "${active_targets[@]}"; do
      gen_dir=""
      case "$tgt" in
        opencode)    gen_dir="$local_path/.opencode/agents" ;;
        claude-code) gen_dir="$local_path/.claude/agents" ;;
        vscode)      gen_dir="$local_path/.vscode/prompts" ;;
        *) continue ;;
      esac

      for agent_file in "$CANONICAL_AGENTS_DIR"/*.md; do
        [ -f "$agent_file" ] || continue
        agent_supports_target "$agent_file" "$tgt" || continue
        agent_id=$(get_agent_id "$agent_file")

        gen_file=""
        case "$tgt" in
          opencode|claude-code) gen_file="$gen_dir/${agent_id}.md" ;;
          vscode)               gen_file="$gen_dir/${agent_id}.prompt.md" ;;
        esac

        if [ ! -f "$gen_file" ]; then
          echo -e "  ${RED}✗ MANQUANT${RESET}   [$tgt] $agent_id"
          project_stale=$((project_stale + 1))
          continue
        fi

        gen_mtime=$(stat -f %m "$gen_file" 2>/dev/null || stat -c %Y "$gen_file" 2>/dev/null)
        max_src_mtime=0
        stale_reason=""

        agent_mtime=$(stat -f %m "$agent_file" 2>/dev/null || stat -c %Y "$agent_file" 2>/dev/null)
        [ "$agent_mtime" -gt "$max_src_mtime" ] && max_src_mtime=$agent_mtime

        while IFS= read -r skill; do
          [ -z "$skill" ] && continue
          skill_file="$SKILLS_DIR/${skill}.md"
          [ -f "$skill_file" ] || continue
          skill_mtime=$(stat -f %m "$skill_file" 2>/dev/null || stat -c %Y "$skill_file" 2>/dev/null)
          if [ "$skill_mtime" -gt "$max_src_mtime" ]; then
            max_src_mtime=$skill_mtime
            stale_reason="skill: $skill"
          fi
        done < <(extract_frontmatter_list "$agent_file" "skills")

        if [ "$agent_mtime" -gt "$gen_mtime" ] && [ "$max_src_mtime" = "$agent_mtime" ]; then
          stale_reason="agent source modifié"
        fi

        if [ "$max_src_mtime" -gt "$gen_mtime" ]; then
          echo -e "  ${YELLOW}⚠ OBSOLÈTE${RESET}   [$tgt] $agent_id  (${stale_reason:-source modifié})"
          project_stale=$((project_stale + 1))
        else
          echo -e "  ${GREEN}✓ À JOUR${RESET}     [$tgt] $agent_id"
          project_ok=$((project_ok + 1))
        fi
      done
    done

    stale_count=$((stale_count + project_stale))
    ok_count=$((ok_count + project_ok))

  else
    # ── Mode déploiement ──────────────────────────────────────────────────────
    deploy_ok=true
    # Exporter PROJECT_ID pour que les adaptateurs puissent lire api-keys.local.md
    PROJECT_ID="$project_id"
    for tgt in "${active_targets[@]}"; do
      load_adapter "$tgt"
      if adapter_validate 2>/dev/null; then
        adapter_deploy "$local_path" && log_success "  [$tgt] déployé" \
          || { log_warn "  [$tgt] échec déploiement"; deploy_ok=false; }
      else
        log_warn "  [$tgt] non disponible — ignoré"
      fi
    done
    if [ "$deploy_ok" = "true" ]; then
      deployed_count=$((deployed_count + 1))
    else
      skipped_count=$((skipped_count + 1))
    fi
  fi

  echo ""
done

# ── Rapport final ─────────────────────────────────────────────────────────────
if [ "$DRY_RUN" = true ]; then
  echo -e "Résultat : ${GREEN}$ok_count à jour${RESET}  |  ${YELLOW}$stale_count obsolète(s)/manquant(s)${RESET}  |  $skipped_count ignoré(s)"
  if [ "$stale_count" -gt 0 ]; then
    echo ""
    log_info "Pour déployer : ./oc.sh sync"
    exit 1
  fi
else
  echo -e "Résultat : ${GREEN}$deployed_count déployé(s)${RESET}  |  $skipped_count ignoré(s)"
fi
