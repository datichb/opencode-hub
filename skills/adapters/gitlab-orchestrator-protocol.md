---
name: gitlab-orchestrator-protocol
description: Protocole d'intégration GitLab pour l'agent Orchestrator — lecture d'un ticket pour router au bon agent sans analyse de contenu, transmission du contexte GitLab aux sous-agents
---

# Skill — GitLab Orchestrator Protocol (v1)

## Rôle

Ce skill permet à l'Orchestrator de lire un ticket GitLab **pour le transmettre** à l'agent approprié, sans jamais analyser ni décomposer le contenu. L'Orchestrator lit — il ne planifie pas.

## Déclencheur

Activer si l'utilisateur fournit un numéro de ticket ou de MR dans sa demande :
- `"Implémente le ticket #42"`
- `"Prends en charge l'issue #42 du projet mon-groupe/mon-projet"`
- `"Travaille sur la MR !15"`

## Workflow

### Étape 1 : Identifier le type de référence

| Référence | Type | Outil à utiliser |
|---|---|---|
| `#N` ou `issue #N` | Ticket | `get_gitlab_issue` |
| `!N` ou `MR !N` | Merge Request | `get_gitlab_merge_request` |
| Aucune référence précise | — | `list_gitlab_issues` pour aider l'utilisateur |

### Étape 2A — Lire un ticket

```
Utiliser l'outil : get_gitlab_issue
Arguments : project_path, issue_iid
→ Obtenir : titre, description, labels, milestone, commentaires
```

**Utiliser uniquement pour déterminer :**
- Quel agent invoquer (voir tableau ci-dessous)
- Quelles informations transmettre au sous-agent

**Ne jamais analyser, décomposer, ni estimer soi-même.**

### Étape 2B — Lire une MR

```
Utiliser l'outil : get_gitlab_merge_request
Arguments : project_path, merge_request_iid
→ Obtenir : titre, description, branches, état, labels
```

### Étape 3 : Routing vers le bon agent

| Contenu du ticket | Agent recommandé |
|---|---|
| Feature nouvelle, scope large | `planner` |
| Feature simple, estimation rapide demandée | `scout` |
| Bug, régression, erreur | `debugger` |
| Revue de code, MR à reviewer | `reviewer` |
| Projet inconnu, premier accès | `onboarder` d'abord, puis `planner` |
| Audit de sécurité / perf / a11y mentionné | `auditor` |

### Étape 4 : Transmission du contexte

Lors de l'invocation du sous-agent, inclure systématiquement :

```
Contexte GitLab transmis :
- Ticket : #<iid> — <titre>
- Projet : <project_path>
- Description : <description complète>
- Labels : <labels>
- Milestone : <titre et échéance>
- Commentaires pertinents : <si présents>
```

**Ne jamais résumer la description** — la transmettre intégralement au sous-agent.

### Étape 5 : Aide à la sélection (si aucun ticket précis)

Si l'utilisateur demande de "travailler sur des tickets" sans en préciser un :

```
Utiliser l'outil : list_gitlab_issues
Arguments : project_path, state: "opened", per_page: 10
→ Afficher la liste à l'utilisateur pour qu'il choisisse
```

Présenter avec `question()` pour laisser l'utilisateur sélectionner le ticket à traiter.

### Règles absolues

- **Ne jamais décomposer** un ticket en sous-tâches (c'est le rôle du planner)
- **Ne jamais estimer** la complexité (c'est le rôle du scout)
- **Ne jamais coder** ni analyser le code lié au ticket
- **Toujours transmettre** la description originale sans la reformuler

### Gestion des erreurs

| Erreur | Comportement |
|---|---|
| Token invalide / expiré | Afficher : `⚠️ Token GitLab invalide — vérifier : oc gitlab status` |
| Ticket non trouvé (404) | Demander à l'utilisateur de vérifier le numéro et le projet |
| Pas de credentials | Demander à l'utilisateur de fournir le contexte manuellement |
