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

**Exemples :**

```bash
oc deploy opencode              # déploie OpenCode au niveau du hub
oc deploy opencode MON-APP      # déploie OpenCode dans MON-APP
oc deploy all MON-APP           # déploie toutes les cibles actives dans MON-APP
oc deploy --check               # vérifie toutes les cibles actives (hub)
oc deploy --check opencode      # vérifie OpenCode (hub)
oc deploy --check all MON-APP   # vérifie toutes les cibles pour MON-APP
```

**Sorties générées :**

| Cible | Fichiers générés |
|-------|-----------------|
| `opencode` | `.opencode/agents/*.md` + `opencode.json` (créé seulement s'il n'existe pas) |
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
oc start [PROJECT_ID] [prompt] [--dev]
```

**Arguments :**

| Argument | Description |
|----------|-------------|
| `[PROJECT_ID]` | ID du projet — sélection interactive si absent |
| `[prompt]` | Prompt de démarrage passé à l'outil |

**Options :**

| Option | Description |
|--------|-------------|
| `--dev` | Mode développement — charge les tickets `ai-delegated` ouverts dans le prompt |

**Exemples :**

```bash
oc start                                    # sélection interactive du projet
oc start MON-APP                            # lance l'outil dans MON-APP
oc start MON-APP "explique l'architecture"  # avec prompt de démarrage
oc start MON-APP --dev                      # charge les tickets ai-delegated
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

---

## `oc remove`

Supprime un projet du registre (avec confirmation).

```bash
oc remove <PROJECT_ID>
```

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
| `open <PROJECT_ID>` | Affiche le chemin pour utiliser `bd` manuellement |
| `sync <PROJECT_ID> [options]` | Synchronise avec un tracker externe |
| `tracker status <PROJECT_ID>` | Affiche le statut de connexion au tracker |
| `tracker setup <PROJECT_ID>` | Configure le tracker (interactif) |
| `tracker switch <PROJECT_ID>` | Change de provider (jira ↔ gitlab ↔ none) |

**Options de `oc beads sync` :**

| Option | Description |
|--------|-------------|
| `--pull-only` | Importe seulement depuis le tracker |
| `--push-only` | Exporte seulement vers le tracker |
| `--dry-run` | Simule sans modifier |

> `oc start` avertit automatiquement si `.beads/` n'est pas présent dans le projet.
