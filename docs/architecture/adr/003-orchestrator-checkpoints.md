# ADR-003 — Orchestrateur avec checkpoints explicites

## Statut

Accepté

## Contexte

Lors de la conception de l'agent `orchestrator`, deux philosophies s'opposaient :

1. **Automatisation complète** : l'orchestrateur enchaîne planner → developer → qa →
   reviewer sans interruption, et présente un résultat final à l'utilisateur.
2. **Checkpoints explicites** : l'orchestrateur pause à chaque étape clé et attend
   une confirmation explicite avant de continuer.

L'automatisation complète semblait plus fluide, mais elle présentait des risques
importants dans un contexte où les agents IA peuvent produire des résultats incorrects,
incomplets ou non conformes aux attentes.

## Décision

L'orchestrateur impose des **checkpoints explicites** (notés `[CP-X]`) à chaque
étape critique :

- `[CP-0]` — Avant de démarrer le workflow (validation des tickets planifiés)
- `[CP-1]` — Avant chaque ticket (confirmation de démarrage)
- `[CP-QA]` — Avant l'étape QA (optionnel, choix de l'utilisateur)
- `[CP-2]` — Après la review (merge ou corrections ?)
- `[CP-3]` — Après chaque ticket (ticket suivant ou stop ?)

L'orchestrateur ne passe jamais à l'étape suivante sans réponse explicite.

## Conséquences

### Positives

- L'utilisateur garde le contrôle à chaque étape
- Les erreurs d'un agent sont détectées avant de se propager aux étapes suivantes
- Permet d'interrompre, de passer un ticket ou de changer de direction à tout moment
- Adapté à un contexte où les agents IA ne sont pas infaillibles

### Négatives / compromis

- Plus lent qu'un workflow entièrement automatisé
- Requiert une présence active de l'utilisateur pendant tout le workflow
- Peut devenir fastidieux sur des features avec de nombreux tickets simples

## Alternatives rejetées

**Automatisation complète** : rejetée car un bug d'implémentation non détecté au
ticket 2 peut contaminer les tickets 3 à N avant que l'utilisateur intervienne.

**Automatisation avec alerte uniquement sur erreur** : rejetée car "pas d'erreur"
ne signifie pas "conforme aux attentes" — la review peut signaler des problèmes
fonctionnels qui ne génèrent pas d'erreur technique.

**Mode configurable** (auto / manuel) : possible en évolution future, mais introduit
de la complexité de configuration sans valeur immédiate prouvée.
