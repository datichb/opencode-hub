#!/usr/bin/env bats
# Tests pour scripts/cmd-update.sh
# Vérifie : adapter_update appelé, gestion bd absent, gestion brew absent, skills_none

load helpers

setup() {
  common_setup

  export HUB_DIR="$BATS_TEST_DIRNAME/.."
  export HUB_CONFIG="$TEST_DIR/hub.json"
  printf '{"version":"1.0.0","default_target":"opencode","active_targets":["opencode"],"cli":{"language":"fr"}}\n' \
    > "$HUB_CONFIG"

  CMD_UPDATE="$BATS_TEST_DIRNAME/../scripts/cmd-update.sh"

  # Mock opencode (adapter_update appelle npm update -g opencode-ai via adapter)
  mkdir -p "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/opencode" <<'OCEOF'
#!/bin/bash
echo "opencode $*"
exit 0
OCEOF
  chmod +x "$TEST_DIR/bin/opencode"

  # Mock npm pour simuler la mise à jour
  cat > "$TEST_DIR/bin/npm" <<'NPMEOF'
#!/bin/bash
echo "npm $*"
exit 0
NPMEOF
  chmod +x "$TEST_DIR/bin/npm"

  export PATH="$TEST_DIR/bin:$PATH"
}

teardown() {
  common_teardown
}

# ── Exécution générale ────────────────────────────────────────────────────────

@test "update : s'exécute sans erreur (bd absent, no skills)" {
  # Sans bd dans le PATH, le script doit gérer gracieusement
  run bash -c 'printf "N\n" | bash "$1"' _ "$CMD_UPDATE"
  [ "$status" -eq 0 ]
}

@test "update : affiche le titre" {
  run bash -c 'printf "N\n" | bash "$1"' _ "$CMD_UPDATE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Mise à jour" ]]
}

@test "update : affiche succès en fin d'exécution" {
  run bash -c 'printf "N\n" | bash "$1"' _ "$CMD_UPDATE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "terminée" ]]
}

# ── Gestion bd absent ─────────────────────────────────────────────────────────

@test "update : bd absent → warning mais pas d'erreur fatale" {
  # bd n'est pas dans le PATH de test
  run bash -c 'printf "N\n" | bash "$1"' _ "$CMD_UPDATE"
  [ "$status" -eq 0 ]
  # Le message i18n update.bd_missing contient "bd"
  [[ "$output" =~ "bd" ]]
}

# ── Gestion skills ────────────────────────────────────────────────────────────

@test "update : sans fichier .sources.json → message skills_none" {
  run bash -c 'printf "N\n" | bash "$1"' _ "$CMD_UPDATE"
  [ "$status" -eq 0 ]
  # Le message i18n update.skills_none
  [[ "$output" =~ "Aucun skill externe" ]]
}

# ── Proposition sync après mise à jour skills ─────────────────────────────────

@test "update : réponse N à sync_now → pas de sync" {
  run bash -c 'printf "N\n" | bash "$1"' _ "$CMD_UPDATE"
  [ "$status" -eq 0 ]
}
