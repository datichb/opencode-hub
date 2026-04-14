#!/bin/bash
# Tests pour la commande oc provider
# Usage: bash tests/cmd-provider.test.sh

set -euo pipefail

HUB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$HUB_DIR/scripts"

# ── Sandbox isolée ───────────────────────────────────────────────────────────
# Tous les fichiers locaux (projects.md, paths.local.md, api-keys.local.md)
# sont redirigés vers un répertoire temporaire supprimé en fin de test,
# même en cas d'échec ou d'interruption.

TEST_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT INT TERM

# Surcharger les chemins AVANT de sourcer common.sh
export PROJECTS_FILE="$TEST_DIR/projects.md"
export PATHS_FILE="$TEST_DIR/paths.local.md"
export API_KEYS_FILE="$TEST_DIR/api-keys.local.md"

# Fournir un projects.md minimal pour les fonctions qui en ont besoin
cat > "$PROJECTS_FILE" <<'PROJEOF'
# Registre de test
PROJEOF

touch "$PATHS_FILE"

source "$SCRIPTS_DIR/common.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to assert
assert_equal() {
  local expected="$1"
  local actual="$2"
  local test_name="${3:-}"
  TESTS_RUN=$((TESTS_RUN + 1))
  
  if [ "$expected" = "$actual" ]; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: $test_name"
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local test_name="${3:-}"
  TESTS_RUN=$((TESTS_RUN + 1))
  
  if [[ "$haystack" == *"$needle"* ]]; then
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: $test_name"
    echo "  Expected to contain: $needle"
    echo "  In: $haystack"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test: provider_exists function
test_provider_exists() {
  echo ""
  echo "=== Testing provider_exists() ==="
  
  # This function is defined in common.sh
  assert_equal "0" "$(provider_exists "anthropic" && echo 0 || echo 1)" "anthropic provider exists"
  assert_equal "0" "$(provider_exists "mammouth" && echo 0 || echo 1)" "mammouth provider exists"
  assert_equal "0" "$(provider_exists "github-models" && echo 0 || echo 1)" "github-models provider exists"
  assert_equal "0" "$(provider_exists "bedrock" && echo 0 || echo 1)" "bedrock provider exists"
  assert_equal "0" "$(provider_exists "ollama" && echo 0 || echo 1)" "ollama provider exists"
  assert_equal "1" "$(provider_exists "invalid-provider" && echo 0 || echo 1)" "invalid provider doesn't exist"
}

# Test: get_provider_info function
test_get_provider_info() {
  echo ""
  echo "=== Testing get_provider_info() ==="
  
  local anthropic_name
  anthropic_name=$(get_provider_info "anthropic" "label")
  [ -n "$anthropic_name" ] && assert_contains "$anthropic_name" "Anthropic" "anthropic provider info has label"
  
  local mammouth_name
  mammouth_name=$(get_provider_info "mammouth" "label")
  [ -n "$mammouth_name" ] && assert_contains "$mammouth_name" "MammouthAI" "mammouth provider info has label"
}

# Test: list_all_providers function
test_list_all_providers() {
  echo ""
  echo "=== Testing list_all_providers() ==="
  
  local providers
  providers=$(list_all_providers)
  assert_contains "$providers" "anthropic" "list contains anthropic"
  assert_contains "$providers" "mammouth" "list contains mammouth"
  assert_contains "$providers" "github-models" "list contains github-models"
  assert_contains "$providers" "bedrock" "list contains bedrock"
  assert_contains "$providers" "ollama" "list contains ollama"
}

# Test: Hub default provider functions
test_hub_default_functions() {
  echo ""
  echo "=== Testing hub default provider functions ==="
  
  # These functions read from hub.json
  local hub_provider
  hub_provider=$(get_hub_default_provider)
  # Should be a known provider (anthropic, bedrock, etc.) or empty
  if [ -n "$hub_provider" ]; then
    assert_equal "0" "$(provider_exists "$hub_provider" && echo 0 || echo 1)" "hub default provider is a valid known provider"
  else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} PASS: hub default provider is empty (not configured)"
  fi
}

# Test: Provider model resolution
test_get_effective_llm_model() {
  echo ""
  echo "=== Testing get_effective_llm_model() ==="
  
  # Test 1: No project config → should use hub or default
  # Utilise un ID qui n'existe pas dans api-keys.local.md (sandbox vide)
  local model
  model=$(get_effective_llm_model "TEST-PROVIDER-NOCONFIG")
  assert_equal "claude-sonnet-4-5" "$model" "default model returned when no project config"
}

# Test: Provider command help
test_provider_command_help() {
  echo ""
  echo "=== Testing provider command help ==="
  
  # Run the provider command without args to see the default list output
  local help_output
  help_output=$(bash "$SCRIPTS_DIR/cmd-provider.sh" 2>&1 || true)
  assert_contains "$help_output" "Fournisseurs LLM" "provider command shows providers list"
  assert_contains "$help_output" "Anthropic" "provider command shows Anthropic"
}

# Test: Provider list subcommand
test_provider_list() {
  echo ""
  echo "=== Testing provider list ==="
  
  local list_output
  list_output=$(bash "$SCRIPTS_DIR/cmd-provider.sh" list 2>&1)
  assert_contains "$list_output" "Anthropic" "list shows Anthropic"
  assert_contains "$list_output" "MammouthAI" "list shows MammouthAI"
  assert_contains "$list_output" "GitHub" "list shows GitHub Models"
  assert_contains "$list_output" "Bedrock" "list shows Bedrock"
  assert_contains "$list_output" "Ollama" "list shows Ollama"
}

# Test: Provider get subcommand with no config
test_provider_get_unconfigured() {
  echo ""
  echo "=== Testing provider get (unconfigured) ==="
  
  local get_output
  get_output=$(bash "$SCRIPTS_DIR/cmd-provider.sh" get "NONEXISTENT-PROJECT" 2>&1 || true)
  # Should indicate no configuration
  assert_contains "$get_output" "NONEXISTENT-PROJECT" "get shows project ID"
}

# Test: Config command accepts new providers
test_config_accepts_providers() {
  echo ""
  echo "=== Testing config command accepts new providers ==="
  
  # Verify the provider validation has been updated
  local config_script
  config_script=$(cat "$SCRIPTS_DIR/cmd-config.sh")
  assert_contains "$config_script" "mammouth" "config script includes mammouth provider"
  assert_contains "$config_script" "github-models" "config script includes github-models provider"
  assert_contains "$config_script" "bedrock" "config script includes bedrock provider"
  assert_contains "$config_script" "ollama" "config script includes ollama provider"
}

# Test: Adapters have provider support
test_adapters_have_provider_support() {
  echo ""
  echo "=== Testing adapters have provider support ==="
  
  # Check opencode adapter
  local opencode_adapter
  opencode_adapter=$(cat "$SCRIPTS_DIR/adapters/opencode.adapter.sh")
  assert_contains "$opencode_adapter" "mammouth" "opencode adapter has mammouth support"
  assert_contains "$opencode_adapter" "github-models" "opencode adapter has github-models support"
  assert_contains "$opencode_adapter" "bedrock" "opencode adapter has bedrock support"
  assert_contains "$opencode_adapter" "ollama" "opencode adapter has ollama support"
  # Bedrock doit utiliser le provider natif amazon-bedrock (pas litellm)
  assert_contains "$opencode_adapter" "amazon-bedrock" "opencode adapter uses native amazon-bedrock provider for bedrock"
  assert_contains "$opencode_adapter" "AWS_BEARER_TOKEN_BEDROCK" "opencode adapter injects AWS_BEARER_TOKEN_BEDROCK at start"
  
  # Check claude-code adapter
  local claude_code_adapter
  claude_code_adapter=$(cat "$SCRIPTS_DIR/adapters/claude-code.adapter.sh")
  assert_contains "$claude_code_adapter" "get_hub_default_provider" "claude-code adapter checks hub default provider"
  assert_contains "$claude_code_adapter" "warn" "claude-code adapter warns about non-anthropic providers"
}

# Test: Bedrock native provider génère le bon opencode.json
test_bedrock_native_opencode_json() {
  echo ""
  echo "=== Testing bedrock native opencode.json generation ==="

  local opencode_adapter
  opencode_adapter=$(cat "$SCRIPTS_DIR/adapters/opencode.adapter.sh")

  # Le bloc bedrock ne doit PAS contenir litellm ni apiKey inline pour bedrock
  # On vérifie que le case bedrock pointe vers amazon-bedrock
  assert_contains "$opencode_adapter" '"amazon-bedrock"' "bedrock case generates amazon-bedrock provider block"

  # Le providers.json doit avoir requires_base_url: false pour bedrock (pas de litellm)
  local providers_json
  providers_json=$(cat "$HUB_DIR/config/providers.json")
  # Le default_model bedrock doit utiliser le format amazon-bedrock/...
  assert_contains "$providers_json" "amazon-bedrock/" "bedrock default_model uses amazon-bedrock/ prefix"
  # litellm doit être false pour bedrock
  local bedrock_litellm
  bedrock_litellm=$(jq -r '.providers.bedrock.litellm' "$HUB_DIR/config/providers.json" 2>/dev/null || echo "")
  assert_equal "false" "$bedrock_litellm" "bedrock.litellm is false (uses native provider)"
}

# Test: cmd_set_default déclenche la mise à jour de opencode.json
test_set_default_syncs_opencode_json() {
  echo ""
  echo "=== Testing cmd_set_default auto-syncs opencode.json ==="

  local cmd_provider_script
  cmd_provider_script=$(cat "$SCRIPTS_DIR/cmd-provider.sh")
  # La commande set-default doit appeler adapter_deploy après la sauvegarde
  assert_contains "$cmd_provider_script" "adapter_deploy" "cmd_set_default calls adapter_deploy for sync"
  assert_contains "$cmd_provider_script" "adapter-manager.sh" "cmd_set_default sources adapter-manager"
}

# Test: Hub.json has default_provider structure
test_hub_json_structure() {
  echo ""
  echo "=== Testing hub.json structure ==="
  
  local hub_json
  hub_json=$(cat "$HUB_DIR/config/hub.json")
  assert_contains "$hub_json" "default_provider" "hub.json contains default_provider"
  assert_contains "$hub_json" "\"name\"" "hub.json default_provider has name field"
  assert_contains "$hub_json" "\"api_key\"" "hub.json default_provider has api_key field"
  assert_contains "$hub_json" "\"base_url\"" "hub.json default_provider has base_url field"
}

# Test: Providers catalog exists
test_providers_catalog() {
  echo ""
  echo "=== Testing providers catalog ==="
  
  if [ -f "$HUB_DIR/config/providers.json" ]; then
    local providers_json
    providers_json=$(cat "$HUB_DIR/config/providers.json")
    assert_contains "$providers_json" "anthropic" "catalog contains anthropic"
    assert_contains "$providers_json" "mammouth" "catalog contains mammouth"
    assert_contains "$providers_json" "github-models" "catalog contains github-models"
    assert_contains "$providers_json" "bedrock" "catalog contains bedrock"
    assert_contains "$providers_json" "ollama" "catalog contains ollama"
  else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} FAIL: providers.json exists"
    echo "  File not found: $HUB_DIR/config/providers.json"
  fi
}

# Run all tests
echo "=========================================="
echo "Provider Feature Tests"
echo "=========================================="

test_provider_exists
test_get_provider_info
test_list_all_providers
test_hub_default_functions
test_get_effective_llm_model
test_provider_command_help
test_provider_list
test_provider_get_unconfigured
test_config_accepts_providers
test_adapters_have_provider_support
test_bedrock_native_opencode_json
test_set_default_syncs_opencode_json
test_hub_json_structure
test_providers_catalog

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total:  $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo "=========================================="

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
fi

exit 0
