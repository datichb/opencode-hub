# Référence CLI — commandes `oc`

Toutes les commandes disponibles via le point d'entrée `oc.sh` (alias recommandé : `oc`).

---

## Synopsis global

```
oc <commande> [sous-commande] [options] [arguments]
```

---

## `oc install`

Installe les outils, crée la structure du hub et configure les cibles actives.

```bash
oc install
```

**Comportement :**
- Interactif — propose un menu de sélection des cibles
- Vérifie et propose d'installer Node.js si une cible en a besoin (OpenCode, Claude Code)
- Si `config/hub.json` existe déjà, demande confirmation avant d'écraser

**Options de cible :**

| Choix | Cibles configurées |
|-------|--------------------|
| 1 (défaut) | OpenCode |
| 2 | Claude Code |
| 3 | VS Code / Copilot |
| 4 | Tout |

> VS Code / Copilot ne requiert pas Node.js.

---

## `oc deploy`

Génère les fichiers agents pour une cible dans un projet.

```bash
oc deploy <target> [PROJECT_ID]
oc deploy --check [target] [PROJECT_ID]
oc deploy --diff  [target] [PROJECT_ID]
```

**Arguments :**

| Argument | Valeurs | Description |
|----------|---------|-------------|
| `<target>` | `opencode`, `claude-code`, `vscode`, `all` | Cible à déployer |
| `[PROJECT_ID]` | ID d'un projet enregistré | Optionnel — déploie au niveau du hub si absent |

**Options :**

| Option | Description |
|--------|-------------|
| `--check` | Vérifie si les fichiers sont à jour sans déployer |
| `--diff` | Compare les sources avec les fichiers déployés ; propose le déploiement si un écart est détecté |

**Exemples :**

```bash
oc deploy opencode              # déploie OpenCode au niveau du hub
oc deploy opencode MON-APP      # déploie OpenCode dans MON-APP
oc deploy all MON-APP           # déploie toutes les cibles actives dans MON-APP
oc deploy --check               # vérifie toutes les cibles actives (hub)
oc deploy --check opencode      # vérifie OpenCode (hub)
oc deploy --check all MON-APP   # vérifie toutes les cibles pour MON-APP
oc deploy --diff all MON-APP    # affiche le diff sources → déployés pour MON-APP
```

**Sorties générées :**

| Cible | Fichiers générés |
|-------|-----------------|
| `opencode` | `.opencode/agents/*.md` + `opencode.json` (régénéré si une clé API ou un PROJECT_ID est défini) |
| `claude-code` | `.claude/agents/*.md` |
| `vscode` | `.github/copilot-instructions.md` + `.vscode/prompts/*.prompt.md` |

**Codes de sortie `--check` :**
- `0` : tout est à jour
- `1` : au moins un fichier est obsolète ou manquant

---

## `oc sync`

Redéploie les agents sur tous les projets enregistrés ayant un chemin local défini.

```bash
oc sync [--dry-run]
```

**Options :**

| Option | Description |
|--------|-------------|
| `--dry-run` | Vérifie la fraîcheur sans déployer (équivalent à `oc deploy --check` sur chaque projet) |

**Exemples :**

```bash
oc sync             # redéploie sur tous les projets
oc sync --dry-run   # vérifie sans déployer
```

---

## `oc start`

Lance l'outil par défaut dans le répertoire d'un projet.

```bash
oc start [PROJECT_ID] [prompt] [--dev [--label <label>] [--assignee <user>]] [--onboard]
```

**Arguments :**

| Argument | Description |
|----------|-------------|
| `[PROJECT_ID]` | ID du projet — sélection interactive si absent |
| `[prompt]` | Prompt de démarrage passé à l'outil |

**Options :**

| Option | Description |
|--------|-------------|
| `--dev` | Mode développement — charge les tickets `ai-delegated` ouverts dans le prompt de démarrage. Effectue un sync tracker `--pull-only` automatique avant le lancement. |
| `--dev --label <label>` | Comme `--dev`, mais filtre les tickets ayant le label `<label>` |
| `--dev --assignee <user>` | Comme `--dev`, mais filtre les tickets assignés à `<user>` |
| `--onboard` | Injecte un prompt de découverte projet pour onboarder l'agent sur le codebase |

> `--dev` et `--onboard` sont mutuellement exclusifs. `--label` et `--assignee` sont mutuellement exclusifs.
> Ces options sont ignorées silencieusement pour la cible `vscode` (pas de support prompt).

**Exemples :**

```bash
oc start                                        # sélection interactive du projet
oc start MON-APP                                # lance l'outil dans MON-APP
oc start MON-APP "explique l'architecture"      # avec prompt de démarrage
oc start MON-APP --dev                          # charge les tickets ai-delegated
oc start MON-APP --dev --label ai-delegated     # filtre par label
oc start MON-APP --dev --assignee alice         # filtre par assignee
oc start MON-APP --onboard                      # prompt de découverte projet
```

> Avertit automatiquement si les agents ne sont pas déployés ou si `.beads/` est absent.

---

## `oc init`

Enregistre un projet dans le hub.

```bash
oc init [PROJECT_ID] [chemin]
```

**Arguments :**

| Argument | Description |
|----------|-------------|
| `[PROJECT_ID]` | Identifiant unique du projet (lettres, chiffres, `-`, `_`) |
| `[chemin]` | Chemin absolu ou `~`-expansé vers le répertoire du projet |

**Exemples :**

```bash
oc init                              # mode interactif
oc init MON-APP ~/workspace/mon-app  # enregistrement direct
```

> Propose de déployer les agents immédiatement après l'enregistrement.

---

## `oc list`

Liste les projets enregistrés avec leur statut d'accessibilité.

```bash
oc list
```

> Pour un tableau de bord détaillé (Beads, API, agents, tracker), utiliser `oc status`.

---

## `oc status`

Affiche un tableau de bord de l'état de tous les projets enregistrés.

```bash
oc status
```

**Pour chaque projet, vérifie :**
- Chemin local accessible
- Beads initialisé (`.beads/`)
- Clé API configurée (provider + modèle)
- Tracker configuré
- Agents déployés pour la cible par défaut

**Exemple de sortie :**

```
  MON-APP
    ·  Chemin : /Users/alice/workspace/mon-app
    ✔  Beads initialisé
    ✔  API configurée (anthropic / claude-sonnet-4-5)
    ·  Tracker : aucun
    ✔  Agents déployés (opencode) : 12 fichier(s)
```

---

## `oc remove`

Supprime un projet du registre (avec confirmation).

```bash
oc remove <PROJECT_ID> [--clean]
```

**Options :**

| Option | Description |
|--------|-------------|
| `--clean` | Supprime également les fichiers agents déployés dans le répertoire du projet (`.opencode/agents/`, `opencode.json`, `.claude/agents/`, `.vscode/prompts/` selon les cibles actives) |

**Exemples :**

```bash
oc remove MON-APP           # retire du registre uniquement
oc remove MON-APP --clean   # retire du registre + nettoie les fichiers déployés
```

> Demande confirmation dans les deux cas. Retire aussi l'entrée de `paths.local.md` et `api-keys.local.md`.

---

## `oc update`

Met à jour les outils installés selon les cibles actives.

```bash
oc update
```

---

## `oc version`

Affiche la version du hub (lue depuis `config/hub.json`).

```bash
oc version
```

---

## `oc config`

Gère les clés API et les modèles IA par projet. Les données sont stockées dans `projects/api-keys.local.md` (non versionné).

```bash
oc config <sous-commande> [options]
```

| Sous-commande | Description |
|---------------|-------------|
| `set <PROJECT_ID> [options]` | Configure la clé API, le modèle et le provider pour un projet |
| `get <PROJECT_ID>` | Affiche la configuration d'un projet (clé masquée) |
| `list` | Liste toutes les configurations enregistrées |
| `unset <PROJECT_ID>` | Supprime la configuration d'un projet (avec confirmation) |

**Options de `oc config set` :**

| Option | Description |
|--------|-------------|
| `--model <modèle>` | Modèle IA (défaut : `claude-sonnet-4-5`) |
| `--provider <provider>` | `anthropic` ou `litellm` (défaut : `anthropic`) |
| `--api-key <clé>` | Clé API (saisie masquée en mode interactif) |
| `--base-url <url>` | URL de base (litellm uniquement) |

> Sans options, `set` est interactif — propose les valeurs actuelles comme défaut.
> Après un `set`, propose de re-déployer `opencode.json` dans le projet si le chemin est connu.

**Exemples :**

```bash
oc config set MON-APP                                 # mode interactif
oc config set MON-APP --model claude-opus-4-5 --provider anthropic --api-key sk-ant-...
oc config set MON-APP --provider litellm --api-key sk-... --base-url https://api.example.com/v1
oc config get MON-APP                                 # affiche la config (clé masquée)
oc config list                                        # liste toutes les entrées
oc config unset MON-APP                               # supprime (avec confirmation)
```

---

## `oc agent`

Gère les agents canoniques du hub.

```bash
oc agent <sous-commande>
```

| Sous-commande | Description |
|---------------|-------------|
| `list` | Liste tous les agents avec leur id, label et targets |
| `create` | Crée un nouvel agent (workflow interactif) |
| `edit <id>` | Modifie les skills et métadonnées d'un agent existant |
| `info <id>` | Affiche le détail complet d'un agent (frontmatter + corps) |
| `select <PROJECT_ID>` | Choisit les agents à déployer pour un projet |
| `mode <PROJECT_ID>` | Affiche / overrides les modes `primary`/`subagent` par projet |
| `validate [agent-id]` | Valide la cohérence des agents (champs requis, skills existants, targets valides, unicité des id) |
| `keytest` | Diagnostic clavier pour le sélecteur interactif |

### `oc agent create` — workflow interactif

1. **Identifiant** — slug unique (ex: `reviewer`)
2. **Label** — nom court affiché dans l'outil (ex: `CodeReviewer`)
3. **Description** — phrase courte décrivant le rôle
4. **Cibles** — sélecteur interactif ↑↓/espace : `opencode`, `claude-code`, `vscode`
5. **Skills** — sélecteur interactif ↑↓/espace avec panneau de description
6. **Corps** — si `opencode` est disponible, proposition de génération automatique via `opencode run`
7. **Prévisualisation** — affichage du fichier `.md` complet avant écriture
8. **Confirmation** — `Y/n` pour créer le fichier

### `oc agent validate`

```bash
oc agent validate             # valide tous les agents canoniques
oc agent validate <agent-id>  # valide uniquement l'agent spécifié
```

Vérifie pour chaque agent :
- Champs requis présents (`id`, `label`, `description`, `targets`, `skills`)
- Unicité de l'`id` sur l'ensemble des agents
- `mode` valide (`primary` | `subagent` | `all`) si présent
- Toutes les cibles dans `targets` reconnues (`opencode`, `claude-code`, `vscode`)
- Tous les skills référencés existent (local ou externe)

Retourne le code 1 si au moins une erreur est détectée.

> `oc agent keytest` affiche les octets bruts reçus pour chaque touche. Utile pour
> diagnostiquer un terminal où la navigation du sélecteur ne fonctionne pas. Quitter avec `q`.

---

## `oc skills`

Gère les skills externes téléchargés via context7.

```bash
oc skills <sous-commande>
```

| Sous-commande | Description |
|---------------|-------------|
| `search <query>` | Recherche des skills disponibles |
| `add /owner/repo [name]` | Ajoute un skill externe |
| `list` | Liste tous les skills (locaux + externes) |
| `update [name]` | Met à jour un skill externe (ou tous si absent) |
| `info /owner/repo` | Prévisualise les skills disponibles dans un dépôt |
| `used-by <skill>` | Liste les agents qui utilisent ce skill |
| `sync` | Re-télécharge tous les skills externes (utile après clone) |
| `remove <name>` | Supprime un skill externe |

---

## `oc beads`

Gère l'intégration Beads (`bd`) dans les projets enregistrés.

```bash
oc beads <sous-commande>
```

| Sous-commande | Description |
|---------------|-------------|
| `status [PROJECT_ID]` | Vérifie Beads sur tous les projets (ou un seul) |
| `init <PROJECT_ID>` | Initialise `.beads/` dans le projet |
| `list <PROJECT_ID>` | Liste les tickets ouverts du projet |
| `create <PROJECT_ID> [titre] [--label <l>] [--type <t>] [--desc <d>]` | Crée un ticket dans le projet |
| `open <PROJECT_ID>` | Affiche le chemin pour utiliser `bd` manuellement |
| `sync <PROJECT_ID> [options]` | Synchronise avec un tracker externe |
| `tracker status <PROJECT_ID>` | Affiche le statut de connexion au tracker |
| `tracker setup <PROJECT_ID>` | Configure le tracker (interactif) |
| `tracker switch <PROJECT_ID>` | Change de provider (jira ↔ gitlab ↔ none) |

### `oc beads create`

```bash
oc beads create <PROJECT_ID> [titre] [--label <label>] [--type <type>] [--desc <description>]
```

| Argument / Option | Description |
|-------------------|-------------|
| `<PROJECT_ID>` | Projet dans lequel créer le ticket |
| `[titre]` | Titre du ticket — mode interactif si absent |
| `--label <label>` | Étiquette du ticket |
| `--type <type>` | Type de ticket (`feature`, `fix`, `chore`, …) |
| `--desc <description>` | Description longue |

**Exemples :**

```bash
oc beads create MON-APP                                              # mode interactif
oc beads create MON-APP "Ajouter la gestion des rôles"              # titre direct
oc beads create MON-APP "Fix race condition" --type fix --label bug  # avec flags
```

**Options de `oc beads sync` :**

| Option | Description |
|--------|-------------|
| `--pull-only` | Importe seulement depuis le tracker |
| `--push-only` | Exporte seulement vers le tracker |
| `--dry-run` | Simule sans modifier |

> `oc start` avertit automatiquement si `.beads/` n'est pas présent dans le projet.
