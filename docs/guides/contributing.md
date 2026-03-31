# Guide de contribution

Ce guide explique comment ajouter un agent, un skill ou un adapter au hub,
et comment contribuer via une PR.

---

## Ajouter un agent

### 1. Créer le fichier agent

```bash
touch agents/<famille>/<id>.md
```

Respecter la convention de nommage :
- `<domaine>-<spécialité>.md` pour les sous-agents (ex: `auditor-security.md`)
- `<rôle>.md` pour les agents principaux (ex: `orchestrator.md`)

### 2. Structure minimale du frontmatter

```markdown
---
id: <identifiant-unique>
label: <NomAffiché>
description: <Description courte en une phrase — visible dans les listes d'agents>
targets: [opencode, claude-code, vscode]
skills: [chemin/vers/skill, ...]
---
```

**Règles :**
- `id` : slug unique, minuscules, tirets autorisés, pas d'espaces
- `label` : PascalCase, affiché dans l'outil IA
- `description` : une phrase, commence par un verbe ou un nom de rôle
- `targets` : au moins `[opencode]` — ajouter les autres si le format est compatible
- `skills` : chemins relatifs à `skills/`, dans l'ordre d'injection souhaité

### 3. Corps de l'agent

Structure recommandée (voir `agents/auditor/auditor.md` comme référence pour les coordinateurs,
`agents/developer/developer-frontend.md` pour les agents implémenteurs) :

```markdown
# <NomAffiché>

<Phrase d'identité : qui tu es et ce que tu fais en 2-3 lignes>

## Ce que tu fais

- <Action 1>
- <Action 2>

## Ce que tu NE fais PAS

- <Contrainte 1>
- <Contrainte 2>

## Workflow

<Workflow condensé en 4-6 étapes>

## Exemples d'invocation (optionnel)

| Demande | Action |
|---------|--------|
| "..." | ... |
```

### 4. Créer ou référencer les skills

Si l'agent nécessite un protocole dédié, créer le skill correspondant
(voir section "Ajouter un skill" ci-dessous) avant de le référencer dans le frontmatter.

### 5. Déployer et tester

```bash
oc deploy opencode
# Vérifier que l'agent apparaît
oc agent list
oc agent info <id>
```

---

## Ajouter un skill

### 1. Choisir le bon dossier

Les skills sont organisés par domaine dans `skills/` :

| Dossier | Usage |
|---------|-------|
| `skills/developer/` | Standards de développement (partagés entre developers et reviewer) |
| `skills/auditor/` | Protocoles d'audit |
| `skills/orchestrator/` | Protocoles de coordination |
| `skills/planning/` | Protocoles de planification |
| `skills/qa/` | Protocoles qualité |
| `skills/debugger/` | Protocoles de diagnostic |
| `skills/reviewer/` | Protocoles de review |
| `skills/documentarian/` | Protocoles de documentation |

Pour un nouveau domaine, créer un nouveau sous-dossier.

### 2. Structure minimale du frontmatter

```markdown
---
name: <nom-du-skill>
description: <Description courte — visible dans oc agent edit et oc skills list>
---
```

> La clé `name` est documentaire. Les scripts lisent uniquement `description`.
> Le chemin du fichier est la référence utilisée dans le frontmatter des agents.

### 3. Contenu du skill

Un bon skill contient :

- **Rôle** : rappel de l'identité de l'agent qui utilise ce skill
- **Règles absolues** : ❌/✅ — les contraintes non négociables
- **Protocole / workflow** : les étapes détaillées
- **Formats de sortie** : les structures exactes des rapports, avec exemples
- **Checklists** : les vérifications systématiques
- **Ce que tu ne fais PAS** : les anti-patterns explicites

Voir `skills/reviewer/review-protocol.md` ou `skills/qa/qa-protocol.md` comme exemples.

### 4. Référencer le skill dans un agent

Ajouter le chemin dans le frontmatter de l'agent (sans l'extension `.md`) :

```markdown
---
skills: [chemin/vers/mon-skill]
---
```

---

## Ajouter un adapter

Un adapter traduit les agents du format hub vers le format d'un outil cible.

Le contrat complet (6 fonctions obligatoires, paramètres, fonctions utilitaires
disponibles et exemple minimal) est documenté dans
[docs/architecture/adapters.md](../architecture/adapters.md).

### Étapes rapides

1. Créer `scripts/adapters/<cible>.adapter.sh` avec les 6 fonctions du contrat
2. Ajouter la cible dans `config/hub.json`
3. Tester avec `oc deploy <cible>` puis `oc agent list`

---

## Conventions de contribution

### Commits

Format **Conventional Commits** obligatoire :

```
feat: ajouter l'agent <nom>
fix: corriger <problème> dans <fichier>
docs: mettre à jour <section>
chore: <maintenance>
refactor: <restructuration>
```

### Nommage des fichiers

| Type | Convention | Exemple |
|------|-----------|---------|
| Agent | `<domaine>[-<spécialité>].md` | `developer-frontend.md` |
| Skill (dans un sous-dossier) | `<domaine>-<sujet>.md` | `audit-security.md` |
| Script shell | `cmd-<commande>.sh` | `cmd-deploy.sh` |
| Adapter | `<cible>.adapter.sh` | `opencode.adapter.sh` |

### Scripts shell

Règles obligatoires pour tous les scripts shell :

```bash
#!/bin/bash
set -euo pipefail

# ✅ Les variables locales sont déclarées dans des fonctions
my_function() {
  local my_var="value"
}

# ❌ Jamais de 'local' hors d'une fonction — undefined behavior avec set -euo pipefail
# ❌ Jamais de "$var" && commande — toujours if [ "$var" = "true" ]
```

### ADR

Toute décision architecturale significative doit être documentée dans un ADR :

```bash
touch docs/architecture/adr/<NNN>-<titre-kebab-case>.md
```

Format : voir [ADR-001](../architecture/adr/001-agent-skill-separation.md) comme modèle.

### PR

Avant de soumettre une PR :

```bash
# Vérifier que les agents déploient correctement
oc deploy opencode
oc deploy --check opencode

# Lister les agents pour vérifier la cohérence
oc agent list
```

---

## Checklist avant PR

- [ ] Le fichier agent respecte la structure minimale (frontmatter + corps)
- [ ] Le skill a un frontmatter avec `name` et `description`
- [ ] L'agent est référencé dans `README.md` et `docs/architecture/agents.md`
- [ ] Le skill est référencé dans `docs/architecture/skills.md`
- [ ] Si décision architecturale : un ADR est créé dans `docs/architecture/adr/`
- [ ] Le commit respecte les Conventional Commits
- [ ] `oc deploy opencode` et `oc deploy --check opencode` passent sans erreur
