# opencode-hub

Hub centralisé pour gérer tous vos projets avec OpenCode + Beads.

## Installation

\`\`\`bash
cd ~/workspace
git clone <votre-repo> opencode-hub
cd opencode-hub
chmod +x oc.sh
\`\`\`

## Ajouter un projet

**1. Enregistrer dans le registre** (`projects/projects.md`) :
\`\`\`markdown
## MON-APP
- Nom : Mon Application
- Stack : Vue 3 + Laravel
- Board Beads : MON-APP
- Labels : feature, fix, front, back
\`\`\`

**2. Ajouter le chemin local** (`projects/paths.local.md`) :
\`\`\`
MON-APP=~/workspace/mon-app
\`\`\`

## Utilisation

\`\`\`bash
# Lancer OpenCode sur un projet
./oc.sh MON-APP

# Avec un prompt direct
./oc.sh MON-APP "planifie la feature de login"
\`\`\`

## Agents disponibles

| Agent | Rôle |
|-------|------|
| `planner` | Planification et création de tickets Beads |
| `developer` | Implémentation des tickets |

## Structure

\`\`\`
opencode-hub/
├── .opencode/         → config OpenCode + agents
├── skills/            → instructions métier partagées
├── projects/          → registre des projets
├── oc.sh              → script de lancement
└── README.md
\`\`\`
