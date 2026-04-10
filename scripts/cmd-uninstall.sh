#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

exec bash "$HUB_DIR/uninstall.sh"
