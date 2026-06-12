> 🇬🇧 [Read in English](015-concision-posture.en.md)

# ADR-015 — Skill de posture de concision pour les agents internes

## Statut

Accepté

## Contexte

Les agents internes du hub (orchestrator, orchestrator-dev, planner, pathfinder, developer, qa-engineer, reviewer) produisent des outputs verbeux qui ne sont pas des livrables formels destinés à l'utilisateur final, mais des échanges de coordination. Ces outputs contiennent systématiquement :

- **Formules d'introduction sans valeur** : "Bien sûr !", "Je vais maintenant...", "Voici ce que j'ai trouvé :"
- **Reformulations du contexte connu** : répétition de ce que l'utilisateur vient de dire ou de ce qui est déjà établi dans la session
- **Transitions redondantes entre sections titrées** : "Passons maintenant à la section suivante :" avant un titre `##`
- **Formules de clôture** : "N'hésite pas à me poser d'autres questions."

Ces patterns ne portent aucune information et allongent inutilement les réponses. Sur des sessions longues avec plusieurs agents chaînés, cela représente 30-40% du volume de tokens de réponse.

Le projet caveman (JuliusBrussee/caveman, 71k stars) valide cette approche à grande échelle : moyenne de 65% de réduction des output tokens sur 10 benchmarks (22-87% selon le type de tâche) avec 100% de précision technique maintenue. La recherche "Brevity Constraints Reverse Performance Hierarchies in Language Models" (arxiv, mars 2026) confirme que contraindre à la brièveté améliore la précision de 26 points sur certains benchmarks.

Cependant, caveman en mode `full` ou `ultra` est trop agressif pour un hub dont certains agents produisent des livrables formels (rapports d'audit, specs UX, rapports de diagnostic). Un niveau `lite` — suppression du filler uniquement — est le bon compromis.

La décision est de créer un skill `posture/concision-posture` maison plutôt que d'installer le plugin caveman tel quel pour trois raisons :
1. **Contrôle par agent** : le skill s'injecte sélectivement dans les agents concernés. Le plugin caveman est global.
2. **Formalisme préservé** : le niveau `lite` est défini avec précision pour ne pas toucher aux livrables formels (blocs handoff, rapports). caveman mode `full` ne fait pas cette distinction.
3. **Pas de dépendance externe** : un skill Markdown n'a pas de prérequis npm/binaire. Pas de surface de mise à jour supplémentaire.

## Décision

Créer le skill `skills/posture/concision-posture.md` en **Bucket A** avec le niveau `lite` comme défaut.

**Niveau `lite` — supprime uniquement :**
- Formules d'introduction sans valeur ("Bien sûr !", "Je vais...", "Voici...")
- Reformulations du contexte déjà connu dans la session
- Transitions redondantes entre sections titrées
- Formules de clôture ("N'hésite pas à...", "J'espère que...")

**N'affecte pas :**
- Les blocs `## Retour vers orchestrator` / `## Question pour l'orchestrateur` (contrats fonctionnels)
- Les récapitulatifs narratifs obligatoires (planner, debugger, onboarder, auditor, designers)
- Les rapports de review, rapports QA, rapports de diagnostic
- Les justifications techniques, avertissements, hypothèses

**Agents concernés (Bucket A) :** orchestrator, orchestrator-dev, planner, pathfinder, developer, qa-engineer, reviewer

**Agents exclus :** auditor-*, documentarian, ux-designer, ui-designer, debugger — leurs outputs sont des livrables formels dont la verbosité est intentionnelle

**Configuration** : clé `token_optimization.output_verbosity` dans `config/hub.json`. La valeur `"lite"` active le skill (défaut). La valeur `"off"` désactive le skill en retirant `posture/concision-posture` du frontmatter des agents.

## Conséquences

### Positives

- **-30-40% output tokens sur les agents internes** (basé sur les benchmarks caveman pour le niveau "lite" équivalent). Impact concret sur les sessions longues multi-agents.
- **Aucune perte d'information** : le niveau `lite` ne supprime que le bruit syntaxique, pas le contenu technique.
- **Formalisme préservé** : les livrables formels (rapports, specs, blocs handoff) ne sont pas impactés car les agents qui les produisent n'ont pas ce skill.
- **Configurable** : `output_verbosity: "off"` dans `hub.json` désactive le skill sur tous les agents sans modifier les frontmatters individuellement.
- **Sans dépendance** : un fichier Markdown dans `skills/posture/`, zero setup.

### Négatives / compromis

- **Risque de sur-concision** : si un agent interprète "lite" de façon trop agressive, des informations utiles pourraient être omises. Le skill est écrit avec des exemples explicites de ce qui doit et ne doit pas être supprimé pour minimiser ce risque.
- **Maintenance manuelle** : contrairement au plugin caveman qui évolue automatiquement, ce skill doit être mis à jour manuellement si les patterns verbeux évoluent avec les modèles.

## Alternatives rejetées

**Plugin caveman tel quel** : caveman en mode `full` ne distingue pas les échanges de coordination des livrables formels. Risque de rapports d'audit ou specs UX dégradés. Pas de contrôle par agent. Dépendance npm supplémentaire.

**Règles de concision dans chaque agent séparément** : chaque agent aurait sa propre version des règles. Duplication de contenu, maintenance distribuée, risque d'incohérence entre agents. Un skill centralisé est plus facile à maintenir.

**Ne rien faire** : les output tokens représentent 40-60% du coût total sur les sessions longues multi-agents. Le filler est un pattern observable et mesurable. Le rapport bénéfice/risque d'un skill `lite` est clairement favorable.

## Impact

| Fichier | Action |
|---------|--------|
| `skills/posture/concision-posture.md` | Créé — skill Bucket A |
| `config/hub.json` | Modifié — ajout `token_optimization.output_verbosity: "lite"` |
| `agents/planning/orchestrator.md` | Modifié — `posture/concision-posture` ajouté dans `skills:` |
| `agents/planning/orchestrator-dev.md` | Modifié — idem |
| `agents/planning/planner.md` | Modifié — idem |
| `agents/planning/pathfinder.md` | Modifié — idem |
| `agents/developer/developer.md` | Modifié — idem |
| `agents/quality/qa-engineer.md` | Modifié — idem |
| `agents/quality/reviewer.md` | Modifié — idem |
