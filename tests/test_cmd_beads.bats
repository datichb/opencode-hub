#!/usr/bin/env bats
# Tests unitaires pour scripts/cmd-beads.sh
# Fonctions testées : _set_project_tracker, _resolve_tracker, _resolve_project_path
#
# Stratégie : cmd-beads.sh ne peut pas être sourcé directement (top-level dispatch
# + re-source de common.sh). Les fonctions à tester sont redéfinies ici après
# source de common.sh, en copie fidèle du code source.

setup() {
  TEST_DIR="$(mktemp -d)"

  # Sourcer common.sh pour les fonctions partagées
  source "$BATS_TEST_DIRNAME/../scripts/common.sh"

  # Surcharger les fichiers de données
  PROJECTS_FILE="$TEST_DIR/projects.md"
  PATHS_FILE="$TEST_DIR/paths.local.md"

  # ── Redéfinir les fonctions de cmd-beads.sh testables ─────────────────────

  _resolve_tracker() {
    local id="$1"
    local tracker
    tracker=$(get_project_tracker "$id")
    tracker=$(echo "$tracker" | tr '[:upper:]' '[:lower:]')
    if [ "$tracker" = "none" ] || [ -z "$tracker" ]; then
      log_error "Aucun tracker configuré pour $id"
      log_info  "Configurer : ./oc.sh beads tracker setup $id"
      exit 1
    fi
    echo "$tracker"
  }

  _set_project_tracker() {
    local id="$1" new_tracker="$2"
    case "$new_tracker" in
      jira|gitlab|none) ;;
      *) log_error "Tracker invalide : $new_tracker (jira | gitlab | none)"; exit 1 ;;
    esac
    if perl -i -0777pe "
      s{(^## \Q${id}\E\n.*?)(- Tracker : \S+)}{\${1}- Tracker : ${new_tracker}}ms
    " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Tracker : ${new_tracker}" "$PROJECTS_FILE"; then
      return 0
    fi
    if perl -i -0777pe "
      s{(^## \Q${id}\E\n.*?- Labels : [^\n]+\n)}{\${1}- Tracker : ${new_tracker}\n}ms
    " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Tracker : ${new_tracker}" "$PROJECTS_FILE"; then
      return 0
    fi
    if perl -i -0777pe "
      s{(^## \Q${id}\E\n.*?- [^\n]+\n)}{\${1}- Tracker : ${new_tracker}\n}ms
    " "$PROJECTS_FILE" 2>/dev/null && grep -q -- "- Tracker : ${new_tracker}" "$PROJECTS_FILE"; then
      return 0
    fi
    log_error "Impossible d'insérer le champ Tracker dans le bloc $id de projects.md"
    return 1
  }

  _resolve_project_path() {
    local id="$1"
    id=$(normalize_project_id "$id")
    if ! project_exists "$id"; then
      log_error "Projet $id introuvable → ./oc.sh list"
      exit 1
    fi
    local path
    path=$(get_project_path "$id")
    path="${path/#\~/$HOME}"
    if [ -z "$path" ]; then
      log_error "Aucun chemin local pour $id → ./oc.sh init $id"
      exit 1
    fi
    if [ ! -d "$path" ]; then
      log_error "Dossier introuvable : $path"
      exit 1
    fi
    echo "$path"
  }

  # ── Données de test ───────────────────────────────────────────────────────

  cat > "$PROJECTS_FILE" <<'PROJEOF'
# Registre de test

## PROJ-FULL
- Nom : Projet complet
- Stack : Test
- Board Beads : PROJ-FULL
- Tracker : jira
- Labels : feature,fix

## PROJ-NO-TRACKER
- Nom : Sans Tracker
- Stack : Test
- Board Beads : PROJ-NO-TRACKER
- Labels : test

## PROJ-NONE
- Nom : Tracker none
- Stack : Test
- Board Beads : PROJ-NONE
- Tracker : none
- Labels : test

## PROJ-NO-LABELS
- Nom : Sans Labels
- Stack : Test
- Board Beads : PROJ-NO-LABELS

## PROJ-CASE
- Nom : Casse incorrecte
- Stack : Test
- Board Beads : PROJ-CASE
- Tracker : Jira
- Labels : test
PROJEOF

  mkdir -p "$TEST_DIR/fake-project"
  cat > "$PATHS_FILE" <<EOF
PROJ-FULL=$TEST_DIR/fake-project
PROJ-NO-TRACKER=$TEST_DIR/fake-project
PROJ-NONE=$TEST_DIR/fake-project
PROJ-NO-LABELS=$TEST_DIR/fake-project
PROJ-CASE=$TEST_DIR/fake-project
EOF
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ── _resolve_tracker ──────────────────────────────────────────────────────────

@test "_resolve_tracker : retourne le tracker quand il est configuré" {
  run _resolve_tracker "PROJ-FULL"
  [ "$status" -eq 0 ]
  [ "$output" = "jira" ]
}

@test "_resolve_tracker : normalise en minuscules (Jira → jira)" {
  run _resolve_tracker "PROJ-CASE"
  [ "$status" -eq 0 ]
  [ "$output" = "jira" ]
}

@test "_resolve_tracker : exit si tracker est none" {
  run _resolve_tracker "PROJ-NONE"
  [ "$status" -ne 0 ]
}

@test "_resolve_tracker : exit si aucun tracker configuré" {
  run _resolve_tracker "PROJ-NO-TRACKER"
  [ "$status" -ne 0 ]
}

# ── _set_project_tracker ─────────────────────────────────────────────────────

@test "_set_project_tracker : remplace un tracker existant" {
  _set_project_tracker "PROJ-FULL" "gitlab"
  run grep -F -- "- Tracker : gitlab" "$PROJECTS_FILE"
  [ "$status" -eq 0 ]
  # L'ancien tracker ne doit plus être présent pour ce projet
  local block
  block=$(sed -n '/^## PROJ-FULL$/,/^## /{/^## PROJ-FULL$/d;/^## /d;p;}' "$PROJECTS_FILE")
  ! echo "$block" | grep -q -- "- Tracker : jira"
}

@test "_set_project_tracker : ajoute après Labels si Tracker absent" {
  _set_project_tracker "PROJ-NO-TRACKER" "gitlab"
  run grep -F -- "- Tracker : gitlab" "$PROJECTS_FILE"
  [ "$status" -eq 0 ]
}

@test "_set_project_tracker : fallback — ajoute après dernier champ si Labels absent" {
  _set_project_tracker "PROJ-NO-LABELS" "jira"
  run grep -F -- "- Tracker : jira" "$PROJECTS_FILE"
  [ "$status" -eq 0 ]
}

@test "_set_project_tracker : whitelist — rejette une valeur invalide" {
  run _set_project_tracker "PROJ-FULL" "bitbucket"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "invalide"
}

@test "_set_project_tracker : accepte none comme valeur valide" {
  _set_project_tracker "PROJ-FULL" "none"
  run grep -F -- "- Tracker : none" "$PROJECTS_FILE"
  [ "$status" -eq 0 ]
}

@test "_set_project_tracker : ne modifie pas les autres projets" {
  _set_project_tracker "PROJ-FULL" "gitlab"
  # PROJ-NONE doit toujours avoir son tracker original
  local block
  block=$(sed -n '/^## PROJ-NONE$/,/^## /{/^## PROJ-NONE$/d;/^## /d;p;}' "$PROJECTS_FILE")
  echo "$block" | grep -q -- "- Tracker : none"
}

# ── _resolve_project_path ─────────────────────────────────────────────────────

@test "_resolve_project_path : retourne le chemin d'un projet valide" {
  run _resolve_project_path "PROJ-FULL"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_DIR/fake-project" ]
}

@test "_resolve_project_path : exit si le projet n'existe pas" {
  run _resolve_project_path "INEXISTANT"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "introuvable"
}

@test "_resolve_project_path : exit si le chemin est vide" {
  # Écraser paths avec un projet sans chemin
  cat > "$PATHS_FILE" <<EOF
PROJ-NO-TRACKER=
EOF
  run _resolve_project_path "PROJ-NO-TRACKER"
  [ "$status" -ne 0 ]
}

@test "_resolve_project_path : exit si le dossier n'existe pas sur le disque" {
  cat > "$PATHS_FILE" <<EOF
PROJ-FULL=$TEST_DIR/dossier-inexistant
EOF
  run _resolve_project_path "PROJ-FULL"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "introuvable"
}
