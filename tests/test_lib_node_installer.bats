#!/usr/bin/env bats
# Tests unitaires pour scripts/lib/node-installer.sh
# Fonctions testées : ensure_node, _choose_installer, installers, helpers

bats_require_minimum_version 1.5.0

load helpers

setup() {
  common_setup
  
  # Sourcer common.sh
  export SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  export LIB_DIR="$SCRIPT_DIR/lib"
  source "$SCRIPT_DIR/common.sh"
  
  # Empêcher le sourcing de nvm.sh réel (peut générer des Mio de sortie dans bats)
  export NVM_DIR="$TEST_DIR/no-nvm"
  
  # Sourcer le module
  source "$BATS_TEST_DIRNAME/../scripts/lib/node-installer.sh"
  
  # Mock log functions
  mock_log_functions
}

teardown() {
  common_teardown
}

# ── Helpers ─────────────────────────────────────────────────────────────────

@test "_get_latest_nvm_version : retourne version format vX.X.X" {
  # Mock curl qui retourne une release GitHub
  curl() {
    echo '{"tag_name":"v0.40.1"}'
  }
  export -f curl
  
  run _get_latest_nvm_version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "_get_latest_nvm_version : retourne fallback si curl échoue" {
  # Mock curl qui échoue
  curl() {
    return 1
  }
  export -f curl
  
  run _get_latest_nvm_version
  [ "$status" -eq 0 ]
  [ "$output" = "v0.40.3" ]
}

@test "_print_manual_instructions : affiche instructions volta" {
  # log_info doit imprimer pour que $output soit testable
  log_info() { echo "$@"; }
  export -f log_info
  run _print_manual_instructions "volta"
  [ "$status" -eq 0 ]
  [[ "$output" == *"volta.sh"* ]]
}

@test "_print_manual_instructions : affiche instructions brew" {
  log_info() { echo "$@"; }
  export -f log_info
  run _print_manual_instructions "brew"
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew install node"* ]]
}

@test "_print_manual_instructions : affiche instructions nvm" {
  log_info() { echo "$@"; }
  export -f log_info
  run _print_manual_instructions "nvm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvm-sh/nvm"* ]]
}

@test "_print_manual_instructions : affiche instructions génériques si méthode inconnue" {
  log_info() { echo "$@"; }
  export -f log_info
  run _print_manual_instructions "unknown"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nodejs.org"* ]]
}

# ── Installers ──────────────────────────────────────────────────────────────

@test "_install_with_volta : installe volta puis node" {
  # Mock curl pour volta install
  curl() {
    echo "echo 'Volta installed'"
  }
  export -f curl
  
  # Mock bash
  bash() {
    return 0
  }
  export -f bash
  
  # Mock volta command
  volta() {
    echo "Installing node..."
    return 0
  }
  export -f volta
  
  # Mock command pour dire que volta existe
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "volta" ]; then
      return 0
    fi
    builtin command "$@"
  }
  export -f command
  
  run _install_with_volta
  [ "$status" -eq 0 ]
}

@test "_install_with_brew : installe node via brew" {
  # Mock brew
  brew() {
    echo "Installing node..."
    return 0
  }
  export -f brew
  
  run _install_with_brew
  [ "$status" -eq 0 ]
}

@test "_install_with_nvm : installe nvm puis node" {
  # Mock curl
  curl() {
    echo "echo 'nvm installed'"
  }
  export -f curl
  
  # Mock bash
  bash() {
    return 0
  }
  export -f bash
  
  # Pointer HOME vers TEST_DIR pour que le code de production fasse
  # export NVM_DIR="$HOME/.nvm" = "$TEST_DIR/.nvm" (là où le faux nvm.sh est créé)
  export HOME="$TEST_DIR"
  export NVM_DIR="$TEST_DIR/.nvm"
  mkdir -p "$NVM_DIR"
  cat > "$NVM_DIR/nvm.sh" <<'EOF'
nvm() {
  echo "Installing node LTS..."
  return 0
}
EOF
  
  # Mock command
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "nvm" ]; then
      return 0
    fi
    builtin command "$@"
  }
  export -f command
  
  run _install_with_nvm
  [ "$status" -eq 0 ]
}

# ── _verify_node_in_path ────────────────────────────────────────────────────

@test "_verify_node_in_path : retourne 0 si node disponible" {
  # Mock node command
  node() {
    echo "v20.0.0"
  }
  export -f node
  
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "node" ]; then
      return 0
    fi
    builtin command "$@"
  }
  export -f command
  
  run _verify_node_in_path
  [ "$status" -eq 0 ]
}

@test "_verify_node_in_path : retourne 1 si node absent" {
  # Mock command qui dit que node n'existe pas
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "node" ]; then
      return 1
    fi
    builtin command "$@"
  }
  export -f command
  
  run _verify_node_in_path
  [ "$status" -ne 0 ]
}

# ── _choose_installer ───────────────────────────────────────────────────────

@test "_choose_installer : retourne volta par défaut" {
  # Pas de mock command : volta/nvm ne sont pas dans PATH en test de toute façon.
  # --separate-stderr évite que les menus (>&2) ne polluent $output.
  run --separate-stderr _choose_installer "linux"
  [ "$status" -eq 0 ]
  [ "$output" = "volta" ]
}

@test "_choose_installer : inclut brew sur macOS" {
  # Même approche : séparation stderr/stdout.
  # Sur macOS, brew est présent en PATH, donc il sera détecté comme "déjà installé".
  # Le choix par défaut (1 = volta) doit être retourné.
  run --separate-stderr _choose_installer "macos"
  [ "$status" -eq 0 ]
  # Sur macOS avec brew, les options sont: volta, brew, nvm
  # Le défaut devrait être volta
  [ "$output" = "volta" ]
  
}

# ── ensure_node ─────────────────────────────────────────────────────────────

@test "ensure_node : retourne 0 si node déjà installé" {
  # Mock node
  node() {
    echo "v20.0.0"
  }
  export -f node
  
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "node" ]; then
      return 0
    fi
    builtin command "$@"
  }
  export -f command
  
  run ensure_node
  [ "$status" -eq 0 ]
}

@test "ensure_node : déclenche installation si node absent" {
  # Mock command pour dire que node n'existe pas
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "node" ]; then
      return 1
    fi
    builtin command "$@"
  }
  export -f command
  
  # Mock _detect_and_install_node
  _detect_and_install_node() {
    echo "Installing node..."
    return 0
  }
  export -f _detect_and_install_node
  
  run ensure_node
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing node"* ]]
}

# ── _install_node_with ──────────────────────────────────────────────────────

@test "_install_node_with : skip si utilisateur refuse" {
  # Simuler réponse 'n' via _prompt (remplace read — _install_node_with utilise _prompt)
  _prompt() { printf -v "$1" '%s' 'n'; }
  export -f _prompt
  
  run _install_node_with "volta"
  [ "$status" -ne 0 ]
}

@test "_install_node_with : installe si utilisateur accepte" {
  # Simuler réponse 'Y' via _prompt
  _prompt() { printf -v "$1" '%s' 'Y'; }
  export -f _prompt
  
  # Mock _install_with_volta
  _install_with_volta() {
    return 0
  }
  export -f _install_with_volta
  
  # Mock _verify_node_in_path
  _verify_node_in_path() {
    return 0
  }
  export -f _verify_node_in_path
  
  run _install_node_with "volta"
  [ "$status" -eq 0 ]
}

@test "_install_node_with : gère erreur installation" {
  # Simuler réponse 'Y' via _prompt
  _prompt() { printf -v "$1" '%s' 'Y'; }
  export -f _prompt
  
  # Mock installation qui échoue
  _install_with_brew() {
    return 1
  }
  export -f _install_with_brew
  
  run _install_node_with "brew"
  [ "$status" -ne 0 ]
}

# ── Intégration ─────────────────────────────────────────────────────────────

@test "Intégration : workflow volta complet" {
  # Mock tous les composants
  curl() {
    if [[ "$*" == *"volta.sh"* ]]; then
      echo "echo 'Volta installed'"
    elif [[ "$*" == *"github.com"* ]]; then
      echo '{"tag_name":"v0.40.1"}'
    fi
  }
  export -f curl
  
  bash() {
    return 0
  }
  export -f bash
  
  volta() {
    return 0
  }
  export -f volta
  
  node() {
    echo "v20.0.0"
  }
  export -f node
  
  command() {
    if [ "$2" = "volta" ] || [ "$2" = "node" ]; then
      return 0
    fi
    builtin command "$@"
  }
  export -f command
  
  # Installer
  run _install_with_volta
  [ "$status" -eq 0 ]
  
  # Vérifier
  run _verify_node_in_path
  [ "$status" -eq 0 ]
}

@test "Intégration : ensure_node avec node déjà présent" {
  node() {
    echo "v18.17.0"
  }
  export -f node
  
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "node" ]; then
      return 0
    fi
    builtin command "$@"
  }
  export -f command
  
  # log_success doit imprimer pour que $output soit testable (mock_log_functions le silençait)
  log_success() { echo "$@"; }
  export -f log_success
  
  run ensure_node
  [ "$status" -eq 0 ]
  [[ "$output" == *"détecté"* ]]
}
