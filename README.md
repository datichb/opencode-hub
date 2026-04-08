# opencode-hub

Hub central pour piloter des assistants IA sur plusieurs projets,
avec des agents partagés, des skills injectables et un workflow Beads intégré.

Supporte **OpenCode**, **Claude Code** et **VS Code / Copilot**.

---

## Pourquoi opencode-hub ?

Les outils IA fonctionnent en silo. opencode-hub centralise tout :

- Agents et rôles définis **une seule fois**, déployés partout
- Skills (protocoles, standards) **injectés automatiquement** au déploiement
- 27 agents spécialisés : orchestrateur, orchestrateur-dev, onboarder, planificateur, documentariste, 2 designers, 9 développeurs, QA, debugger, reviewer, 7 auditeurs
- Projets enregistrés et lancés via **une commande unique**
- Workflow Beads intégré pour la **gestion des tâches**

---

## Installation

### One-liner (recommandé)

```bash
curl -fsSL https://raw.githubusercontent.com/BenjaminDataiche/opencode-hub/main/install.sh | bash
```

Le script automatise tout : clone du repo dans `~/.opencode-hub`, installation des dépendances (`jq`, `Node.js`, `opencode`, `bun`), création de l'alias `oc` dans votre shell, et configuration interactive des cibles AI.

> **Dépendances requises :** `git`, `curl`
> Les autres dépendances (`jq`, `Node.js`, `opencode`, `bun`) sont installées automatiquement.

Après l'installation, recharger le shell :

```bash
source ~/.zshrc   # ou source ~/.bashrc
```

### Installation manuelle

```bash
git clone https://github.com/BenjaminDataiche/opencode-hub.git ~/.opencode-hub
echo 'alias oc="~/.opencode-hub/oc.sh"' >> ~/.zshrc && source ~/.zshrc
oc install
```

---

## Démarrage rapide

Une fois installé :

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

## Agents disponibles

| Famille | Agents |
|---------|--------|
| Coordinateurs | `orchestrator`, `orchestrator-dev`, `auditor`, `onboarder` |
| Développeurs | `developer-frontend`, `developer-backend`, `developer-fullstack`, `developer-data`, `developer-devops`, `developer-mobile`, `developer-api`, `developer-platform`, `developer-security` |
| Design | `ux-designer`, `ui-designer` |
| Qualité | `reviewer`, `qa-engineer`, `debugger` |
| Audit | `auditor-security`, `auditor-performance`, `auditor-accessibility`, `auditor-ecodesign`, `auditor-architecture`, `auditor-privacy`, `auditor-observability` |
| Planification | `planner` |
| Documentation | `documentarian` |

---

## Licence

MIT
