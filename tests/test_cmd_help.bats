#!/usr/bin/env bats
# Tests pour scripts/cmd-help.sh
# Vérifie : sections affichées, commandes listées, code de sortie, i18n

load helpers

setup() {
  common_setup

  export HUB_DIR="$BATS_TEST_DIRNAME/.."
  export HUB_CONFIG="$TEST_DIR/hub.json"
  printf '{"version":"1.0.0","default_target":"opencode","active_targets":["opencode"],"cli":{"language":"fr"}}\n' \
    > "$HUB_CONFIG"

  CMD_HELP="$BATS_TEST_DIRNAME/../scripts/cmd-help.sh"
}

teardown() {
  common_teardown
}

# ── Comportement général ──────────────────────────────────────────────────────

@test "help : s'exécute sans erreur" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
}

@test "help : output non vide" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "help : affiche plusieurs lignes" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  local lines
  lines=$(echo "$output" | grep -c .)
  [ "$lines" -gt 10 ]
}

# ── Sections ──────────────────────────────────────────────────────────────────

@test "help : contient une section setup/installation" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ [Ss]etup ]] || [[ "$output" =~ [Ii]nstall ]] || [[ "$output" =~ [Cc]onfiguration ]]
}

@test "help : contient une section projets/projects" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ [Pp]rojet ]] || [[ "$output" =~ [Pp]roject ]]
}

@test "help : contient une section lancement/launch" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ [Ll]ancement ]] || [[ "$output" =~ [Ll]aunch ]] || [[ "$output" =~ [Ss]tart ]]
}

@test "help : contient une section analyse/analysis" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ [Aa]nalyse ]] || [[ "$output" =~ [Aa]nalysis ]] || [[ "$output" =~ [Aa]udit ]]
}

@test "help : contient une section maintenance" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ [Mm]aintenance ]] || [[ "$output" =~ [Mm]aintien ]]
}

@test "help : contient une section config" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ [Cc]onfig ]]
}

# ── Commandes listées ─────────────────────────────────────────────────────────

@test "help : mentionne la commande start" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "start" ]]
}

@test "help : mentionne la commande deploy" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "deploy" ]]
}

@test "help : mentionne la commande audit" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "audit" ]]
}

@test "help : mentionne des exemples d'utilisation" {
  run bash "$CMD_HELP"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "oc.sh" ]] || [[ "$output" =~ "oc " ]]
}
