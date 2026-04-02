#!/usr/bin/env bats
# Tests unitaires pour scripts/cmd-beads.sh
# Fonctions testées : _set_project_tracker, _resolve_tracker, cmd_init
#
# Grâce au guard BASH_SOURCE, cmd-beads.sh peut être sourcé directement :
# il n'exécute le dispatch que lorsqu'il est lancé en tant que script principal.
# On source common.sh puis cmd-beads.sh pour obtenir les vraies fonctions.

setup() {
  TEST_DIR="$(mktemp -d)"

  # Sourcer common.sh pour les fonctions partagées
  source "$BATS_TEST_DIRNAME/../scripts/common.sh"

  # Surcharger les fichiers de données
  PROJECTS_FILE="$TEST_DIR/projects.md"
  PATHS_FILE="$TEST_DIR/paths.local.md"

  # Sourcer cmd-beads.sh (le dispatch ne s'exécute pas grâce au guard BASH_SOURCE)
  source "$BATS_TEST_DIRNAME/../scripts/cmd-beads.sh"

  # Mock de bd — enregistre les appels dans BD_CALLS_LOG
  BD_CALLS_LOG="$TEST_DIR/bd_calls.log"
  export BD_CALLS_LOG
  : > "$BD_CALLS_LOG"
  bd() {
    local _oifs="${IFS-}" ; IFS=' '
    echo "bd $*" >> "$BD_CALLS_LOG"
    IFS="$_oifs"
    # bd init → créer .beads/ dans le répertoire courant
    if [ "$1" = "init" ]; then
      mkdir -p .beads
    fi
    return 0
  }
  export -f bd

  # Mock git — intercepte remote, enregistre les appels, délègue le reste
  GIT_CALLS_LOG="$TEST_DIR/git_calls.log"
  export GIT_CALLS_LOG
  : > "$GIT_CALLS_LOG"
  REAL_GIT="$(command -v git)"
  git() {
    echo "git $*" >> "$GIT_CALLS_LOG"
    if [ "${1:-}" = "remote" ]; then
      if [ "${2:-}" = "get-url" ]; then
        return 1  # Simuler aucun remote configuré
      elif [ "${2:-}" = "add" ]; then
        return 0
      fi
      return 0
    fi
    "$REAL_GIT" "$@"
  }
  export -f git

  # Fonctions guard simplifiées
  _require_bd() { return 0; }
  require_project_id() { [ -z "${1:-}" ] && { log_error "PROJECT_ID requis"; exit 1; }; return 0; }

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

# ── resolve_project_path ──────────────────────────────────────────────────────

@test "resolve_project_path : retourne le chemin d'un projet valide" {
  run resolve_project_path "PROJ-FULL"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_DIR/fake-project" ]
}

@test "resolve_project_path : exit si le projet n'existe pas" {
  run resolve_project_path "INEXISTANT"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "introuvable"
}

@test "resolve_project_path : exit si le chemin est vide" {
  # Écraser paths avec un projet sans chemin
  cat > "$PATHS_FILE" <<EOF
PROJ-NO-TRACKER=
EOF
  run resolve_project_path "PROJ-NO-TRACKER"
  [ "$status" -ne 0 ]
}

@test "resolve_project_path : exit si le dossier n'existe pas sur le disque" {
  cat > "$PATHS_FILE" <<EOF
PROJ-FULL=$TEST_DIR/dossier-inexistant
EOF
  run resolve_project_path "PROJ-FULL"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "introuvable"
}

# ── cmd_init — propagation des labels ─────────────────────────────────────────

@test "cmd_init : appelle bd init et propage les labels du projet" {
  # Nettoyer le log bd et le .beads potentiel
  : > "$BD_CALLS_LOG"
  rm -rf "$TEST_DIR/fake-project/.beads"
  run cmd_init "PROJ-FULL"
  [ "$status" -eq 0 ]
  # bd init a été appelé
  grep -q "bd init" "$BD_CALLS_LOG"
  # Les labels feature,fix ont été propagés
  grep -q "bd label add feature" "$BD_CALLS_LOG"
  grep -q "bd label add fix" "$BD_CALLS_LOG"
}

@test "cmd_init : ne propage rien si aucun label configuré" {
  : > "$BD_CALLS_LOG"
  rm -rf "$TEST_DIR/fake-project/.beads"
  run cmd_init "PROJ-NO-LABELS"
  [ "$status" -eq 0 ]
  # bd init appelé, mais pas bd label add
  grep -q "bd init" "$BD_CALLS_LOG"
  ! grep -q "bd label add" "$BD_CALLS_LOG"
}

@test "cmd_init : exit si .beads existe déjà" {
  # .beads existe déjà (créé par un test précédent ou manuellement)
  mkdir -p "$TEST_DIR/fake-project/.beads"
  run cmd_init "PROJ-FULL"
  # exit 0 avec un warning
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "déjà initialisé"
}

# ── cmd_init — proposition upstream git ──────────────────────────────────────

@test "cmd_init : propose upstream et avertit URL vide si stdin vide" {
  # run fournit /dev/null comme stdin → read retourne vide
  # _setup_upstream vide → default Y → URL vide → avertissement
  : > "$BD_CALLS_LOG"
  : > "$GIT_CALLS_LOG"
  rm -rf "$TEST_DIR/fake-project/.beads"
  run cmd_init "PROJ-FULL"
  [ "$status" -eq 0 ]

  # git remote get-url upstream a été testé
  grep -q "git remote get-url upstream" "$GIT_CALLS_LOG"
  # URL vide → avertissement
  [[ "$output" == *"URL vide"* ]]
}

@test "cmd_init : configure upstream si URL fournie via stdin" {
  : > "$BD_CALLS_LOG"
  : > "$GIT_CALLS_LOG"
  rm -rf "$TEST_DIR/fake-project/.beads"
  # Fournir Y + URL via fichier stdin
  printf "Y\nhttps://github.com/test/repo.git\n" > "$TEST_DIR/stdin_upstream.txt"
  run cmd_init "PROJ-FULL" < "$TEST_DIR/stdin_upstream.txt"
  [ "$status" -eq 0 ]

  # git remote add upstream a été appelé avec l'URL
  grep -q "git remote add upstream https://github.com/test/repo.git" "$GIT_CALLS_LOG"
  [[ "$output" == *"Remote upstream configuré"* ]]
}

@test "cmd_init : respecte le refus de configurer upstream" {
  : > "$BD_CALLS_LOG"
  : > "$GIT_CALLS_LOG"
  rm -rf "$TEST_DIR/fake-project/.beads"
  # Fournir n via fichier stdin → pas de question URL
  printf "n\n" > "$TEST_DIR/stdin_refuse.txt"
  run cmd_init "PROJ-FULL" < "$TEST_DIR/stdin_refuse.txt"
  [ "$status" -eq 0 ]

  # git remote add ne doit PAS avoir été appelé
  ! grep -q "git remote add upstream" "$GIT_CALLS_LOG"
  [[ "$output" == *"Configurer plus tard"* ]]
}
