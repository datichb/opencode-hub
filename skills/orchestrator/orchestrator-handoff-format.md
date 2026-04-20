---
name: orchestrator-handoff-format
description: Source de vérité unique pour le format du bloc de retour entre orchestrator-dev et orchestrator — structure exacte, champs obligatoires, et définitions des statuts globaux (succès/partiel/bloqué). Injecté dans orchestrator et orchestrator-dev pour garantir que le producteur et le consommateur partagent le même contrat de communication.
---

# Skill — Format de handoff orchestrator-dev → orchestrator

Ce skill est la **source de vérité unique** pour le format du bloc de retour.
Il est injecté dans `orchestrator` et `orchestrator-dev` — le producteur et le consommateur partagent ainsi le même contrat, sans risque de désynchro.

---

## Format du bloc `## Retour vers orchestrator`

Quand `orchestrator-dev` est invoqué depuis l'`orchestrator`, il **doit** produire ce bloc à la fin de son récap global :

```
---

## Retour vers orchestrator

**Tickets traités :** [bd-XX ✅, bd-YY ✅, ...]
**Tickets ignorés :** [bd-ZZ ⏭️, ...]
**Points d'attention :**
- <point 1>
- <point 2>
**Statut global :** succès | partiel | bloqué
```

Ce bloc est **obligatoire** quand invoqué depuis l'orchestrateur feature. Il n'est pas produit quand invoqué standalone.

---

## Définitions du statut global

| Statut | Condition |
|--------|-----------|
| `succès` | Tous les tickets traités ont été commités sans blocage persistant |
| `partiel` | Au moins un ticket ignoré ou bloqué après 3 cycles de review |
| `bloqué` | Au moins un ticket est resté bloqué et nécessite une intervention manuelle |

---

## Règles pour l'orchestrator (consommateur)

- Ce format structuré est requis pour construire le CP-feature.
- Si le récap reçu ne contient pas ces champs, les demander explicitement à `orchestrator-dev` avant de continuer.
- Ne jamais construire le CP-feature à partir d'un récap incomplet ou ambigu.
