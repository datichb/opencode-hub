#!/usr/bin/env bats
# Tests de smoke — vérifie que les commandes principales existent et peuvent s'exécuter
# Ces tests ne vérifient PAS la logique métier, seulement l'absence d'erreurs critiques
# (syntaxe bash, fonctions manquantes, chemins invalides, etc.)

setup() {
  TEST_DIR="$(mktemp -d)"
  HUB_ROOT="$BATS_TEST_DIRNAME/.."
  
  # Mock minimal pour éviter les dépendances externes
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME/.config/opencode"
  
  # Créer un hub.json minimal
  cat > "$TEST_DIR/hub.json" <<'EOF'
{
  "version": "test",
  "default_target": "opencode",
  "active_targets": ["opencode"],
  "opencode": {"model": "claude-sonnet-4-5"}
}
EOF
  export HUB_CONFIG="$TEST_DIR/hub.json"
  
  # Créer un projects.md minimal
  cat > "$TEST_DIR/projects.md" <<'EOF'
# Projects

## TEST-SMOKE
- Nom : Test Smoke
- Stack : Test
EOF
  export PROJECTS_FILE="$TEST_DIR/projects.md"
  
  # Mock les fonctions log pour silence
  log_info() { true; }
  log_success() { true; }
  log_warn() { true; }
  log_error() { true; }
  export -f log_info log_success log_warn log_error
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ── oc.sh principal ───────────────────────────────────────────────────────────

@test "oc.sh existe et est exécutable" {
  [ -f "$HUB_ROOT/oc.sh" ]
  [ -x "$HUB_ROOT/oc.sh" ]
}

@test "oc.sh affiche l'aide sans erreur (--help)" {
  run bash "$HUB_ROOT/oc.sh" --help
  [ "$status" -eq 0 ]
}

@test "oc.sh affiche la version sans erreur (--version)" {
  run bash "$HUB_ROOT/oc.sh" --version
  [ "$status" -eq 0 ]
}

# ── common.sh ─────────────────────────────────────────────────────────────────

@test "common.sh peut être sourcé sans erreur" {
  run bash -c "source '$HUB_ROOT/scripts/common.sh' && echo OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Commandes principales (cmd-*.sh) ──────────────────────────────────────────

@test "cmd-config.sh peut être sourcé sans erreur" {
  run bash -c "
    source '$HUB_ROOT/scripts/common.sh'
    _CMD_CONFIG_SOURCE_ONLY=1 source '$HUB_ROOT/scripts/cmd-config.sh'
    echo OK
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "cmd-beads.sh peut être sourcé sans erreur" {
  run bash -c "
    source '$HUB_ROOT/scripts/common.sh'
    _CMD_BEADS_SOURCE_ONLY=1 source '$HUB_ROOT/scripts/cmd-beads.sh'
    echo OK
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "cmd-deploy.sh a une syntaxe bash valide" {
  run bash -n "$HUB_ROOT/scripts/cmd-deploy.sh"
  [ "$status" -eq 0 ]
}

@test "cmd-init.sh a une syntaxe bash valide" {
  run bash -n "$HUB_ROOT/scripts/cmd-init.sh"
  [ "$status" -eq 0 ]
}

@test "cmd-provider.sh a une syntaxe bash valide" {
  run bash -n "$HUB_ROOT/scripts/cmd-provider.sh"
  [ "$status" -eq 0 ]
}

# ── Librairies (lib/*.sh) ─────────────────────────────────────────────────────

@test "lib/api-keys.sh peut être sourcé sans erreur" {
  run bash -c "
    source '$HUB_ROOT/scripts/common.sh'
    source '$HUB_ROOT/scripts/lib/api-keys.sh'
    echo OK
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "lib/prompt-builder.sh peut être sourcé sans erreur" {
  run bash -c "
    source '$HUB_ROOT/scripts/common.sh'
    source '$HUB_ROOT/scripts/lib/prompt-builder.sh'
    echo OK
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "lib/providers.sh peut être sourcé sans erreur" {
  run bash -c "
    source '$HUB_ROOT/scripts/common.sh'
    source '$HUB_ROOT/scripts/lib/providers.sh'
    echo OK
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "lib/adapter-manager.sh peut être sourcé sans erreur" {
  run bash -c "
    source '$HUB_ROOT/scripts/common.sh'
    source '$HUB_ROOT/scripts/lib/adapter-manager.sh'
    echo OK
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Adapters ──────────────────────────────────────────────────────────────────

@test "opencode.adapter.sh peut être sourcé sans erreur" {
  run bash -c "
    source '$HUB_ROOT/scripts/common.sh'
    source '$HUB_ROOT/scripts/lib/prompt-builder.sh'
    source '$HUB_ROOT/scripts/adapters/opencode.adapter.sh'
    echo OK
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Vérifications structurelles ───────────────────────────────────────────────

@test "le dossier agents/ existe et contient des agents" {
  [ -d "$HUB_ROOT/agents" ]
  agent_count=$(find "$HUB_ROOT/agents" -name "*.md" -type f | wc -l)
  [ "$agent_count" -gt 0 ]
}

@test "le dossier skills/ existe et contient des skills" {
  [ -d "$HUB_ROOT/skills" ]
  skill_count=$(find "$HUB_ROOT/skills" -name "*.md" -type f | wc -l)
  [ "$skill_count" -gt 0 ]
}

@test "le fichier config/hub.json.example existe et est du JSON valide" {
  [ -f "$HUB_ROOT/config/hub.json.example" ]
  command -v jq &>/dev/null || skip "jq non disponible"
  run jq . "$HUB_ROOT/config/hub.json.example"
  [ "$status" -eq 0 ]
}

@test "le fichier config/providers.json existe et est du JSON valide" {
  [ -f "$HUB_ROOT/config/providers.json" ]
  command -v jq &>/dev/null || skip "jq non disponible"
  run jq . "$HUB_ROOT/config/providers.json"
  [ "$status" -eq 0 ]
}

# ── ShellCheck basic (si disponible) ──────────────────────────────────────────

@test "oc.sh passe shellcheck basic (si disponible)" {
  command -v shellcheck &>/dev/null || skip "shellcheck non disponible"
  run shellcheck -S warning "$HUB_ROOT/oc.sh"
  [ "$status" -eq 0 ]
}

@test "common.sh passe shellcheck basic (si disponible)" {
  command -v shellcheck &>/dev/null || skip "shellcheck non disponible"
  run shellcheck -S warning "$HUB_ROOT/scripts/common.sh"
  [ "$status" -eq 0 ]
}
