---
name: gitlab-pathfinder-protocol
description: Protocole d'intégration GitLab pour l'agent Pathfinder — lecture d'un ticket pour affiner l'estimation de complexité, détection de MR existantes sur le même périmètre
---

# Skill — GitLab Pathfinder Protocol (v1)

## Rôle

Ce skill enrichit le workflow du Pathfinder avec les données GitLab pour améliorer la précision des estimations et détecter les travaux déjà en cours sur le même périmètre.

## Étape 3bis — Vérification GitLab (optionnelle, après exploration codebase)

### Déclencheur

Activer si **au moins un** de ces critères :
- L'utilisateur a fourni un numéro de ticket (`#42`) ou de MR (`!15`)
- L'utilisateur a mentionné un projet GitLab
- La feature est décrite comme "ticket X" ou issue référencée

### Workflow

#### Cas A — Un ticket est fourni

```
Utiliser l'outil : get_gitlab_issue
Arguments : project_path, issue_iid
→ Obtenir : titre, description, labels, milestone, commentaires
```

**Exploiter pour affiner l'estimation :**

| Donnée GitLab | Impact sur l'estimation |
|---|---|
| Description longue avec ACs détaillés | +1 niveau de complexité si > 5 ACs |
| Labels `type::feature` + `area::frontend` + `area::backend` | Full-stack → +1 ticket minimum |
| Commentaires avec questions ouvertes | Signaler incertitudes dans le rapport |
| Milestone < 7 jours | Mentionner contrainte temporelle forte |
| Assigné à quelqu'un d'autre | Mentionner dans le rapport |

#### Cas B — Une MR est fournie

```
Utiliser l'outil : get_gitlab_merge_request
Arguments : project_path, merge_request_iid
→ Obtenir : titre, description, branches, état, labels, changements
```

**Exploiter pour :**
- Comprendre le périmètre si la MR est déjà en cours
- Estimer le delta restant si la MR est `opened` et partiellement implémentée
- Signaler si la MR a des conflits (`has_conflicts: true`)

#### Cas C — Recherche de travaux similaires (optionnel)

Si la feature semble liée à des travaux existants :

```
Utiliser l'outil : list_gitlab_issues
Arguments : project_path, state: "opened", search: <mots-clés>
→ Vérifier : tickets déjà ouverts sur le même périmètre
```

**Si ticket similaire trouvé :**
- Mentionner dans le rapport Pathfinder : "Ticket similaire détecté : #N"
- Recommander au planner de vérifier si c'est un doublon

### Format de sortie enrichi

Ajouter cette section dans le rapport Pathfinder si données GitLab disponibles :

```markdown
## 🦊 Contexte GitLab

**Ticket source :** #<iid> — <titre>
**Labels :** <labels>
**Milestone :** <titre> (échéance : <date ou "aucune">)
**Complexité ajustée par GitLab :** <XS/S/M/L/XL> (depuis <estimation initiale>)

**Facteurs d'ajustement :**
- <raison 1>
- <raison 2>

**Points d'attention :**
- <blockers / questions ouvertes / dépendances détectées>
```

**Si aucune donnée GitLab :** ne pas inclure cette section.

### Gestion des erreurs

| Erreur | Comportement |
|---|---|
| Token invalide / expiré | Afficher : `⚠️ Token GitLab invalide — vérifier : oc gitlab status` |
| Ticket non trouvé (404) | Mentionner dans le rapport, continuer sans données GitLab |
| Pas de credentials configurés | Skiper silencieusement, continuer l'estimation sans GitLab |
