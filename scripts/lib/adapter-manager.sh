#!/bin/bash
# Charge et expose l'adaptateur opencode

# Charge l'adaptateur opencode et expose ses fonctions
load_adapter() {
  local adapter_file="$ADAPTERS_DIR/opencode.adapter.sh"

  if [ ! -f "$adapter_file" ]; then
    log_error "Adaptateur opencode introuvable : $adapter_file"
    exit 1
  fi

  # shellcheck source=/dev/null
  source "$adapter_file"

  # Vérifier que les 8 fonctions du contrat adapter sont définies
  local required_fns=(
    adapter_validate
    adapter_needs_node
    adapter_deploy_files
    adapter_deploy_config
    adapter_deploy
    adapter_install
    adapter_update
    adapter_start
  )
  local fn
  for fn in "${required_fns[@]}"; do
    if ! declare -F "$fn" &>/dev/null; then
      log_error "Contrat adapter invalide : opencode.adapter.sh ne définit pas ${fn}()"
      exit 1
    fi
  done
}
