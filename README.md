# opencode-hub

Hub central pour piloter des assistants IA sur plusieurs projets,
avec des agents partagés, des skills injectables et un workflow Beads intégré.

Supporte **OpenCode** et **Claude Code**.

---

## Comment ça marche

opencode-hub repose sur trois concepts : **agents**, **skills** et **déploiement**.

- Les **agents** définissent les rôles IA (qui fait quoi, comment, dans quel ordre).
- Les **skills** sont des protocoles injectables (standards de code, checklists, formats de rapport) — déclarés une fois, réutilisés entre plusieurs agents.
- Le **déploiement** assemble agents + skills et les copie dans vos projets cibles.

```
opencode-hub/          ← source de vérité (éditer ici, jamais dans les projets)
├── agents/            ← identité des rôles IA (~40-80 lignes par agent)
├── skills/            ← protocoles détaillés injectables
└── scripts/           ← assemblage et déploiement

         oc deploy opencode MON-APP
opencode-hub  ──────────────────────►  mon-app/.opencode/agents/*.md
                                   └►  mon-app/opencode.json

         oc deploy claude-code MON-APP
opencode-hub  ──────────────────────►  mon-app/.claude/agents/*.md
```

Résultat : 27 agents spécialisés, toujours à jour, disponibles dans tous vos projets
depuis une source de vérité unique.

---

## Prérequis

| Outil | Usage |
|-------|-------|
| `git` | Cloner le hub |
| `curl` | Télécharger le script d'installation |

> Les autres dépendances (`jq`, `Node.js`, `opencode`, `bun`, `beads`) sont proposées
> lors de `oc install` — chaque outil demande une **confirmation explicite** avant installation.

---

## Installation

### One-liner (recommandé)

```bash
curl -fsSL https://raw.githubusercontent.com/datichb/opencode-hub/main/install.sh | bash
```

Le script automatise tout : clone dans `~/.opencode-hub`, vérification des dépendances
avec confirmation, création de l'alias `oc`, et configuration interactive des cibles AI.

Après l'installation, recharger le shell :

```bash
source ~/.zshrc   # ou source ~/.bashrc
```

### Installation manuelle

```bash
git clone https://github.com/datichb/opencode-hub.git ~/.opencode-hub
echo 'alias oc="~/.opencode-hub/oc.sh"' >> ~/.zshrc && source ~/.zshrc
oc install
```

---

## Désinstallation

```bash
oc uninstall
# ou directement :
bash ~/.opencode-hub/uninstall.sh
```

Guide interactif en 4 étapes — tout est optionnel et demande confirmation :

| Étape | Action | Défaut |
|-------|--------|--------|
| 1 | Nettoyer les agents déployés dans les projets (`.opencode/agents/`, `opencode.json`, `.claude/agents/`) | `[y/N]` |
| 2 | Supprimer le hub (`~/.opencode-hub`) | `[y/N]` |
| 3 | Retirer l'alias `oc` et les exports bun du fichier rc | `[Y/n]` |
| 4 | Désinstaller opencode, Beads, bun (séparément) | `[y/N]` |

> `jq` et `node` ne sont jamais désinstallés. Un backup `.bak` est créé avant toute
> modification du fichier rc.

---

## Démarrage rapide

```bash
# 1. Enregistrer un projet
oc init MON-APP ~/workspace/mon-app

# 2. Déployer les agents dans le projet
oc deploy opencode MON-APP

# 3. Lancer l'outil dans le projet
oc start MON-APP
```

> Guide complet : [docs/guides/getting-started.md](docs/guides/getting-started.md)

---

## Agents disponibles

27 agents organisés en 7 familles. Les agents `primary` sont visibles directement
par l'utilisateur ; les agents `subagent` sont invocables par les coordinateurs.

| Famille | Agents | Description | Usage type |
|---------|--------|-------------|------------|
| **Coordinateurs** | `orchestrator`, `orchestrator-dev`, `auditor`, `onboarder` | Pilotent d'autres agents, ne codent jamais | `"Implémente [feature]"` — orchestre tout de la spec au merge |
| **Développeurs** | `developer-frontend`, `developer-backend`, `developer-fullstack`, `developer-data`, `developer-devops`, `developer-mobile`, `developer-api`, `developer-platform`, `developer-security` | Implémentation par domaine technique | Routés automatiquement par `orchestrator-dev` |
| **Design** | `ux-designer`, `ui-designer` | Conception UX/UI en amont de l'implémentation, lecture seule | `"Spec UX pour [feature]"` avant de coder |
| **Qualité** | `reviewer`, `qa-engineer`, `debugger` | Review, tests manquants, diagnostic de bugs | `"Review de ma PR"` / `"Ce bug : [stacktrace]"` |
| **Audit** | `auditor-security`, `auditor-performance`, `auditor-accessibility`, `auditor-ecodesign`, `auditor-architecture`, `auditor-privacy`, `auditor-observability` | Audit par domaine, lecture seule | Délégués par `auditor` ou invocables directement |
| **Planification** | `planner`, `onboarder` | Décomposition en tickets Beads, découverte de projet | `"Décompose [feature] en tickets"` |
| **Documentation** | `documentarian` | README, CHANGELOG, ADR, doc API | `"Documente [sujet]"` |

> Référence complète : [docs/architecture/agents.md](docs/architecture/agents.md)

---

## Workflows disponibles

| Scénario | Point d'entrée | Prompt type |
|----------|---------------|-------------|
| Feature de A à Z | `orchestrator` | `"Implémente [feature]"` |
| Tickets prêts à coder | `orchestrator-dev` | `"Implémente les tickets bd-X à bd-Y"` |
| Audit avant mise en prod | `auditor` | `"Audite le projet"` |
| Bug en production | `debugger` | `"Ce bug : [stacktrace]"` |
| Spec UX/UI standalone | `ux-designer` / `ui-designer` | `"Spec UX pour [feature]"` |
| Documenter une feature | `documentarian` | `"Documente [sujet]"` |
| Découvrir un projet existant | `onboarder` | `"Onboarde-toi sur ce projet"` |
| Planifier sans implémenter | `planner` | `"Décompose [feature] en tickets"` |

> Scénarios détaillés avec diagrammes et prompts réels : [docs/guides/workflows.md](docs/guides/workflows.md)

---

## Documentation

### Guides

| Document | Description |
|----------|-------------|
| [Démarrage rapide](docs/guides/getting-started.md) | Installation complète, premier déploiement |
| [Providers LLM](docs/guides/providers.md) | Anthropic, MammouthAI, GitHub Models, Bedrock, Ollama |
| [Workflows](docs/guides/workflows.md) | Feature complète, audit, debug — scénarios illustrés |
| [Contribuer](docs/guides/contributing.md) | Ajouter un agent, un skill, un adapter |

### Architecture

| Document | Description |
|----------|-------------|
| [Vue d'ensemble](docs/architecture/overview.md) | Concepts, diagrammes de flux, principes de design |
| [Agents](docs/architecture/agents.md) | Référence exhaustive des 27 agents |
| [Skills](docs/architecture/skills.md) | Référence exhaustive des skills et leurs dépendances |
| [ADR](docs/architecture/adr/) | Décisions architecturales (6 ADR) |

### Référence

| Document | Description |
|----------|-------------|
| [CLI](docs/reference/cli.md) | Toutes les commandes `oc` avec options et exemples |
| [Configuration](docs/reference/config.md) | hub.json, projects.md, paths.local.md |

---

## Licence

MIT
