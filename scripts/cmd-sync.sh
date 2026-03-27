#!/bin/bash
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

log_warn "⚠  La commande 'sync' est dépréciée et n'a plus d'effet."
echo ""
log_info "Les skills sont désormais assemblés à la génération via 'oc deploy'."
log_info "Utilise : ./oc.sh deploy [target] [PROJECT_ID]"
echo ""
exit 0
