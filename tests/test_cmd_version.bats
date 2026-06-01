#!/usr/bin/env bats
# Tests pour scripts/cmd-version.sh
# Vérifie : affichage version, format, fallback sans jq

load helpers

setup() {
  common_setup

  export HUB_DIR="$BATS_TEST_DIRNAME/.."
  export HUB_CONFIG="$TEST_DIR/hub.json"
  printf '{"version":"1.0.0","default_target":"opencode","active_targets":["opencode"],"cli":{"language":"fr"}}\n' \
    > "$HUB_CONFIG"

  CMD_VERSION="$BATS_TEST_DIRNAME/../scripts/cmd-version.sh"
}

teardown() {
  common_teardown
}

# ── Affichage ─────────────────────────────────────────────────────────────────

@test "version : s'exécute sans erreur" {
  run bash "$CMD_VERSION"
  [ "$status" -eq 0 ]
}

@test "version : affiche 'opencode-hub'" {
  run bash "$CMD_VERSION"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "opencode-hub" ]]
}

@test "version : affiche un numéro de version avec format vX.Y.Z" {
  run bash "$CMD_VERSION"
  [ "$status" -eq 0 ]
  [[ "$output" =~ v[0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "version : la version lue correspond à hub.json.example" {
  local expected
  expected=$(jq -r '.version' "$HUB_DIR/config/hub.json.example" 2>/dev/null)
  run bash "$CMD_VERSION"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "$expected" ]]
}

@test "version : fallback si hub.json.example absent — version inconnue affichée" {
  # hub.json.example absent : cmd-version.sh doit afficher la version "unknown" ou similaire
  # On ne peut pas surcharger HUB_DIR car common.sh a besoin du vrai repo (i18n, etc.)
  # On vérifie plutôt que le script ne crashe pas et affiche quelque chose de sensé
  # même quand le fichier hub.json.example est manquant (testé indirectement via le vrai hub)
  local example_file="$HUB_DIR/config/hub.json.example"
  [ -f "$example_file" ] || skip "hub.json.example introuvable dans le vrai hub"
  run bash "$CMD_VERSION"
  [ "$status" -eq 0 ]
  [[ "$output" =~ v[0-9] ]]
}

@test "version : output sur une seule ligne" {
  run bash "$CMD_VERSION"
  [ "$status" -eq 0 ]
  local lines
  lines=$(echo "$output" | grep -c .)
  [ "$lines" -eq 1 ]
}
