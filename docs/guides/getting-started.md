# Démarrage rapide

Ce guide vous permet d'installer le hub et de lancer votre premier agent en moins de 10 minutes.

## Prérequis

| Outil | Version minimale | Vérification |
|-------|-----------------|--------------|
| Git | 2.x | `git --version` |
| Node.js | 18+ | `node --version` |

> **Note :** Node.js est requis uniquement si vous ciblez OpenCode ou Claude Code.
> VS Code / Copilot ne nécessite pas Node.js.
>
> **Beads (`bd`)** est installé automatiquement par `oc install` — pas besoin de l'installer manuellement.

---

## 1. Cloner le hub

```bash
git clone https://github.com/toi/opencode-hub.git ~/opencode-hub
chmod +x ~/opencode-hub/oc.sh ~/opencode-hub/scripts/*.sh \
         ~/opencode-hub/scripts/adapters/*.sh \
         ~/opencode-hub/scripts/lib/*.sh
```

---

## 2. Alias recommandé

Ajouter dans `~/.zshrc` ou `~/.bashrc` :

```bash
alias oc="~/opencode-hub/oc.sh"
source ~/.zshrc   # ou source ~/.bashrc
```

---

## 3. Installer le hub

```bash
oc install
```

Le script interactif vous demande de choisir les cibles à activer :

| Choix | Cibles configurées |
|-------|--------------------|
| 1 (défaut) | OpenCode |
| 2 | Claude Code |
| 3 | VS Code / Copilot |
| 4 | Tout |

> Si `config/hub.json` existe déjà, une confirmation est demandée avant d'écraser
> la configuration. Répondez `N` pour conserver votre configuration existante.

---

## 4. Enregistrer un projet

```bash
oc init MON-APP ~/workspace/mon-app
```

Cette commande :
- Ajoute `MON-APP` dans `projects/projects.md`
- Associe le chemin local `~/workspace/mon-app`
- Propose de déployer les agents immédiatement

> **Convention `PROJECT_ID`** : lettres, chiffres, `-` et `_` uniquement. Pas d'espaces.

---

## 5. Déployer les agents

Si vous n'avez pas déployé lors du `oc init` :

```bash
# Déployer sur le hub lui-même (OpenCode)
oc deploy opencode

# Déployer dans un projet spécifique
oc deploy opencode MON-APP
oc deploy all MON-APP   # toutes les cibles actives
```

Résultat attendu selon la cible :

| Cible | Fichiers générés dans le projet |
|-------|---------------------------------|
| `opencode` | `.opencode/agents/*.md` |
| `claude-code` | `.claude/agents/*.md` |
| `vscode` | `.github/copilot-instructions.md` + `.vscode/prompts/*.prompt.md` |

---

## 6. Lancer l'outil

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

## 7. Vérifier le déploiement

```bash
oc deploy --check opencode MON-APP
```

Affiche pour chaque agent : `✓ À JOUR`, `⚠ OBSOLÈTE` ou `✗ MANQUANT`.

Après un `git pull` sur le hub :

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

## Dépannage

| Symptôme | Solution |
|----------|----------|
| `oc: command not found` | Vérifier l'alias dans `.zshrc`/`.bashrc` et `source` le fichier |
| `Node.js introuvable` | Relancer `oc install` — propose les installeurs disponibles |
| Agent absent dans l'outil | Relancer `oc deploy <target> MON-APP` |
| Agent obsolète (`⚠ OBSOLÈTE`) | `oc deploy <target> MON-APP` pour resynchroniser |
| `bd: command not found` | Installer Beads : `brew install bd` |
