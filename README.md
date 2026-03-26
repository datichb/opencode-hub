# opencode-hub 🧠

Un hub central pour piloter des assistants IA sur plusieurs projets,
avec des agents partagés, des skills injectables et un workflow Beads intégré.

Supporte **OpenCode**, **Claude Code** et **VS Code / Copilot**.

---

## Pourquoi opencode-hub ?

Les outils IA (OpenCode, Claude Code, VS Code Copilot) fonctionnent en silo.
**opencode-hub** centralise tout :

- ✅ Agents et rôles définis **une seule fois**, déployés partout
- ✅ Skills (bonnes pratiques, conventions) **injectés automatiquement**
- ✅ Projets enregistrés et lancés via **une commande unique**
- ✅ Workflow Beads intégré pour la **gestion des tâches**
- ✅ Cible configurable : **OpenCode**, **Claude Code**, **VS Code**

---

## Structure

```
opencode-hub/
├── oc.sh                              ← Point d'entrée principal
├── agents/                            ← Sources canoniques des rôles (éditer ici)
│   ├── planner.md
│   └── developer.md
├── skills/                            ← Blocs de bonnes pratiques réutilisables
│   ├── planner.md
│   └── developer/
│       ├── dev-standards-universal.md
│       ├── dev-standards-backend.md
│       ├── dev-standards-frontend.md
│       ├── dev-standards-frontend-a11y.md
│       └── dev-standards-vuejs.md
├── config/
│   └── hub.json                       ← Cible par défaut et cibles actives
├── scripts/
│   ├── common.sh                      ← Variables et helpers partagés
│   ├── lib/
│   │   ├── prompt-builder.sh          ← Assemblage agent + skills
│   │   └── adapter-manager.sh         ← Chargement des adaptateurs
│   ├── adapters/
│   │   ├── opencode.adapter.sh        ← Génère .opencode/agents/ + config.json
│   │   ├── claude-code.adapter.sh     ← Génère .claude/agents/
│   │   └── vscode.adapter.sh          ← Génère copilot-instructions.md + prompts
│   ├── cmd-deploy.sh                  ← oc deploy
│   ├── cmd-install.sh
│   ├── cmd-init.sh
│   ├── cmd-list.sh
│   ├── cmd-remove.sh
│   ├── cmd-start.sh
│   ├── cmd-sync.sh
│   └── cmd-update.sh
└── projects/
    ├── projects.md                    ← Registre des projets (versionné)
    └── paths.local.md                 ← Chemins locaux (ignoré par git)
```

> Les dossiers `.opencode/agents/`, `.claude/`, `.vscode/prompts/` et
> `.github/copilot-instructions.md` sont des **sorties générées** — ne jamais
> les éditer à la main.

---

## Installation

### 1. Cloner le hub

```bash
git clone https://github.com/toi/opencode-hub.git ~/opencode-hub
cd ~/opencode-hub
chmod +x oc.sh scripts/*.sh scripts/adapters/*.sh scripts/lib/*.sh
```

### 2. Installer les dépendances

```bash
./oc.sh install
```

Interactif : choisir la ou les cibles à configurer.

| Choix | Cibles installées |
|-------|-------------------|
| 1 (défaut) | OpenCode |
| 2 | Claude Code |
| 3 | VS Code / Copilot |
| 4 | Tout |

### 3. Alias recommandé

```bash
# Dans ~/.zshrc ou ~/.bashrc
alias oc="~/opencode-hub/oc.sh"
source ~/.zshrc
```

---

## Workflow typique

```bash
# 1. Installer le hub et choisir les cibles
oc install

# 2. Enregistrer un projet
oc init MON-APP ~/workspace/mon-app

# 3. Déployer les agents dans le projet
oc deploy opencode MON-APP
oc deploy claude-code MON-APP   # si activé
oc deploy vscode MON-APP        # si activé

# 4. Lancer l'outil par défaut dans le projet
oc start MON-APP
```

---

## Commandes

### `oc install [target]`
Installe les outils, crée la structure et configure les cibles actives.

```bash
oc install
```

---

### `oc deploy <target> [PROJECT_ID]`
Génère les fichiers agents pour la cible spécifiée.

```bash
oc deploy opencode              # déploie au niveau du hub
oc deploy claude-code MON-APP   # déploie dans un projet
oc deploy vscode MON-APP
oc deploy all                   # toutes les cibles actives
```

| Cible | Sorties générées |
|-------|-----------------|
| `opencode` | `.opencode/agents/*.md` + `.opencode/config.json` |
| `claude-code` | `.claude/agents/*.md` |
| `vscode` | `.github/copilot-instructions.md` + `.vscode/prompts/*.prompt.md` |

---

### `oc start [PROJECT_ID]`
Lance l'outil par défaut (défini dans `config/hub.json`) dans le projet.

```bash
oc start             # sélection interactive
oc start MON-APP
```

---

### `oc init [PROJECT_ID] [chemin]`
Enregistre un projet dans le hub.

```bash
oc init              # mode interactif
oc init MON-APP ~/workspace/mon-app
```

---

### `oc list`
Liste les projets enregistrés avec leur statut d'accessibilité.

```bash
oc list
```

---

### `oc remove <PROJECT_ID>`
Supprime un projet du registre (avec confirmation).

```bash
oc remove MON-APP
```

---

### `oc sync`
Injection legacy des skills dans `.opencode/agents/` via marqueurs HTML.
Préférer `oc deploy opencode` pour le nouveau flux.

```bash
oc sync
```

---

### `oc update`
Met à jour les outils installés (selon les cibles actives).

```bash
oc update
```

---

## Agents canoniques

Les agents sont définis dans `agents/` avec un frontmatter déclarant
leurs métadonnées, leurs cibles et leurs skills.

```markdown
---
id: developer
label: Developer
description: Assistant de développement...
targets: [opencode, claude-code, vscode]
skills: [developer/dev-standards-universal, developer/dev-standards-backend]
---

# 👨‍💻 Developer

Tu es un assistant de développement...
```

| Champ | Rôle |
|-------|------|
| `id` | Identifiant unique du rôle |
| `label` | Nom affiché dans l'outil cible |
| `description` | Description courte |
| `targets` | Cibles supportées : `opencode`, `claude-code`, `vscode` |
| `skills` | Skills à injecter (chemins relatifs à `skills/`) |

**Pour modifier un agent :** éditer `agents/<id>.md`, puis `oc deploy <target>`.

---

## Skills

Les skills sont des blocs Markdown dans `skills/` injectés automatiquement
dans les agents qui les déclarent.

```
skills/
├── planner.md                      ← Workflow Beads du planner
└── developer/
    ├── dev-standards-universal.md  ← Qualité, SOLID, TypeScript strict
    ├── dev-standards-backend.md    ← Architecture en couches, DTOs
    ├── dev-standards-frontend.md   ← Séparation logique/présentation
    ├── dev-standards-frontend-a11y.md ← WCAG 2.1, sémantique HTML
    └── dev-standards-vuejs.md      ← Composition API, Pinia, composables
```

**Pour ajouter un skill :**
1. Créer `skills/mon-skill.md`
2. L'ajouter dans le frontmatter de l'agent : `skills: [..., mon-skill]`
3. Relancer `oc deploy <target>`

---

## Configuration hub

`config/hub.json` contrôle le comportement global :

```json
{
  "version": "2.0.0",
  "default_target": "opencode",
  "active_targets": ["opencode"]
}
```

| Clé | Rôle |
|-----|------|
| `default_target` | Cible utilisée par `oc start` |
| `active_targets` | Cibles déployées par `oc deploy all` et mises à jour par `oc update` |

---

## Projets

### `projects/projects.md` — versionné

```markdown
## MON-APP
- Nom : Mon Application
- Stack : Vue 3 + Laravel
- Board Beads : MON-APP
- Labels : feature, fix, front, back
```

### `projects/paths.local.md` — ignoré par git

```
MON-APP=~/workspace/mon-app
AUTRE-APP=/home/user/projets/autre-app
```

> Chaque développeur maintient son propre `paths.local.md`.

---

## Ce qui est versionné / généré

| Versionné ✅ | Généré (ignoré git) ❌ |
|-------------|----------------------|
| `agents/` | `.opencode/agents/` |
| `skills/` | `.claude/agents/` |
| `config/hub.json` | `.vscode/prompts/` |
| `scripts/` | `.github/copilot-instructions.md` |
| `projects/projects.md` | `projects/paths.local.md` |

---

## Contribuer

Les agents, skills et config sont versionnés et partagés par toute l'équipe.
Pour modifier un agent ou ajouter un skill, soumettre une PR puis relancer
`oc deploy <target>` localement après merge.
