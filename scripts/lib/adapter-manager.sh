#!/bin/bash
# Charge et expose les adaptateurs par cible (opencode)

# Charge l'adaptateur d'une cible et expose ses fonctions
load_adapter() {
  local target="$1"
  local adapter_file="$ADAPTERS_DIR/${target}.adapter.sh"

  if [ ! -f "$adapter_file" ]; then
    log_error "Adaptateur inconnu : $target"
    log_info "Cibles disponibles : opencode"
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
      log_error "Contrat adapter invalide : ${target}.adapter.sh ne définit pas ${fn}()"
      exit 1
    fi
  done
}

# Retourne la cible par défaut — toujours "opencode"
get_default_target() {
  echo "opencode"
}

# Retourne les cibles actives — toujours "opencode"
get_active_targets() {
  echo "opencode"
}
