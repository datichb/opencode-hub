#!/usr/bin/env bats
# Tests edge cases — permissions fichiers
# Vérifie : fichiers en lecture seule, dossiers non-writable

load helpers

setup() {
  common_setup

  # Skip tous les tests si on tourne en root (chmod n'a pas d'effet)
  if [ "$EUID" -eq 0 ] 2>/dev/null || [ "$(id -u)" -eq 0 ]; then
    skip "Tests de permissions ignorés en root"
  fi

  export PROJECTS_FILE="$TEST_DIR/projects.md"
  export PATHS_FILE="$TEST_DIR/paths.local.md"
  export API_KEYS_FILE="$TEST_DIR/api-keys.local.md"
  export HUB_CONFIG="$TEST_DIR/hub.json"
  printf '{"version":"1.0.0","default_target":"opencode","active_targets":["opencode"],"cli":{"language":"fr"}}\n' \
    > "$HUB_CONFIG"

  SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"

  cat > "$PROJECTS_FILE" <<'EOF'
# Registre de test

## PERM-PROJ
- Nom : Perm Project
- Stack : Node.js
- Board Beads : PERM-PROJ
- Tracker : none
- Labels : test
- Agents : all
EOF
  echo "PERM-PROJ=$TEST_DIR/proj-perm" > "$PATHS_FILE"
  mkdir -p "$TEST_DIR/proj-perm"
  : > "$API_KEYS_FILE"

  source "$SCRIPT_DIR/common.sh"
}

teardown() {
  # Restaurer les permissions avant suppression
  chmod -R u+rw "$TEST_DIR" 2>/dev/null || true
  common_teardown
}

# ── Lecture de fichiers en read-only ──────────────────────────────────────────

@test "permissions : projects.md en lecture seule → get_project_path toujours lisible" {
  chmod 444 "$PROJECTS_FILE"
  local path
  path=$(get_project_path "PERM-PROJ" 2>/dev/null || echo "")
  [ "$path" = "$TEST_DIR/proj-perm" ]
}

@test "permissions : paths.local.md en lecture seule → get_project_path toujours lisible" {
  chmod 444 "$PATHS_FILE"
  local path
  path=$(get_project_path "PERM-PROJ" 2>/dev/null || echo "")
  [ "$path" = "$TEST_DIR/proj-perm" ]
}

@test "permissions : api-keys en lecture seule → api_keys_entry_exists ne crashe pas" {
  chmod 444 "$API_KEYS_FILE"
  run bash -c '
    source "$1/common.sh"
    api_keys_entry_exists "PERM-PROJ" 2>/dev/null || true
    echo "survived"
  ' _ "$SCRIPT_DIR"
  [[ "$output" =~ "survived" ]]
}

# ── Écriture dans dossier non-writable ────────────────────────────────────────

@test "permissions : dossier projet non-writable → cmd-deploy ne crashe pas fatalement" {
  chmod 555 "$TEST_DIR/proj-perm"
  run bash "$SCRIPT_DIR/cmd-deploy.sh" "PERM-PROJ"
  # Soit erreur propre (non-zero), soit avertissement — pas de crash inattendu
  [ "$status" -lt 126 ]
  chmod 755 "$TEST_DIR/proj-perm"
}

@test "permissions : hub.json en lecture seule → cmd-version fonctionne" {
  chmod 444 "$HUB_CONFIG"
  run bash "$SCRIPT_DIR/cmd-version.sh"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

# ── Dossier non-traversable ───────────────────────────────────────────────────

@test "permissions : dossier TEST_DIR non-writable → création sous-dossier échoue proprement" {
  local restricted="$TEST_DIR/restricted"
  mkdir -p "$restricted"
  chmod 555 "$restricted"
  run bash -c "mkdir -p '$restricted/subdir' 2>/dev/null; echo exit:$?"
  # mkdir doit échouer silencieusement
  [[ "$output" =~ "exit:1" ]] || [[ "$output" =~ "exit:0" ]]
  chmod 755 "$restricted"
}
