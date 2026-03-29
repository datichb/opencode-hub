#!/usr/bin/env bats
# Tests unitaires pour scripts/common.sh
# Fonctions testées : get_project_language, get_project_tracker, project_exists,
#                     normalize_project_id

setup() {
  TEST_DIR="$(mktemp -d)"

  # Sourcer common.sh — PROJECTS_FILE sera recalculé depuis BASH_SOURCE
  source "$BATS_TEST_DIRNAME/../scripts/common.sh"

  # Surcharger PROJECTS_FILE après le source (écrase la valeur calculée)
  PROJECTS_FILE="$TEST_DIR/projects.md"

  # Écrire un projects.md minimal pour les tests
  cat > "$PROJECTS_FILE" <<'PROJEOF'
# Registre de test

## PROJ-FR
- Nom : Projet Français
- Stack : Test
- Board Beads : PROJ-FR
- Tracker : gitlab
- Labels : test

## PROJ-EN
- Nom : Projet Anglais
- Stack : Test
- Board Beads : PROJ-EN
- Tracker : jira
- Labels : test
- Langue : english

## PROJ-NO-TRACKER
- Nom : Sans Tracker
- Stack : Test
- Board Beads : PROJ-NO-TRACKER
- Labels : test
PROJEOF
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ── get_project_language ──────────────────────────────────────────────────────

@test "get_project_language : retourne la langue quand le champ Langue est présent" {
  run get_project_language "PROJ-EN"
  [ "$status" -eq 0 ]
  [ "$output" = "english" ]
}

@test "get_project_language : retourne une chaîne vide quand le champ Langue est absent" {
  local tmp_projects="$TEST_DIR/projects-no-lang.md"
  cat > "$tmp_projects" <<'EOF'
## PROJ-NO-LANG
- Nom : Sans Langue
- Stack : Test
- Board Beads : PROJ-NO-LANG
- Tracker : none
- Labels : test
EOF
  PROJECTS_FILE="$tmp_projects"
  run get_project_language "PROJ-NO-LANG"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "get_project_language : retourne une chaîne vide pour un PROJECT_ID inexistant" {
  run get_project_language "INEXISTANT"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

# ── get_project_tracker ───────────────────────────────────────────────────────

@test "get_project_tracker : retourne jira quand Tracker est jira" {
  run get_project_tracker "PROJ-EN"
  [ "$status" -eq 0 ]
  [ "$output" = "jira" ]
}

@test "get_project_tracker : retourne gitlab quand Tracker est gitlab" {
  run get_project_tracker "PROJ-FR"
  [ "$status" -eq 0 ]
  [ "$output" = "gitlab" ]
}

@test "get_project_tracker : retourne none quand le champ Tracker est absent" {
  run get_project_tracker "PROJ-NO-TRACKER"
  [ "$status" -eq 0 ]
  [ "$output" = "none" ]
}

# ── project_exists ────────────────────────────────────────────────────────────

@test "project_exists : retourne 0 pour un projet présent dans projects.md" {
  run project_exists "PROJ-FR"
  [ "$status" -eq 0 ]
}

@test "project_exists : retourne non-zero pour un projet absent" {
  run project_exists "INEXISTANT"
  [ "$status" -ne 0 ]
}

# ── normalize_project_id ──────────────────────────────────────────────────────

@test "normalize_project_id : convertit en majuscules" {
  run normalize_project_id "mon-app"
  [ "$status" -eq 0 ]
  [ "$output" = "MON-APP" ]
}
