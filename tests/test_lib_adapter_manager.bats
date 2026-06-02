#!/usr/bin/env bats
# Tests unitaires pour scripts/lib/adapter-manager.sh
# Fonctions testées : load_adapter (charge toujours opencode.adapter.sh)

load helpers

setup() {
  common_setup
  
  # Sourcer common.sh
  export SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  export LIB_DIR="$SCRIPT_DIR/lib"
  export ADAPTERS_DIR="$TEST_DIR/adapters"
  source "$SCRIPT_DIR/common.sh"
  
  # Sourcer le module
  source "$BATS_TEST_DIRNAME/../scripts/lib/adapter-manager.sh"
  
  # Créer dossier adapters
  mkdir -p "$ADAPTERS_DIR"
}

teardown() {
  common_teardown
}

# ── load_adapter ────────────────────────────────────────────────────────────

@test "load_adapter : charge opencode.adapter.sh" {
  # Créer un adaptateur opencode de test
  cat > "$ADAPTERS_DIR/opencode.adapter.sh" <<'EOF'
adapter_validate() { return 0; }
adapter_needs_node() { return 0; }
adapter_deploy_files() { return 0; }
adapter_deploy_config() { return 0; }
adapter_deploy() { return 0; }
adapter_install() { return 0; }
adapter_update() { return 0; }
adapter_start() { return 0; }
EOF
  
  # Appeler sans run pour que les fonctions restent visibles dans le shell courant
  load_adapter
  
  # Vérifier que les fonctions sont définies
  run declare -F adapter_validate
  [ "$status" -eq 0 ]
}

@test "load_adapter : échoue si opencode.adapter.sh absent" {
  # ADAPTERS_DIR vide → pas de opencode.adapter.sh
  run load_adapter
  [ "$status" -ne 0 ]
}

@test "load_adapter : échoue si fonction manquante dans opencode.adapter.sh" {
  # Adaptateur incomplet
  cat > "$ADAPTERS_DIR/opencode.adapter.sh" <<'EOF'
adapter_validate() { return 0; }
adapter_needs_node() { return 0; }
# Fonctions manquantes...
EOF
  
  run load_adapter
  [ "$status" -ne 0 ]
}

@test "load_adapter : exporte toutes les fonctions requises" {
  cat > "$ADAPTERS_DIR/opencode.adapter.sh" <<'EOF'
adapter_validate() { echo "validate"; }
adapter_needs_node() { echo "needs_node"; }
adapter_deploy_files() { echo "deploy_files"; }
adapter_deploy_config() { echo "deploy_config"; }
adapter_deploy() { echo "deploy"; }
adapter_install() { echo "install"; }
adapter_update() { echo "update"; }
adapter_start() { echo "start"; }
EOF
  
  load_adapter
  
  run adapter_validate
  [ "$output" = "validate" ]
  
  run adapter_deploy
  [ "$output" = "deploy" ]
}

# ── Intégration ─────────────────────────────────────────────────────────────

@test "Intégration : rechargement de load_adapter remplace les fonctions" {
  # Premier chargement
  cat > "$ADAPTERS_DIR/opencode.adapter.sh" <<'EOF'
adapter_validate() { echo "v1"; }
adapter_needs_node() { return 0; }
adapter_deploy_files() { return 0; }
adapter_deploy_config() { return 0; }
adapter_deploy() { return 0; }
adapter_install() { return 0; }
adapter_update() { return 0; }
adapter_start() { return 0; }
EOF

  load_adapter
  run adapter_validate
  [ "$output" = "v1" ]

  # Réécrire et recharger
  cat > "$ADAPTERS_DIR/opencode.adapter.sh" <<'EOF'
adapter_validate() { echo "v2"; }
adapter_needs_node() { return 0; }
adapter_deploy_files() { return 0; }
adapter_deploy_config() { return 0; }
adapter_deploy() { return 0; }
adapter_install() { return 0; }
adapter_update() { return 0; }
adapter_start() { return 0; }
EOF

  load_adapter
  run adapter_validate
  [ "$output" = "v2" ]
}
