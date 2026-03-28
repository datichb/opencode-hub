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
├── LICENSE
├── agents/                            ← Sources canoniques des rôles (éditer ici)
│   ├── planner.md
│   └── developer.md
├── skills/                            ← Blocs de bonnes pratiques réutilisables
│   ├── planner.md
│   └── developer/
│       ├── dev-beads.md
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
│   │   ├── adapter-manager.sh         ← Chargement des adaptateurs
│   │   └── node-installer.sh          ← Installation de Node.js (Volta/brew/nvm)
│   ├── adapters/
│   │   ├── opencode.adapter.sh        ← Génère .opencode/agents/ + config.json
│   │   ├── claude-code.adapter.sh     ← Génère .claude/agents/
│   │   └── vscode.adapter.sh          ← Génère copilot-instructions.md + prompts
│   ├── cmd-agent.sh
│   ├── cmd-beads.sh
│   ├── cmd-deploy.sh
│   ├── cmd-help.sh
│   ├── cmd-install.sh
│   ├── cmd-init.sh
│   ├── cmd-list.sh
│   ├── cmd-remove.sh
│   ├── cmd-skills.sh
│   ├── cmd-start.sh
│   └── cmd-update.sh
└── projects/
    ├── projects.md                    ← Registre des projets (versionné)
    └── paths.local.md                 ← Chemins locaux (ignoré par git)
```

> Les dossiers `.opencode/agents/`, `.claude/`,
> `.vscode/prompts/` et `.github/copilot-instructions.md` sont des
> **sorties générées** — ne jamais les éditer à la main.
> `opencode.json` à la racine d'un projet est créé par `oc deploy opencode`
> s'il n'existe pas encore, puis conservé tel quel.

---

## Installation

### 1. Cloner le hub

```bash
git clone https://github.com/toi/opencode-hub.git ~/opencode-hub
cd ~/opencode-hub
chmod +x oc.sh scripts/*.sh scripts/adapters/*.sh scripts/lib/*.sh
```

### 2. Lancer l'installation

```bash
./oc.sh install
```

Le script est interactif et se déroule en deux étapes :

**Étape 1 — Choisir les cibles**

| Choix | Cibles configurées |
|-------|--------------------|
| 1 (défaut) | OpenCode |
| 2 | Claude Code |
| 3 | VS Code / Copilot |
| 4 | Tout |

**Étape 2 — Node.js (uniquement pour OpenCode et Claude Code)**

Si Node.js n'est pas installé, le script affiche un menu interactif pour
choisir l'installeur. Les options déjà disponibles sur la machine sont
indiquées :

| Option | Condition affichée |
|--------|--------------------|
| Volta | `(recommandé)` ou `(déjà installé, recommandé)` |
| Homebrew | affiché sur macOS, `(déjà installé)` si présent |
| nvm | `(déjà installé)` si présent, sinon lien vers GitHub |

Après le choix, le script propose soit l'**installation automatique**, soit
les **commandes à copier-coller** pour une installation manuelle.

> VS Code / Copilot ne requiert pas Node.js — `oc install` avec la cible `vscode`
> ne vérifie pas Node.

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

### `oc install`
Installe les outils, crée la structure et configure les cibles actives.
Vérifie et installe Node.js si une cible en a besoin.

```bash
oc install
```

> **Important :** Après `oc install`, lancez `oc deploy <target>` pour générer
> les fichiers agents dans chaque projet. Le déploiement n'est **pas automatique**.

---

### `oc deploy <target> [PROJECT_ID]`
Génère les fichiers agents pour la cible spécifiée.
Vérifie que la cible est disponible (`adapter_validate`) avant de déployer.

```bash
oc deploy opencode              # déploie au niveau du hub
oc deploy claude-code MON-APP   # déploie dans un projet
oc deploy vscode MON-APP
oc deploy all                   # toutes les cibles actives
```

| Cible | Sorties générées |
|-------|-----------------|
| `opencode` | `.opencode/agents/*.md` + `opencode.json` (créé seulement s'il n'existe pas) |
| `claude-code` | `.claude/agents/*.md` |
| `vscode` | `.github/copilot-instructions.md` + `.vscode/prompts/*.prompt.md` |

---

### `oc start [PROJECT_ID] [prompt] [--dev]`
Lance l'outil par défaut (défini dans `config/hub.json`) dans le projet.
Vérifie que la cible est disponible avant de lancer.

```bash
oc start             # sélection interactive
oc start MON-APP
oc start MON-APP "explique l'architecture du projet"
oc start MON-APP --dev    # bootstrap : charge les tickets ai-delegated en prompt
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

### `oc update`
Met à jour les outils installés (selon les cibles actives).

```bash
oc update
```

---

### `oc agent <sous-commande>`
Gère les agents canoniques du hub.

```bash
oc agent list                   # lister les agents
oc agent create                 # créer un agent (interactif)
oc agent edit <agent-id>        # modifier skills et métadonnées
oc agent info <agent-id>        # afficher le détail d'un agent
oc agent keytest                # diagnostic clavier (sélecteur de skills)
```

#### `oc agent create` — workflow interactif

La création d'un agent suit ces étapes dans l'ordre :

1. **Identifiant** — slug unique (ex: `reviewer`)
2. **Label** — nom court affiché dans l'outil (ex: `CodeReviewer`)
3. **Description** — phrase courte décrivant le rôle
4. **Cibles** — sélecteur interactif ↑↓/espace : `opencode`, `claude-code`, `vscode`
5. **Skills** — sélecteur interactif ↑↓/espace avec panneau de description
6. **Corps** — si `opencode` est disponible, proposition de génération automatique via `opencode run`
7. **Prévisualisation** — affichage du fichier `.md` complet avant écriture
8. **Confirmation** — `Y/n` pour créer le fichier

> `oc agent keytest` affiche les octets bruts reçus pour chaque touche.
> Utile pour diagnostiquer un terminal où la navigation du sélecteur
> ne fonctionne pas comme attendu. Quitter avec `q`.

---

### `oc skills <sous-commande>`
Gère les skills externes téléchargés via context7.

```bash
oc skills search <query>          # rechercher des skills
oc skills add /owner/repo [name]  # ajouter un skill externe
oc skills list                    # lister tous les skills (locaux + externes)
oc skills update [name]           # mettre à jour un skill externe (ou tous)
oc skills used-by <skill>         # lister les agents qui utilisent ce skill
oc skills sync                    # re-télécharger tous les skills (après clone)
oc skills remove <name>           # supprimer un skill externe
```

---

### `oc beads <sous-commande>`
Gère l'intégration Beads (`bd`) dans les projets enregistrés.
`bd` doit être installé via Homebrew (`brew install bd`).

```bash
oc beads status                   # vérifie Beads sur tous les projets
oc beads status MON-APP           # vérifie Beads sur un projet précis
oc beads init MON-APP             # initialise .beads/ dans le projet
oc beads list MON-APP             # liste les tickets ouverts du projet
oc beads open MON-APP             # affiche le chemin pour utiliser bd manuellement

# Synchronisation avec un tracker externe (Jira / GitLab)
oc beads sync MON-APP             # synchronisation bidirectionnelle
oc beads sync MON-APP --pull-only # importer seulement depuis le tracker
oc beads sync MON-APP --push-only # exporter seulement vers le tracker
oc beads sync MON-APP --dry-run   # simuler sans modifier

# Gestion du tracker du projet
oc beads tracker status MON-APP   # affiche le statut de connexion
oc beads tracker setup  MON-APP   # configure le tracker (interactif)
oc beads tracker switch MON-APP   # change de provider (jira ↔ gitlab ↔ none)
```

Le provider de tracker est stocké dans `projects.md` (champ `Tracker`).
Les credentials sont stockés localement par `bd config set` (non versionnés).

> `oc start` avertit automatiquement si `.beads/` n'est pas présent dans le projet.

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
dans les agents qui les déclarent. Chaque fichier skill a un frontmatter
`name` + `description`.

```
skills/
├── planner.md                         ← Workflow Beads du planner
└── developer/
    ├── dev-beads.md                   ← Commandes bd et workflow tickets
    ├── dev-standards-universal.md     ← Clean Code, SOLID complet, TypeScript strict
    ├── dev-standards-backend.md       ← Architecture en couches, DTOs, sécurité
    ├── dev-standards-frontend.md      ← Séparation logique/présentation, performance
    ├── dev-standards-frontend-a11y.md ← WCAG 2.1 A/AA, sémantique HTML, ARIA
    └── dev-standards-vuejs.md         ← Composition API, Pinia, composables
```

**Pour ajouter un skill :**
1. Créer `skills/mon-skill.md` avec un frontmatter `name` + `description`
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
- Tracker : jira
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

Dans **opencode-hub** (ce dépôt) :

| Versionné ✅ | Généré (ignoré git) ❌ |
|-------------|----------------------|
| `agents/` | `.opencode/agents/` |
| `skills/` | `skills/external/` |
| `config/hub.json` | `projects/paths.local.md` |
| `scripts/` | |
| `projects/projects.md` | |

Dans les **dépôts projets cibles** (générés par `oc deploy`) :

| Cible | Fichiers générés | À committer dans le projet ? |
|-------|-----------------|------------------------------|
| `opencode` | `.opencode/agents/` + `opencode.json` | Non (`.opencode/agents/` ignoré, `opencode.json` oui) |
| `claude-code` | `.claude/agents/` | Non |
| `vscode` | `.github/copilot-instructions.md` + `.vscode/prompts/` | **Oui** — ces fichiers doivent être committés dans le projet cible |

---

## Contribuer

Les agents, skills et config sont versionnés et partagés par toute l'équipe.
Pour modifier un agent ou ajouter un skill, soumettre une PR puis relancer
`oc deploy <target>` localement après merge.

---

## Notes techniques

- **`oc init`** rejette les `PROJECT_ID` contenant des espaces, slashes ou caractères spéciaux.
  Caractères autorisés : lettres, chiffres, `-` et `_`.
- **`oc start`** avertit si les agents ne sont pas encore déployés dans le projet cible,
  et si `.beads/` n'est pas initialisé dans le projet.
- **`oc skills sync`** est non-interactif : il écrase silencieusement les fichiers existants
  (`--force` interne). La commande `oc skills add` elle, demande toujours confirmation en mode normal.
- **`_generate_body`** dans `oc agent create` détecte automatiquement `timeout` ou `gtimeout`
  (macOS) pour encadrer l'appel à `opencode run`.
- **`oc remove`** : le `PROJECT_ID` est échappé dans la regex Perl (`\Q...\E`) pour éviter
  toute interprétation de caractères spéciaux.
