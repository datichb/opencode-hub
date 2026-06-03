---
name: gitlab-planner-protocol
description: Protocole d'intégration GitLab pour l'agent Planner — lecture du ticket source, exploitation des labels et milestones pour contextualiser la décomposition en sous-tickets
---

# Skill — GitLab Planner Protocol (v1)

## Rôle

Ce skill enrichit la Phase 1 (Exploration contextuelle) du Planner avec les données GitLab pour ancrer la décomposition dans le contexte réel du projet : ticket source, priorité, contraintes de sprint.

## Phase 1.2bis — Exploration GitLab (optionnelle)

Cette phase se place **après Phase 1.2 (Codebase)** et **avant Phase 2 (Questions)**.

### Déclencheur

Lancer Phase 1.2bis si **au moins un** de ces critères :
- L'utilisateur a fourni un numéro de ticket GitLab (ex : `#42`, `!15`)
- L'utilisateur a mentionné un projet GitLab (`mon-groupe/mon-projet`)
- La feature est décrite comme "ticket X" ou "issue X"

### Workflow

#### Étape 1 : Lire le ticket source

Si un `issue_iid` est fourni :

```
Utiliser l'outil : get_gitlab_issue
Arguments : project_path, issue_iid
→ Obtenir : titre, description complète, labels, milestone, assignés, commentaires
```

**Exploiter le ticket pour :**
- Utiliser la **description** comme cahier des charges initial
- Extraire les **critères d'acceptation** si présents
- Identifier les **contraintes** mentionnées dans les commentaires
- Récupérer le **milestone** pour situer la priorité temporelle

**Si ticket non trouvé (404) :**
- Mentionner dans le récap : "Ticket #N introuvable ou accès refusé"
- Continuer avec les informations fournies par l'utilisateur

#### Étape 2 : Comprendre le contexte projet (si première utilisation)

Si les labels ou milestones ne sont pas encore connus :

```
Utiliser l'outil : list_gitlab_labels
Argument : project_path
→ Obtenir : taxonomie complète des labels (types, priorités, domaines)

Utiliser l'outil : list_gitlab_milestones
Arguments : project_path, state: "active"
→ Obtenir : sprints en cours, dates de livraison
```

**Exploiter pour :**
- Comprendre la nomenclature de priorité du projet (`priority::high`, `P0`, etc.)
- Identifier le sprint actuel et sa date de fin
- Évaluer l'urgence de la feature

#### Étape 3 : Vérifier les tickets liés (optionnel)

Si la feature semble liée à d'autres tickets existants :

```
Utiliser l'outil : list_gitlab_issues
Arguments : project_path, state: "opened", search: <mots-clés de la feature>
→ Obtenir : tickets en cours sur le même périmètre
```

**Exploiter pour :**
- Détecter des **dépendances** ou des **doublons**
- Identifier des tickets **bloquants** à mentionner dans le plan
- Éviter de re-décomposer un travail déjà en cours

#### Étape 4 : Enrichissement du récap Phase 1

Ajouter cette section dans le récap si données GitLab disponibles :

```markdown
## 🦊 Contexte GitLab

**Ticket source :** #<iid> — <titre>
**URL :** <web_url>
**Labels :** <labels>
**Milestone :** <titre> (échéance : <date>)
**Priorité détectée :** <haute/moyenne/normale — déduite des labels>

**Critères d'acceptation extraits :**
<liste extraite de la description ou des commentaires>

**Tickets liés détectés :**
- #<iid> — <titre> [<état>]
```

**Si aucune donnée GitLab :** ne pas inclure cette section.

### Impact sur la décomposition

Utiliser les données GitLab pour ajuster le plan :

| Contexte GitLab | Ajustement |
|---|---|
| Milestone < 7 jours | Réduire le scope, prioriser le MVP |
| Labels `priority::critical` ou `P0` | Mettre en avant dans les tickets Beads |
| Commentaires avec blockers | Ajouter ticket de levée de blocage |
| Description avec ACs détaillés | Pré-remplir les critères d'acceptation Beads |
| Tickets liés ouverts | Ajouter section dépendances dans le plan |

### Gestion des erreurs

| Erreur | Comportement |
|---|---|
| Token invalide / expiré | Afficher : `⚠️ Token GitLab invalide — vérifier : oc gitlab status` |
| Projet non trouvé (404) | Afficher : `⚠️ Projet introuvable — vérifier le chemin : mon-groupe/mon-projet` |
| Pas de credentials | Skiper silencieusement Phase 1.2bis, continuer sans données GitLab |
