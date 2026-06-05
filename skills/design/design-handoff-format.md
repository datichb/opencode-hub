---
name: design-handoff-format
description: Source de vérité pour le format de retour des agents ux-designer et ui-designer vers l'orchestrator. Définit le bloc structuré à produire quand un agent design termine sa spec et est invoqué depuis l'orchestrator. Injecté dans ux-designer, ui-designer et orchestrator pour garantir que le producteur et le consommateur partagent le même contrat.
---

# Skill — Format de handoff design → orchestrator

Ce skill est la **source de vérité** pour le format de retour des agents design vers l'orchestrator.
Il est injecté dans `ux-designer`, `ui-designer` et `orchestrator` — producteur et consommateur partagent le même contrat.

---

## Quand produire ce bloc

### Détection du contexte d'invocation

Au démarrage, détecter si le prompt contient `[CONTEXTE] Invoqué depuis l'orchestrateur feature`. Si oui :
- Mémoriser **CONTEXTE = orchestrateur_feature** pour toute la session
- Ne jamais utiliser l'outil `question` — toute interaction passe par les blocs structurés
- En fin de session : produire la spec complète + le bloc `## Retour vers orchestrator`
- En cas de clarification critique nécessaire en cours de session : produire `## Retour intermédiaire vers orchestrateur` + `## Question pour l'orchestrateur` et **terminer la session**

Sinon (standalone ou depuis `planner`) :
- Utiliser l'outil `question` normalement
- Produire la spec sans le bloc `## Retour vers orchestrator`

---

Quand CONTEXTE = orchestrateur_feature, produire dans cet ordre :

1. **La spec complète** — user flows intégraux avec tous les états, wireframes textuels, tokens, composants, critères d'acceptance UX/UI. **Cette spec doit être produite dans sa totalité, jamais résumée, même si elle est longue.** Elle est produite après la validation explicite de l'utilisateur.
2. **Le bloc `## Retour vers orchestrator`** défini ci-dessous — synthèse structurée avec les métadonnées, contraintes et statut.

En standalone ou quand invoqué depuis le `planner`, la spec est produite sans ce bloc.

> **Autocontrôle obligatoire avant de produire ce bloc :**
> « Ai-je produit la spec complète avant ce bloc ? Si non, la produire d'abord. »

---

## Format du bloc `## Retour vers orchestrator`

```
---

## Retour vers orchestrator

**Agent :** ux-designer | ui-designer
**Ticket :** #<ID> — <titre>

### Spec produite
Voir spec complète ci-dessus — jamais résumée ni reproduite ici.

### Contraintes d'implémentation
- <contrainte 1 — ex : responsive mobile-first obligatoire, ratio de contraste WCAG AA minimum, etc.>
- <contrainte 2>
<"Aucune" si pas de contrainte spécifique identifiée>

### Points ouverts
- <question en suspens 1 — ce qui n'a pas été tranché et nécessite une décision avant ou pendant l'implémentation>
- <question en suspens 2>
<"Aucun" si tous les points ont été tranchés>

### Alternatives écartées
- `<alternative 1>` : <pourquoi écartée>
- `<alternative 2>` : <pourquoi écartée>
<"Aucune" si aucune alternative notable n'a été explorée>

### Statut
`spec-complète` | `spec-partielle` | `bloqué`
```

**Définitions du statut :**

| Statut | Condition |
|--------|-----------|
| `spec-complète` | Spec validée par l'utilisateur, tous les éléments nécessaires à l'implémentation sont présents |
| `spec-partielle` | Spec validée mais avec des points ouverts qui devront être résolus pendant l'implémentation |
| `bloqué` | Spec non finalisée — un blocage empêche de produire une spec exploitable |

---

## Règles pour le producteur (ux-designer / ui-designer)

- **Toujours produire la spec complète** avant ce bloc — jamais résumée ni abrégée. La spec est obligatoire dans tous les cas.
- **Toujours produire ce bloc** à la suite de la spec, même si le statut est `bloqué`
- **Le champ `### Spec produite`** dans le bloc pointe vers la spec ci-dessus — ne pas la reproduire dans le bloc
- Le bloc est produit **après** la validation explicite de l'utilisateur, pas avant
- Si invoqué depuis l'orchestrator via `Task`, utiliser ce format à la place du `bd close` habituel
- Le `task_id` n'est pas requis dans ce format (contrairement au format `orchestrator-dev`) — l'orchestrator reprend naturellement après réception

> ❌ Ne jamais produire le bloc handoff sans avoir d'abord produit la spec complète.
> ❌ Ne jamais résumer la spec — le bloc est une synthèse de métadonnées, pas un substitut à la spec.

---

## Bloc `## Retour intermédiaire vers orchestrateur` (clarification en cours de session)

Produit quand une **clarification critique** est nécessaire en cours de session (CONTEXTE = orchestrateur_feature uniquement) — ex : aucun design system détecté, informations utilisateur insuffisantes, décision de direction artistique bloquante.

> ⚠️ Réserver aux vrais blockers. Formuler une hypothèse documentée et continuer si possible.

```markdown
## Retour intermédiaire vers orchestrateur

**Agent :** ux-designer | ui-designer
**Phase :** Clarification en cours de session
**task_id :** <sessionID courant>

### Ce qui a été exploré jusqu'ici
- <observation 1>
- <observation 2>

### Problème détecté
<Description précise de la clarification nécessaire>

### Impact
<Conséquence sur la spec si on continue sans cette information>

### Hypothèse possible
<Formulation de l'hypothèse si l'utilisateur préfère continuer>
```

---

## Bloc `## Question pour l'orchestrateur` (clarification en cours de session)

Accompagne toujours un `## Retour intermédiaire vers orchestrateur`.

```markdown
## Question pour l'orchestrateur

**Phase :** Clarification design
**task_id :** <sessionID courant>

**Contexte :** <Description du problème et de son impact>

**Question :** <Question précise>

**Options :**
- `<label-a>` — <description>
- `<label-b>` — <description>

**Instruction de reprise :** "Réponse clarification design : [option]. [Information si applicable]. Reprendre la production de la spec."
```

---

## Règles pour le consommateur (orchestrator)

### À la réception du retour d'un agent design

⚠️ **RAPPEL IMPÉRATIF** : La spec et le bloc doivent être affichés EN TEXTE dans la discussion AVANT d'appeler `question`.

> Ce protocole est défini dans le skill `posture/retranscription-coordinateur` (injecté dans orchestrator) — s'y référer pour le template exact de retranscription.

**Séquence obligatoire (ne jamais inverser) :**

1. **Afficher la spec complète dans le texte de la discussion** (ne pas inclure dans l'outil `question`) — ne jamais résumer. Cette spec contient les user flows intégraux avec tous les états, wireframes textuels, tokens, composants, critères d'acceptance UX/UI.

2. **Afficher l'intégralité du bloc `## Retour vers orchestrator` dans le texte de la discussion** (ne pas inclure dans l'outil `question`) — vérifier que tous les champs obligatoires sont présents.

3. **Vérifier la présence de tous les champs obligatoires** : `Contraintes d'implémentation`, `Points ouverts`, `Statut`.
   - Si l'un de ces champs est absent ou vide sans mention explicite (`"Aucun"` / `"Aucune"`) → demander explicitement à l'agent design de compléter avant de continuer.

4. **Si la spec complète est absente** (le bloc handoff est présent sans spec préalable) → demander explicitement à l'agent design de produire la spec complète avant de continuer.

5. **Intégrer les `### Contraintes d'implémentation`** dans le prompt de délégation à `orchestrator-dev` lors de la phase d'implémentation.

6. **Signaler les `### Points ouverts`** à l'utilisateur lors du CP-spec pour décision avant implémentation.

7. **Utiliser le `### Statut`** pour conditionner la suite :
   - `spec-complète` ou `spec-partielle` → continuer vers CP-spec normalement
   - `bloqué` → ne pas router vers orchestrator-dev — demander à l'utilisateur comment débloquer

> ❌ Ne jamais construire le CP-spec sans avoir d'abord affiché la spec ET le bloc en texte
> ❌ Ne jamais résumer la spec — l'afficher intégralement
> ❌ Ne jamais accepter un bloc handoff sans spec préalable — les deux sont obligatoires
> ❌ Ne jamais appeler `question` avant d'avoir affiché le contenu

**Exemple de retranscription correcte :** Voir skill `posture/retranscription-coordinateur` section "Exemples".
