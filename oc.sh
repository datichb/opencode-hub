#!/bin/bash

# opencode-hub launcher
HUB_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECTS_FILE="$HUB_DIR/projects/projects.md"
PATHS_FILE="$HUB_DIR/projects/paths.local.md"

# Aide
usage() {
  echo "Usage: oc.sh <PROJECT_ID> [prompt]"
  echo ""
  echo "Projets disponibles :"
  grep "^## " "$PROJECTS_FILE" | sed 's/^## /  - /'
  exit 1
}

[ -z "$1" ] && usage

PROJECT_ID="$1"
PROMPT="${2:-}"

# Lire le chemin local
PROJECT_PATH=$(grep "^$PROJECT_ID=" "$PATHS_FILE" 2>/dev/null | cut -d'=' -f2)

if [ -z "$PROJECT_PATH" ]; then
  echo "❌ Projet '$PROJECT_ID' non trouvé dans paths.local.md"
  exit 1
fi

# Vérifier que le dossier existe
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"
if [ ! -d "$PROJECT_PATH" ]; then
  echo "❌ Dossier introuvable : $PROJECT_PATH"
  exit 1
fi

# Vérifier / créer le board Beads
bd board "$PROJECT_ID" > /dev/null 2>&1 || {
  echo "📋 Création du board Beads : $PROJECT_ID"
  bd board --create "$PROJECT_ID"
}

# Lancer OpenCode depuis le projet avec la config du hub
echo "🚀 Lancement OpenCode pour $PROJECT_ID"
cd "$PROJECT_PATH" && opencode --config "$HUB_DIR/.opencode" ${PROMPT:+--message "$PROMPT"}
