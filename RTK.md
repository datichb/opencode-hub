
---

## Session 2026-05-23 — Refonte workflow planner

### Problème résolu

**Incohérence sémantique majeure** entre 3 workflows coexistant sans coordination dans le planner :
- Workflow agent planner.md : PHASE 0 → 1 → [1.5] → 2 → 3 → [3.5] → 4
- Workflow analysis-workflow : Phase 0 → 1 → 2 → 3 → 4 → 5
- Confusion terminologique : "Phase 2" avait 3 significations différentes selon le contexte

### Solution appliquée : **Option E — Refonte native intégrée**

Création d'un **workflow planner unifié** (`skills/planning/planner-workflow.md`, 1541 lignes) qui :
- ✅ Fusionne les meilleurs aspects des deux workflows existants
- ✅ Résout les conflits sémantiques (Phase 0-6 unifié et cohérent)
- ✅ Préserve les spécificités métier du planner (délégation design Phase 1.5, création Beads Phase 5, ai-delegated Phase 5.5)
- ✅ Hérite des récaps et validations systématiques d'analysis-workflow
- ✅ Réutilise les principes des templates et questions existants (adaptés au planner)
- ✅ Maintient le format handoff pour l'orchestrateur

### Workflow planner final (7 phases)

```
Phase 0 — Vérification des prérequis
         ↓
Phase 1 — Exploration contextuelle (bd list, codebase, signaux UX/UI)
         ↓
Phase 1.5 — Délégation design (optionnelle si signaux détectés)
           ↓
Phase 2 — Questions complémentaires (métier, technique, design)
         ↓
Phase 3 — Analyse approfondie (Plan hiérarchique)
         ↓
Phase 4 — Détection des cas particuliers (doublons, tickets trop gros, dépendances circulaires)
         ↓
Phase 5 — Production du livrable (Création Beads avec enrichissement complet)
         ↓
Phase 5.5 — Délégation ai-delegated (optionnelle)
           ↓
Phase 6 — Vérification finale (+ bloc handoff si invoqué depuis orchestrateur)
```

### Innovations clés

#### 1. Format de retour — RÈGLE ABSOLUE
À chaque fin de phase et à chaque pause inter-étape :
1. **TOUJOURS produire le récap en texte clair dans la discussion**
2. **PUIS appeler l'outil `question` pour la validation**

> ❌ JAMAIS : appeler `question` comme première action
> ✅ TOUJOURS : afficher le récap en texte → puis appeler `question`

Cette règle garantit que :
- L'utilisateur voit toujours le contexte complet avant chaque question
- L'orchestrateur reçoit le récap complet pour l'afficher dans son fil
- Pas de perte d'information même en invocation imbriquée

#### 2. Phases itératives avec retour en arrière
- Retour en arrière possible entre phases (ex : Phase 3 → Phase 1 si nouvelles infos)
- Compteur d'itérations (max 3 par phase) pour éviter les boucles infinies
- À la 3ème itération : proposer de forcer le passage à la suite

#### 3. Contexte d'invocation explicite
- Détection du marqueur `[CONTEXTE] Invoqué depuis l'orchestrateur feature`
- Si détecté : produire le bloc `## Retour vers orchestrator` en fin de Phase 6
- Sinon (standalone) : produire uniquement le récap complet

### Fichiers modifiés

| Fichier | Action | Avant | Après |
|---------|--------|-------|-------|
| `agents/planning/planner.md` | Réécrit | 91 lignes | 143 lignes |
| `skills/planning/planner-workflow.md` | Créé | n/a | 1541 lignes (53.8K) |
| `skills/planning/planner.md` | Renommé → planner-legacy.md | 980 lignes | (archivé) |

### Skills injectés dans l'agent planner

**Avant :**
```yaml
skills: [
  developer/beads-plan,
  planning/planner,
  posture/expert-posture,
  posture/tool-question,
  planning/planner-handoff-format,
  analysis/analysis-workflow,
  analysis/analysis-templates,
  analysis/analysis-questions
]
```

**Après :**
```yaml
skills: [
  developer/beads-plan,
  planning/planner-workflow,        # ← nouveau skill unique
  planning/planner-handoff-format,  # ← conservé tel quel
  posture/expert-posture,
  posture/tool-question
]
```

Les 3 skills `analysis/*` ont été **retirés du planner** — ils restent disponibles pour `onboarder`, `debugger`, `auditor-*` qui en ont besoin.

### Comparaison avec les options écartées

| Option | Avantage | Inconvénient | Décision |
|--------|----------|--------------|----------|
| A. Réécriture complète | Clarté maximale | Risque régression, effort très élevé | ❌ Trop invasif |
| B. Bridge documentation | Rapide | Ne résout pas l'incohérence fondamentale | ❌ Rustine insuffisante |
| C. Skill bridge séparé | Isolation propre | Ajoute une couche d'indirection | ❌ Complexité inutile |
| D. Désactiver analysis-workflow | Simple | Perd valeur des récaps itératifs | ❌ Régression fonctionnelle |
| **E. Refonte native (retenue)** | **Résout l'incohérence + préserve valeur** | **Effort modéré mais ciblé** | ✅ **Optimal** |

### Bénéfices

✅ **Cohérence sémantique** : Phase 0-6 unifié, terminologie claire et sans ambiguïté
✅ **Récaps et validations systématiques** : hérités d'analysis-workflow, appliqués à chaque phase
✅ **Phases itératives** : possibilité de revenir en arrière, compteur 3 max
✅ **Spécificités préservées** : Phase 1.5 (design) et 5.5 (ai-delegated) intégrées naturellement
✅ **Templates métier intégrés** : création Beads avec enrichissement complet (description, acceptance, notes, design)
✅ **Format handoff maintenu** : compatibilité avec l'orchestrateur feature
✅ **Visibilité maximale** : récaps en texte clair avant chaque question, utilisateur et orchestrateur informés

### Prochaines étapes

1. ✅ Créer `skills/planning/planner-workflow.md`
2. ✅ Adapter `agents/planning/planner.md`
3. ✅ Archiver `skills/planning/planner.md` → `planner-legacy.md`
4. ⏹️ Vérifier cohérence onboarder/debugger/auditor avec analysis-workflow (même méthodologie)
5. ✅ Documenter dans RTK.md

### Tests de validation recommandés

- [ ] Invoquer le planner en standalone → vérifier que les récaps apparaissent en texte avant les questions
- [ ] Invoquer le planner depuis l'orchestrateur → vérifier le bloc `## Retour vers orchestrator` en fin de Phase 6
- [ ] Déclencher Phase 1.5 (signaux UX/UI) → vérifier la délégation design
- [ ] Déclencher Phase 5.5 (ai-delegated) → vérifier la validation avant ajout du label
- [ ] Tester un retour en arrière (ex : Phase 3 → Phase 1) → vérifier le compteur d'itérations
- [ ] Tester une pause inter-étape (info manquante en Phase 1) → vérifier le format contexte + question

### Notes de conception

#### Pourquoi garder Phase 1.5 et 5.5 ?
Ces phases optionnelles sont des **spécificités métier du planner** non généralisables aux autres agents d'analyse :
- **Phase 1.5** : délégation UX/UI avant planification (propre au planner, pas applicable à auditor/onboarder/debugger)
- **Phase 5.5** : délégation ai-delegated après création (gestion des permissions, propre au planner)

Elles ne cassent pas la linéarité du workflow car elles sont **optionnelles et conditionnelles**.

#### Pourquoi 7 phases au lieu de 6 ?
Le planner a besoin de 2 phases de production (Phase 3 : plan hiérarchique + Phase 5 : création Beads), contrairement aux autres agents qui n'ont qu'une seule phase de production de livrable.

#### Pourquoi ne pas réutiliser analysis-workflow tel quel ?
`analysis-workflow` est **trop générique** pour le planner. Il faudrait :
- Ajouter des conditions partout pour gérer Phase 1.5 et 5.5
- Adapter Phase 3 et Phase 5 qui ont des sémantiques différentes
- Gérer le cas particulier de la création effective dans Beads (phase d'écriture, pas juste analyse)

La refonte native évite cette complexité et produit un workflow **cohérent et maintenable**.

---

---

## Session 2026-05-23 — Refonte workflow onboarder

### Problème résolu

**Workflow linéaire non structuré** avec 11 étapes (ÉTAPE 1-7 + pauses) sans récaps systématiques :
- Pas de récap entre les étapes
- Questions de clarification non structurées
- Pas de phase de détection des cas particuliers
- Pas de spécificités d'invocation définies (standalone vs orchestrateur)

### Solution appliquée : **Refonte native intégrée**

Création d'un **workflow onboarder unifié** (`skills/planning/onboarder-workflow.md`, 1375 lignes) qui :
- ✅ Intègre les meilleurs aspects d'analysis-workflow (récaps systématiques, questions validées, phases itératives)
- ✅ Fusionne `project-discovery.md` (396 lignes) et `project-conventions.md` (362 lignes) en un workflow cohérent
- ✅ Ajoute Phase 4 (Détection des cas particuliers) — absente du workflow original
- ✅ Définit les spécificités d'invocation (standalone vs orchestrateur avec bloc handoff)
- ✅ Maintient les spécificités métier (3 fichiers à écrire, pauses fichiers existants, carte agents)
- ✅ Format de retour : récap en texte clair avant chaque question

### Workflow onboarder final (6 phases)

```
Phase 0 — Vérification des prérequis
         (projet accessible, fichiers structurants détectés)
         ↓
Phase 1 — Exploration contextuelle
         (stack → profil → exploration adaptative selon profil → tickets Beads + ADRs)
         ↓
Phase 2 — Questions complémentaires
         (stratégie projet, conventions ambiguës, zones d'ombre)
         ↓
Phase 3 — Analyse approfondie : Rapport de contexte
         (stack, architecture, patterns, points d'attention, carte agents priorisée)
         ↓
Phase 4 — Détection des cas particuliers
         (incohérences stack/conventions, CVE, dette masquée, architecture hybride)
         ↓
Phase 5 — Production du livrable
         (ONBOARDING.md + CONVENTIONS.md + projects.md optionnel + bloc handoff si orchestrateur)
```

### Innovations clés

#### 1. Format de retour — RÈGLE ABSOLUE
À chaque fin de phase :
1. **TOUJOURS produire le récap en texte clair dans la discussion**
2. **PUIS appeler l'outil `question` pour la validation**

> ❌ JAMAIS : appeler `question` comme première action
> ✅ TOUJOURS : afficher le récap en texte → puis appeler `question`

#### 2. Phase 4 ajoutée — Détection des cas particuliers
Absente du workflow original, cette phase vérifie :
- Incohérences stack/conventions (config dit X, code fait Y)
- Dépendances avec CVE connus (npm audit / pip check)
- Conventions contradictoires (plusieurs conventions de nommage sans règle)
- Architecture hybride non documentée (mélange MVC + DDD + anémique)
- Dette technique masquée (code mort, imports circulaires)
- Tests flaky (signalés dans logs CI)

#### 3. Exploration adaptative structurée
7 profils d'exploration définis avec fichiers spécifiques à lire :
- Frontend Vue.js / React / Angular
- Backend Node.js / Python / PHP / Ruby
- API REST / GraphQL
- Data / ML (dbt, Airflow, notebooks)
- DevOps / Platform (Docker, Terraform, K8s)
- Mobile (React Native, Flutter)
- Complément transversal (tous profils)

#### 4. Fusion CONVENTIONS.md dans le workflow
Le protocole de détection et le format de CONVENTIONS.md (issu de `project-conventions.md`) sont intégrés directement en Phase 5.2 :
- 9 sources de conventions détectées
- Format structuré en 9 catégories
- Règles de conduite (baser sur fichiers lus, citer sources, signaler incohérences)

#### 5. Carte des agents priorisée
3 niveaux de recommandation basés sur observations concrètes :
- **Prioritaires** : activés par points d'attention 🔴/🟠 (risques détectés)
- **Recommandés** : activés par la stack détectée
- **Optionnels** : selon ambitions projet

### Fichiers modifiés

| Fichier | Action | Avant | Après |
|---------|--------|-------|-------|
| `agents/planning/onboarder.md` | Réécrit | 193 lignes | 143 lignes |
| `skills/planning/onboarder-workflow.md` | Créé | n/a | 1375 lignes (46.6K) |
| `skills/planning/project-discovery.md` | Renommé → project-discovery-legacy.md | 396 lignes | (archivé) |
| `skills/planning/project-conventions.md` | Renommé → project-conventions-legacy.md | 362 lignes | (archivé) |

### Skills injectés dans l'agent onboarder

**Avant :**
```yaml
skills: [
  planning/project-discovery,
  planning/project-conventions,
  posture/expert-posture,
  posture/tool-question,
  developer/beads-plan,
  developer/dev-standards-git,
  planning/onboarder-handoff-format,
  analysis/analysis-workflow,
  analysis/analysis-templates,
  analysis/analysis-questions
]
```

**Après :**
```yaml
skills: [
  planning/onboarder-workflow,        # ← nouveau skill unique
  planning/onboarder-handoff-format,  # ← conservé tel quel
  posture/expert-posture,
  posture/tool-question,
  developer/beads-plan,
  developer/dev-standards-git
]
```

Les 2 skills `project-discovery` et `project-conventions` ont été **fusionnés** dans `onboarder-workflow`.
Les 3 skills `analysis/*` ont été **retirés de l'onboarder** (appliqués via la structure du workflow).

### Comparaison avec le planner

| Aspect | Planner | Onboarder |
|--------|---------|-----------|
| **Phases** | 7 (0 → 1 → 1.5 → 2 → 3 → 4 → 5 → 5.5 → 6) | 6 (0 → 1 → 2 → 3 → 4 → 5) |
| **Phases optionnelles** | 2 (1.5 design, 5.5 ai-delegated) | 0 (toutes obligatoires) |
| **Phases d'écriture** | 2 (3 plan, 5 création Beads) | 1 (5 fichiers) |
| **Fichiers produits** | Tickets Beads | ONBOARDING.md + CONVENTIONS.md + projects.md opt. |
| **Création** | Oui (tickets, epics, labels, dépendances) | Non (lecture seule sauf fichiers rapports) |
| **Délégation** | Oui (ux-designer, ui-designer, ai-delegated) | Non (suggère agents, ne délègue pas) |
| **Complexité** | Élevée (création interactive, dépendances, TDD) | Moyenne (exploration, détection, génération) |

### Bénéfices

✅ **Cohérence sémantique** : Phase 0-5 unifié, terminologie claire
✅ **Récaps et validations systématiques** : hérités d'analysis-workflow, appliqués à chaque phase
✅ **Phases itératives** : possibilité de revenir en arrière, compteur 3 max
✅ **Phase 4 ajoutée** : détection des cas particuliers (incohérences, CVE, dette masquée)
✅ **Fusion méthodologique** : project-discovery + project-conventions dans un workflow cohérent
✅ **Format handoff maintenu** : compatibilité avec l'orchestrateur feature
✅ **Visibilité maximale** : récaps en texte clair avant chaque question
✅ **Exploration adaptative structurée** : 7 profils avec fichiers spécifiques par profil
✅ **Carte agents priorisée** : 3 niveaux (prioritaires/recommandés/optionnels) basés sur observations

### Prochaines étapes

1. ✅ Analyser onboarder + project-discovery + project-conventions
2. ✅ Créer `skills/planning/onboarder-workflow.md`
3. ✅ Adapter `agents/planning/onboarder.md`
4. ✅ Archiver `project-discovery.md` et `project-conventions.md` → *-legacy.md
5. ✅ Documenter dans RTK.md
6. ⏹️ Appliquer la même méthodologie au debugger et aux auditor-*

### Tests de validation recommandés

- [ ] Invoquer l'onboarder en standalone → vérifier récaps en texte avant questions
- [ ] Invoquer l'onboarder depuis l'orchestrateur → vérifier bloc `## Retour vers orchestrator` en Phase 5
- [ ] Tester Phase 4 (cas particuliers) → vérifier détection incohérences
- [ ] Tester retour en arrière (Phase 3 → Phase 1) → vérifier compteur d'itérations
- [ ] Tester pause fichier existant (ONBOARDING.md déjà présent) → vérifier question écraser/conserver
- [ ] Tester exploration adaptative → vérifier profils (frontend, backend, data, mobile, etc.)

### Notes de conception

#### Pourquoi 6 phases au lieu de 7 comme le planner ?
L'onboarder n'a pas besoin de :
- **Phase 1.5 (design)** : pas de délégation UX/UI — l'onboarder suggère des agents mais ne les invoque pas
- **Phase 5.5 (ai-delegated)** : pas de gestion de permissions — l'onboarder ne crée pas de tickets

#### Pourquoi fusionner project-discovery et project-conventions ?
Ces deux skills étaient **complémentaires et séquentiels** :
- `project-discovery` : exploration + détection stack + rapport
- `project-conventions` : détection conventions + génération CONVENTIONS.md

Les fusionner dans un workflow unifié évite la duplication et clarifie la séquence :
- Phase 1 : exploration (ex-project-discovery ÉTAPE 1-3)
- Phase 3 : rapport (ex-project-discovery ÉTAPE 4)
- Phase 5.2 : CONVENTIONS.md (ex-project-conventions intégral)

#### Pourquoi garder project-discovery-legacy et project-conventions-legacy ?
Référence historique si besoin de retrouver une logique spécifique non migrée.
À supprimer après validation complète du nouveau workflow.

---

---

## ✅ Refonte Debugger (2026-05-23)

### Problème initial
L'agent debugger utilisait un skill `debug-protocol.md` (302 lignes) qui documentait une méthodologie de diagnostic en 4 étapes (reproduction, isolation, identification, hypothèse) **sans intégration avec analysis-workflow** → pas de récaps systématiques, pas de questions obligatoires, pas de phases itératives.

### Solution retenue
Refonte native intégrée : **création de `debugger-workflow.md`** (855 lignes) qui fusionne la méthodologie de diagnostic existante (4 étapes) dans un workflow structuré en 6 phases avec récaps systématiques et questions obligatoires.

### Workflow debugger final

```
Phase 0 — Vérification des prérequis (artefacts)
         ↓
Phase 1 — Exploration contextuelle (CONVENTIONS.md, ticket Beads, fichiers impliqués)
         ↓
Phase 2 — Questions complémentaires (artefacts manquants) [optionnelle]
         ↓
Phase 3 — Analyse approfondie : Diagnostic en 4 étapes
         │ 3.1 Reproduction (comportement observé vs attendu, conditions)
         │ 3.2 Isolation (couche concernée, point d'entrée)
         │ 3.3 Identification (lecture stacktrace/logs/réseau)
         │ 3.4 Hypothèse et vérification (probabilités graduées)
         ↓
Phase 4 — Détection des cas particuliers
         │ ✓ Race condition / bug intermittent
         │ ✓ Problème d'environnement (dev/staging/prod)
         │ ✓ Données spécifiques (edge cases, null, caractères spéciaux)
         │ ✓ Configuration (env vars, feature flags)
         │ ✓ Dépendances externes (API, BDD, cache)
         │ ✓ Régression (commit récent, déploiement, migration)
         ↓
Phase 5 — Production du livrable (Rapport + ticket Beads)
```

**Chaque phase se termine par :**
1. Récap affiché en texte clair dans la discussion
2. Question de validation via l'outil `question`

**Règle absolue :** toujours afficher le récap en texte AVANT d'appeler l'outil `question`.

### Innovations spécifiques debugger

#### 1. Vérification artefacts (Phase 0)
**Problème :** diagnostiquer avec des informations insuffisantes produit un rapport peu fiable
**Solution :** vérification obligatoire en Phase 0 avec pause si artefacts insuffisants
- Artefacts suffisants : stacktrace complète, logs avec timestamp, description précise comportement observé/attendu
- Artefacts insuffisants → question regroupée demandant toutes les infos manquantes
- Option "Continuer quand même" → diagnostic partiel assumé

#### 2. Méthodologie diagnostic intégrée (Phase 3)
**Problème :** l'ancien `debug-protocol.md` documentait les 4 étapes sans les lier à un workflow global
**Solution :** les 4 étapes (reproduction, isolation, identification, hypothèse) sont maintenant intégrées en **Phase 3** avec :
- Guides de lecture détaillés (stacktrace, logs applicatifs, logs réseau)
- Formulation en hypothèses graduées (haute/moyenne/faible probabilité)
- Éléments d'étayage systématiques + actions pour confirmer

#### 3. Détection cas particuliers (Phase 4)
**Problème :** les diagnostics rataient souvent les race conditions, bugs environnement-spécifiques, edge cases
**Solution :** Phase 4 dédiée avec checklist 6 points :
- Bug intermittent / race condition
- Problème d'environnement (dev/staging/prod)
- Données spécifiques (edge cases, null, caractères spéciaux)
- Configuration (env vars, feature flags)
- Dépendances externes (API, BDD, cache)
- Régression (commit récent, déploiement, migration)

#### 4. Format de retour selon contexte
**Standalone :**
- Rapport de diagnostic complet uniquement
- Pas de bloc `## Retour vers orchestrator`

**Depuis orchestrateur :**
- Rapport de diagnostic complet (texte narratif)
- Bloc `## Retour vers orchestrator` (résumé structuré actionnable)
- Autocontrôle avant production bloc : « Ai-je produit le rapport complet avant ce bloc ? »

### Résultats

| Métrique | Avant | Après |
|----------|-------|-------|
| **Agent** | 127 lignes | 134 lignes (+7, +5%) |
| **Workflow** | 302 lignes (`debug-protocol.md`) | 855 lignes (`debugger-workflow.md`) (+553, +183%) |
| **Skills référencés** | 1 (`debug-protocol`) | 2 (`debugger-workflow` + `debugger-handoff-format`) |
| **Phases** | 5 étapes linéaires | 6 phases itératives avec récaps systématiques |
| **Questions obligatoires** | ❌ absentes | ✅ 1 par phase (6 questions) |
| **Retours en arrière** | ❌ non prévus | ✅ possible entre toutes phases |
| **Détection artefacts insuffisants** | ❌ non gérée | ✅ Phase 0 dédiée avec pause |
| **Détection cas particuliers** | ❌ non structurée | ✅ Phase 4 avec checklist 6 points |
| **Formulation hypothèses** | Texte libre | Hypothèses graduées (haute/moyenne/faible probabilité) avec éléments d'étayage |
| **Format de retour** | Rapport uniquement | Rapport + bloc handoff si invoqué depuis orchestrateur |

### Comparaison avec planner et onboarder

| Caractéristique | Planner | Onboarder | Debugger |
|-----------------|---------|-----------|----------|
| **Phases** | 7 (0→1→1.5→2→3→4→5→5.5→6) | 6 (0→1→2→3→4→5) | 6 (0→1→2→3→4→5) |
| **Phase 0** | Contexte projet | Contexte projet | **Vérification artefacts** |
| **Phase 1** | Exploration + signaux UX/UI | Exploration adaptative 7 profils | **Exploration contextuelle** |
| **Phase optionnelle** | 1.5 (délégation design) | — | 2 (questions artefacts) |
| **Phase métier** | 3 (plan hiérarchique) | 3 (rapport contexte) | 3 (diagnostic 4 étapes) |
| **Phase cas particuliers** | 4 (tickets mixtes, ambiguïtés) | 4 (CVE, dette masquée) | 4 (race conditions, edge cases) |
| **Phase finale** | 6 (vérification + handoff) | 5 (fichiers + handoff) | 5 (rapport + ticket Beads) |
| **Itérations max** | 3 par phase | 3 par phase | 3 par phase |
| **Délégations** | ✅ ux-designer, ui-designer | ❌ aucune | ❌ aucune |
| **Écriture fichiers** | ❌ non | ✅ ONBOARDING.md, CONVENTIONS.md | ❌ non |
| **Création tickets** | ✅ bd create (multiples) | ❌ non | ✅ bd create (1 ticket) |
| **Label spécifique** | `ai-delegated` (Phase 5.5) | — | `from-diagnostic` |

### Fichiers modifiés

```
Créés :
+ skills/quality/debugger-workflow.md                  855 lignes

Refactorés :
± agents/quality/debugger.md                           127 → 134 lignes (+7)

Archivés :
→ skills/debugger/debug-protocol.md
→ skills/debugger/debug-protocol-legacy.md             302 lignes
```

### Prochaines étapes

- ✅ **Debugger refactoré** : workflow unifié 6 phases (0→1→2→3→4→5) intégrant méthodologie diagnostic 4 étapes
- ⏭️ Vérifier cohérence auditor-* avec analysis-workflow (7 agents à auditer)
- ⏭️ Documenter la gouvernance des workflows (quand créer un workflow unifié, quand utiliser analysis-workflow directement)

---

## ✅ Refonte Auditor Coordinateur (2026-05-23)

### Problème initial
L'agent coordinateur `auditor` utilisait un skill `audit-protocol.md` (184 lignes) qui documentait le format de rapport et les règles d'audit, mais **sans workflow structuré avec récaps systématiques et questions obligatoires**. Les skills `analysis-workflow`, `analysis-templates`, `analysis-questions` (3 skills, 1331 lignes au total) étaient injectés dans `auditor` ET dans les 7 sous-agents `auditor-*`, alors que seul le coordinateur en avait réellement besoin.

### Solution retenue
Refonte native intégrée du coordinateur uniquement : **création de `auditor-workflow.md`** (841 lignes) qui structure les phases de coordination (vérification prérequis, chargement contexte, sélection domaines, délégation, consolidation) avec récaps systématiques et questions obligatoires. Les 7 sous-agents `auditor-*` conservent leur workflow technique actuel (`audit-protocol-light`) sans refonte.

### Workflow auditor coordinateur final

```
Phase 0 — Vérification des prérequis
         │ ✓ Périmètre clair (domaines, fichiers/modules, contraintes légales)
         │ ✓ Stack identifiable (langage + framework minimum)
         │ ✓ Accès aux fichiers pertinents (sources lisibles)
         ↓
Phase 1 — Chargement du contexte projet
         │ Priorité 1: Lire ONBOARDING.md (si existe)
         │ Priorité 2: Reconnaissance rapide (3-4 fichiers)
         │   → Fichier dépendances (package.json, composer.json, etc.)
         │   → Structure répertoires (src/, app/, lib/)
         │   → Configs (docker-compose.yml, .env.example, nginx.conf)
         │ → Résumé : stack + architecture + points d'attention
         ↓
Phase 2 — Sélection des domaines à auditer
         │ Analyse demande utilisateur :
         │   • Audit complet → tous les sous-agents (7 domaines)
         │   • Audit ciblé → sous-agent spécifique
         │   • Audit express → sécurité + accessibilité + performance (3)
         │   • Audit multi-domaines → combinaison
         │ Vérification compatibilité stack :
         │   • Performance → pertinent si frontend (Web Vitals) ou backend (N+1)
         │   • Accessibilité → pertinent si frontend avec UI
         │   • Éco-conception → pertinent si app déployée
         │   • Observabilité → pertinent si app en production
         ↓
Phase 3 — Délégation aux sous-agents spécialisés
         │ Pour chaque sous-agent :
         │   → Transmettre contexte projet complet en préambule
         │   → Invoquer via outil `task`
         │   → Collecter rapport + score /10 + criticités
         │ Invocation séquentielle (pas parallèle)
         │ Pause si audit bloquant détecté
         ↓
Phase 4 — Consolidation et synthèse exécutive
         │ Si 1 seul sous-agent → afficher rapport tel quel
         │ Si 2+ sous-agents → produire synthèse :
         │   • Vue d'ensemble (tableau scores + criticités)
         │   • Score global estimé (moyenne pondérée)
         │   • Top 5 actions prioritaires (tous domaines)
         │   • Points positifs globaux
         │   • Recommandations stratégiques (transverses)
```

**Chaque phase se termine par :**
1. Récap affiché en texte clair dans la discussion
2. Question de validation via l'outil `question`

**Règle absolue :** toujours afficher le récap en texte AVANT d'appeler l'outil `question`.

### Innovations spécifiques auditor coordinateur

#### 1. Vérification prérequis (Phase 0)
**Problème :** déléguer aux sous-agents sans contexte suffisant produit des rapports incomplets
**Solution :** vérification obligatoire 3 conditions en Phase 0 avec pause si insuffisant
- Périmètre clair (domaines + fichiers/modules + contraintes légales)
- Stack identifiable (langage + framework minimum)
- Accès aux fichiers pertinents (sources lisibles, pas que compilé)
- Option "Lancer quand même" → sous-agents signaleront limites dans section "Non couvert"

#### 2. Chargement contexte projet (Phase 1)
**Problème :** les sous-agents ré-exploraient le projet individuellement → duplication + incohérence
**Solution :** le coordinateur charge le contexte une seule fois en Phase 1 et le transmet à tous
- Priorité 1 : ONBOARDING.md (si existe) → contexte complet pré-établi
- Priorité 2 : Reconnaissance rapide (3-4 fichiers) → stack + architecture + points d'attention
- Suggestion à l'utilisateur de lancer l'onboarder si ONBOARDING.md absent

#### 3. Sélection domaines avec compatibilité stack (Phase 2)
**Problème :** certains domaines ne sont pas pertinents pour certaines stacks (ex : accessibilité pour API pure)
**Solution :** Phase 2 vérifie la compatibilité et propose de retirer les domaines non pertinents
- Performance → pertinent si frontend (Web Vitals) ou backend (N+1)
- Accessibilité → pertinent si frontend avec UI (HTML/CSS/JS)
- Éco-conception → pertinent si app déployée (web, mobile, serveur)
- Observabilité → pertinent si app en production avec endpoints

#### 4. Consolidation multi-domaines (Phase 4)
**Problème :** pas de vue d'ensemble quand plusieurs domaines audités
**Solution :** Phase 4 produit une synthèse exécutive avec :
- Vue d'ensemble (tableau scores + criticités par domaine)
- Score global estimé (moyenne pondérée configurable)
- Top 5 actions prioritaires (tous domaines confondus, triées par criticité)
- Recommandations stratégiques (transverses — impact plusieurs domaines)
- Identification des interdépendances (ex : absence validation → sécu + perf)

#### 5. Suppression des skills analysis-* inutilisés
**Problème :** les 3 skills `analysis-workflow`, `analysis-templates`, `analysis-questions` (1331 lignes) étaient injectés dans tous les agents (coordinateur + 7 sous-agents) alors que seul le coordinateur en avait besoin
**Solution :** 
- Skills analysis-* retirés des 7 sous-agents `auditor-*` (workflow technique inchangé)
- Les 3 skills analysis-* complètement supprimés (remplacés par workflows unifiés natifs)
- Répertoire `skills/analysis/` supprimé

### Résultats

| Métrique | Avant | Après |
|----------|-------|-------|
| **Agent coordinateur** | 164 lignes | 118 lignes (-46, -28%) |
| **Workflow coordinateur** | 184 lignes (`audit-protocol.md`) | 841 lignes (`auditor-workflow.md`) (+657, +357%) |
| **Skills référencés (coordinateur)** | 4 (`audit-protocol` + 3 analysis) | 3 (`auditor-workflow` + `audit-protocol-legacy` archivé + `audit-handoff-format`) |
| **Skills référencés (sous-agents)** | 7 (dont 3 analysis inutiles) | 4 (analysis retirés) |
| **Phases** | 3 étapes linéaires | 5 phases itératives avec récaps systématiques |
| **Questions obligatoires** | ❌ absentes | ✅ 1 par phase (5 questions) |
| **Retours en arrière** | ❌ non prévus | ✅ possible entre toutes phases |
| **Vérification prérequis** | ❌ non structurée | ✅ Phase 0 dédiée avec pause si insuffisant |
| **Compatibilité stack/domaines** | ❌ non vérifiée | ✅ Phase 2 avec vérification + proposition retrait |
| **Consolidation multi-domaines** | ✅ présente | ✅ améliorée (score global, top 5, recommandations stratégiques, interdépendances) |
| **Format de retour** | Synthèse uniquement | Synthèse + bloc handoff si invoqué depuis orchestrateur |
| **Skills analysis-* supprimés** | — | ✅ 3 skills (1331 lignes) supprimés, répertoire `skills/analysis/` supprimé |

### Comparaison avec planner, onboarder, debugger

| Caractéristique | Planner | Onboarder | Debugger | Auditor |
|-----------------|---------|-----------|----------|---------|
| **Phases** | 7 (0→1→1.5→2→3→4→5→5.5→6) | 6 (0→1→2→3→4→5) | 6 (0→1→2→3→4→5) | 5 (0→1→2→3→4) |
| **Phase 0** | Contexte projet | Contexte projet | Vérification artefacts | **Vérification prérequis 3 conditions** |
| **Phase 1** | Exploration + signaux UX/UI | Exploration adaptative 7 profils | Exploration contextuelle | **Chargement contexte (ONBOARDING.md ou reconnaissance)** |
| **Phase optionnelle** | 1.5 (délégation design) | — | 2 (questions artefacts) | — |
| **Phase métier** | 3 (plan hiérarchique) | 3 (rapport contexte) | 3 (diagnostic 4 étapes) | 3 (délégation sous-agents) |
| **Phase cas particuliers** | 4 (tickets mixtes, ambiguïtés) | 4 (CVE, dette masquée) | 4 (race conditions, edge cases) | ❌ absente (gérée par sous-agents) |
| **Phase finale** | 6 (vérification + handoff) | 5 (fichiers + handoff) | 5 (rapport + ticket Beads) | 4 (consolidation + synthèse) |
| **Itérations max** | 3 par phase | 3 par phase | 3 par phase | 3 par phase |
| **Délégations** | ✅ ux-designer, ui-designer | ❌ aucune | ❌ aucune | ✅ 7 auditor-* |
| **Écriture fichiers** | ❌ non | ✅ ONBOARDING.md, CONVENTIONS.md | ❌ non | ❌ non |
| **Création tickets** | ✅ bd create (multiples) | ❌ non | ✅ bd create (1 ticket) | ❌ non (recommandations uniquement) |
| **Consolidation** | ❌ non | ❌ non | ❌ non | ✅ synthèse multi-domaines |

### Fichiers modifiés

```
Créés :
+ skills/auditor/auditor-workflow.md                   841 lignes

Refactorés :
± agents/auditor/auditor.md                            164 → 118 lignes (-46)
± agents/auditor/auditor-security.md                   skills : 7 → 4 (analysis-* retirés)
± agents/auditor/auditor-performance.md                skills : 7 → 4 (analysis-* retirés)
± agents/auditor/auditor-accessibility.md              skills : 7 → 4 (analysis-* retirés)
± agents/auditor/auditor-ecodesign.md                  skills : 7 → 4 (analysis-* retirés)
± agents/auditor/auditor-architecture.md               skills : 7 → 4 (analysis-* retirés)
± agents/auditor/auditor-privacy.md                    skills : 7 → 4 (analysis-* retirés)
± agents/auditor/auditor-observability.md              skills : 7 → 4 (analysis-* retirés)

Archivés :
→ skills/auditor/audit-protocol.md
→ skills/auditor/audit-protocol-legacy.md              184 lignes

Supprimés :
✗ skills/analysis/analysis-workflow.md                 545 lignes
✗ skills/analysis/analysis-templates.md                510 lignes
✗ skills/analysis/analysis-questions.md                276 lignes
✗ skills/analysis/ (répertoire)                        —
```

### Bilan global des 4 refontes

| Agent | Lignes avant | Lignes après | Workflow | Skills archivés | Skills supprimés |
|-------|--------------|--------------|----------|----------------|------------------|
| **planner** | 91 | 143 (+52, +57%) | 1541 lignes | 1 (`planner.md` 980L) | — |
| **onboarder** | 193 | 143 (-50, -26%) | 1375 lignes | 2 (`project-discovery` 396L, `project-conventions` 362L) | — |
| **debugger** | 127 | 134 (+7, +5%) | 855 lignes | 1 (`debug-protocol` 302L) | — |
| **auditor** | 164 | 118 (-46, -28%) | 841 lignes | 1 (`audit-protocol` 184L) | 3 analysis (1331L) |

**Total workflows créés :** 4612 lignes  
**Total skills archivés :** 5 (2224 lignes)  
**Total skills supprimés :** 3 (1331 lignes)  
**Total agents refactorés :** 4 + 7 sous-agents (skills analysis retirés)  
**Documentation RTK.md :** 632 lignes totales (~486 lignes ajoutées)

### Prochaines étapes

- ✅ **4 agents planning/quality refactorés** : planner, onboarder, debugger, auditor coordinateur
- ⏭️ Documenter la gouvernance des workflows (quand créer un workflow unifié vs utiliser un workflow technique simple)
- ⏭️ Auditer les autres familles d'agents (design, development) pour identifier d'éventuelles opportunités de refonte

## Statistiques globales

**Refontes réalisées :** 4 agents coordinateurs (planner, onboarder, debugger, auditor)

| Métrique | Total |
|----------|-------|
| **Workflows créés** | 4612 lignes (4 fichiers) |
| **Skills archivés** | 5 fichiers (2224 lignes) |
| **Skills supprimés** | 3 fichiers (1331 lignes) |
| **Agents refactorés** | 4 coordinateurs + 7 sous-agents (nettoyage skills) |
| **Documentation produite** | 671 lignes (RTK.md) |

### Principes de conception appliqués

1. **Récap avant question** — règle absolue : toujours afficher le récap en texte AVANT d'appeler l'outil `question`
2. **Workflows unifiés natifs** — chaque agent coordinateur a son propre workflow spécialisé, pas de dépendance à un workflow générique
3. **Questions obligatoires** — chaque phase se termine par une question de validation via l'outil `question`
4. **Itérations contrôlées** — maximum 3 itérations par phase pour éviter les boucles infinies
5. **Formats de handoff** — blocs structurés `## Retour vers orchestrator` pour les invocations depuis l'orchestrateur feature
6. **Phases cas particuliers** — phase dédiée pour détecter edge cases, incohérences, risques non évidents
7. **Autocontrôle systématique** — avant de produire un bloc handoff : "Ai-je produit le contenu complet avant ce bloc ?"

### Quand créer un workflow unifié ?

**✅ Créer un workflow unifié si l'agent :**
- Est un **coordinateur** qui orchestre d'autres agents ou des phases complexes
- Nécessite des **validations utilisateur** à chaque étape (CP-0, CP-spec, CP-audit, etc.)
- A des **phases itératives** possibles (retour en arrière, révisions, ajustements)
- Produit un **livrable structuré** après plusieurs phases d'analyse ou de collecte
- Interagit avec l'utilisateur pour **clarifier, valider ou décider**

**❌ Ne PAS créer de workflow unifié si l'agent :**
- Est un **agent technique spécialisé** (auditor-security, developer-frontend, etc.)
- A un **workflow linéaire simple** sans phases de validation intermédiaire
- Est **invoqué par un coordinateur** qui gère déjà les validations et récaps
- Produit un **livrable technique direct** (rapport d'audit, implémentation de code)
- N'interagit **pas directement avec l'utilisateur final**

**Exemples :**
- ✅ `planner`, `onboarder`, `debugger`, `auditor` → workflows unifiés (coordination, validation, phases)
- ❌ `auditor-security`, `auditor-performance`, `developer-frontend` → workflows techniques simples (exécution, pas coordination)

### Gouvernance des workflows

**Règle générale :**
- Les **agents coordinateurs** (planner, onboarder, debugger, auditor, orchestrator, orchestrator-dev) ont des workflows unifiés avec récaps + questions + phases itératives
- Les **agents spécialisés** (auditor-*, developer-*, qa-*, reviewer-*) ont des workflows techniques simples documentés dans leurs skills spécifiques

**Exception :**
- Un agent spécialisé peut avoir un workflow unifié s'il est invoqué directement par l'utilisateur ET nécessite des validations intermédiaires (ex : `ux-designer`, `ui-designer` ont des phases de validation avec l'utilisateur)
