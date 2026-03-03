# opencode-hub 🧠

Un hub central pour piloter [OpenCode](https://opencode.ai) sur plusieurs projets,
avec des agents IA partagés, des skills injectables et un workflow Beads intégré.

---

## Pourquoi opencode-hub ?

OpenCode se lance dans un dossier projet et ne partage rien entre projets.
**opencode-hub** résout ça :

- ✅ Agents et règles définis **une seule fois**, utilisés partout
- ✅ Skills (bonnes pratiques, conventions) **injectés automatiquement**
- ✅ Projets enregistrés et lancés via **une commande unique**
- ✅ Workflow Beads intégré pour la **gestion des tâches**

---

## Structure

```
opencode-hub/
├── oc.sh                        ← Point d'entrée principal
├── scripts/                     ← Une commande = un fichier
│   ├── common.sh                ← Variables et helpers partagés
│   ├── cmd-help.sh
│   ├── cmd-install.sh
│   ├── cmd-init.sh
│   ├── cmd-list.sh
│   ├── cmd-remove.sh
│   ├── cmd-start.sh
│   ├── cmd-sync.sh
│   └── cmd-update.sh
├── .opencode/
│   ├── config.json              ← Config globale OpenCode
│   └── agents/                  ← Agents IA partagés
│       ├── dev.md
│       ├── reviewer.md
│       └── ...
├── skills/                      ← Blocs de bonnes pratiques
│   ├── git-flow.md
│   ├── vue3.md
│   └── ...
└── projects/
    ├── projects.md              ← Registre des projets (versionné)
    └── paths.local.md           ← Chemins locaux (ignoré par git)
```

---

## Installation

### 1. Cloner le hub

```bash
git clone https://github.com/toi/opencode-hub.git ~/opencode-hub
cd ~/opencode-hub
chmod +x oc.sh scripts/*.sh
```

### 2. Installer les dépendances

```bash
./oc.sh install
```

Installe automatiquement :
- [OpenCode](https://opencode.ai) via npm
- [Beads](https://beads.so) via npm
- Crée les fichiers initiaux si absents

### 3. Alias recommandé

Ajouter dans ton `.bashrc` / `.zshrc` :

```bash
alias oc="~/opencode-hub/oc.sh"
```

Puis :

```bash
source ~/.zshrc
```

---

## Commandes

### `oc install`
Installe OpenCode, Beads et prépare la structure du hub.

```bash
./oc.sh install
```

---

### `oc init [PROJECT_ID] [chemin]`
Enregistre un projet dans le hub.

```bash
./oc.sh init              # mode interactif
./oc.sh init MON-APP ~/workspace/mon-app
```

- Ajoute le projet dans `projects/projects.md`
- Enregistre le chemin local dans `projects/paths.local.md`
- Accepte les projets existants (adoption) ou nouveaux

---

### `oc list`
Liste tous les projets enregistrés avec leur statut.

```bash
./oc.sh list
```

```
  ID                   Chemin local                   Statut
  ──────────────────────────────────────────────────────────
  MON-APP              ~/workspace/mon-app            ✔ accessible
  AUTRE-APP            ~/workspace/autre              ✘ introuvable
```

---

### `oc start [PROJECT_ID]`
Lance OpenCode dans le dossier du projet.

```bash
./oc.sh start             # sélection interactive
./oc.sh start MON-APP
```

---

### `oc remove <PROJECT_ID>`
Supprime un projet du registre (avec confirmation).

```bash
./oc.sh remove MON-APP
```

---

### `oc sync`
Injecte les skills dans les agents qui ont un marqueur `<!-- SKILLS: ... -->`.

```bash
./oc.sh sync
```

---

### `oc update`
Met à jour OpenCode et Beads.

```bash
./oc.sh update
```

---

## Agents

Les agents sont définis dans `.opencode/agents/` et partagés entre tous les projets.

### Exemple — `agents/dev.md`

```markdown
---
name: dev
description: Agent développement principal
---

Tu es un développeur senior. Tu suis les conventions du projet.

<!-- SKILLS: git-flow, vue3 -->

<!-- SKILLS_START -->
<!-- injecté automatiquement par ./oc.sh sync -->
<!-- SKILLS_END -->
```

Le marqueur `<!-- SKILLS: skill1, skill2 -->` indique quels fichiers
de `skills/` injecter. Lancer `./oc.sh sync` après toute modification
d'un skill.

---

## Skills

Les skills sont des blocs Markdown dans `skills/` décrivant des conventions
ou bonnes pratiques réutilisables.

### Exemple — `skills/git-flow.md`

```markdown
## Git Flow

- Branches : `feature/`, `fix/`, `chore/`
- Commits : format Conventional Commits
- Une PR = une tâche Beads
- Toujours rebaser sur `main` avant de merger
```

Ajouter un skill dans un agent :
1. Créer `skills/mon-skill.md`
2. Ajouter `<!-- SKILLS: ..., mon-skill -->` dans l'agent
3. Lancer `./oc.sh sync`

---

## Projets

### `projects/projects.md` — versionné

```markdown
# Projets

## MON-APP
- Nom : Mon Application
- Stack : Vue 3 + Laravel
- Board Beads : MON-APP
- Labels : feature, fix, front, back
```

### `projects/paths.local.md` — ignoré par git

```
# Chemins locaux (ignoré par git)
MON-APP=~/workspace/mon-app
AUTRE-APP=/home/user/projets/autre-app
```

> Chaque développeur maintient son propre `paths.local.md`.
> Il ne doit jamais être commité.

---

## Workflow typique

```bash
# 1. Installer le hub
./oc.sh install

# 2. Enregistrer un projet
./oc.sh init MON-APP ~/workspace/mon-app

# 3. Synchroniser les skills dans les agents
./oc.sh sync

# 4. Lancer OpenCode
./oc.sh start MON-APP
```

---

## .gitignore recommandé

```
projects/paths.local.md
.opencode/auth.json
```

---

## Contribuer

Les agents et skills sont versionnés et partagés par toute l'équipe.
Pour ajouter un skill ou modifier un agent, soumettre une PR comme pour
n'importe quel autre fichier du projet.