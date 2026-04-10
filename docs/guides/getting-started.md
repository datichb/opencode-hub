# Démarrage rapide

Ce guide vous permet d'installer le hub et de lancer votre premier agent en moins de 10 minutes.

## Prérequis

| Outil | Version minimale | Vérification |
|-------|-----------------|--------------|
| Git | 2.x | `git --version` |
| curl | — | `curl --version` |

> Les autres dépendances (`jq`, `Node.js`, `opencode`, `bun`) sont installées automatiquement par le script d'installation.
>
> **Beads (`bd`)** est installé automatiquement par `oc install`.

---

## 1. Installer le hub

### Option A — One-liner (recommandé)

```bash
curl -fsSL https://raw.githubusercontent.com/datichb/opencode-hub/main/install.sh | bash
```

Le script automatise :
- Clone du repo dans `~/.opencode-hub`
- Installation des dépendances manquantes (`jq`, `Node.js`, `opencode`, `bun`)
- Création de l'alias `oc` dans `~/.zshrc` ou `~/.bashrc`
- Initialisation des fichiers de config locaux
- Configuration interactive des cibles AI et du provider LLM

Après l'installation, recharger le shell :

```bash
source ~/.zshrc   # ou source ~/.bashrc
```

> **Dossier d'installation personnalisé :** `OPENCODE_HUB_DIR=~/tools/oc bash install.sh`

---

### Option B — Installation manuelle

```bash
# 1. Cloner
git clone https://github.com/BenjaminDataiche/opencode-hub.git ~/.opencode-hub

# 2. Alias shell
echo 'alias oc="~/.opencode-hub/oc.sh"' >> ~/.zshrc && source ~/.zshrc

# 3. Configurer
oc install
```

`oc install` est interactif et vous demande de choisir les cibles à activer :

| Choix | Cibles configurées |
|-------|--------------------|
| 1 (défaut) | OpenCode |
| 2 | Claude Code |
| 3 | Tout (OpenCode + Claude Code) |

> Si `config/hub.json` existe déjà, une confirmation est demandée avant d'écraser
> la configuration. Répondez `N` pour conserver votre configuration existante.

---

## 2. Enregistrer un projet

```bash
oc init MON-APP ~/workspace/mon-app
```

Cette commande :
- Ajoute `MON-APP` dans `projects/projects.md`
- Associe le chemin local `~/workspace/mon-app`
- Propose de déployer les agents immédiatement

> **Convention `PROJECT_ID`** : lettres, chiffres, `-` et `_` uniquement. Pas d'espaces.

---

## 3. Déployer les agents

Si vous n'avez pas déployé lors du `oc init` :

```bash
# Déployer dans un projet spécifique
oc deploy opencode MON-APP
oc deploy all MON-APP   # toutes les cibles actives
```

Résultat attendu selon la cible :

| Cible | Fichiers générés dans le projet |
|-------|---------------------------------|
| `opencode` | `.opencode/agents/*.md` |
| `claude-code` | `.claude/agents/*.md` |

---

## 4. Lancer l'outil

```bash
oc start MON-APP
```

Lance l'outil par défaut (défini dans `config/hub.json`) dans le répertoire du projet.

Avec un prompt de démarrage :

```bash
oc start MON-APP "explique l'architecture du projet"
```

En mode développement (charge les tickets `ai-delegated` ouverts) :

```bash
oc start MON-APP --dev
```

---

## 5. Vérifier le déploiement

```bash
oc deploy --check opencode MON-APP
```

Affiche pour chaque agent : `✓ À JOUR`, `⚠ OBSOLÈTE` ou `✗ MANQUANT`.

Après un `git pull` sur le hub (ou `oc update`) :

```bash
oc sync            # redéploie sur tous les projets
oc sync --dry-run  # vérifie sans déployer
```

---

## Résultat attendu

À l'issue de ces étapes, dans le répertoire de votre projet :

```
mon-app/
└── .opencode/
    └── agents/
        ├── orchestrator.md
        ├── planner.md
        ├── reviewer.md
        ├── qa-engineer.md
        ├── debugger.md
        ├── auditor.md
        ├── developer-frontend.md
        └── ...
```

Vous pouvez maintenant invoquer n'importe quel agent dans OpenCode :
- `"Implémente la feature de connexion utilisateur"` → agent `orchestrator`
- `"Audite la sécurité du projet"` → agent `auditor-security`
- `"Planifie le module de paiement"` → agent `planner`

---

## Mettre à jour le hub

```bash
oc update
```

Met à jour opencode, Beads, et les skills externes. Si des skills sont modifiés, propose de relancer `oc sync`.

Pour mettre à jour les sources du hub lui-même :

```bash
git -C ~/.opencode-hub pull
oc sync
```

---

## Dépannage

| Symptôme | Solution |
|----------|----------|
| `oc: command not found` | Relancer `source ~/.zshrc` (ou `~/.bashrc`) après installation |
| `curl: command not found` | Installer curl, puis relancer le one-liner |
| `Node.js introuvable` | Relancer `oc install` — propose les installeurs disponibles |
| Agent absent dans l'outil | Relancer `oc deploy <target> MON-APP` |
| Agent obsolète (`⚠ OBSOLÈTE`) | `oc deploy <target> MON-APP` pour resynchroniser |
| `bd: command not found` | Installer Beads : `brew install bd` |
| Dossier d'install déjà existant | `OPENCODE_HUB_DIR=~/autre-chemin bash install.sh` |
