---
name: dev-standards-simplicity
description: Principes de simplicité — KISS, YAGNI, pas d'abstraction prématurée, pas d'optimisation prématurée, limites de complexité mesurables. La solution la plus simple qui répond au besoin est toujours préférée.
---

# Skill — Standards de Simplicité

## Principe fondamental

La simplicité est un critère de qualité au même titre que la sécurité ou la testabilité.
Le code le plus simple qui répond au besoin actuel est toujours le bon choix.
La complexité accidentelle est une dette — elle ralentit, elle fragile, elle décourage.

**Règle d'or : avant d'écrire du code, demande-toi si tu peux faire moins.**

---

## KISS — Keep It Simple

Préfère toujours la solution la plus directe qui résout le problème posé.

```
✅ Un if/else pour 2 cas
❌ Un pattern Strategy avec interface, factory et 3 fichiers pour 2 cas

✅ Une fonction qui lit un fichier et retourne son contenu
❌ Une classe FileReaderService avec injection de dépendance pour un usage unique

✅ Une requête SQL avec une jointure
❌ Un ORM avec 4 niveaux d'abstraction et un query builder custom pour la même requête
```

**Question à poser avant d'implémenter :** "Est-ce que la version la plus naïve résout déjà le problème ?"
Si oui, implémenter la version naïve. L'optimisation et l'abstraction viennent ensuite, si les faits les justifient.

---

## YAGNI — You Aren't Gonna Need It

N'implémente pas ce qui n'est pas demandé par un ticket actif.

```
❌ Ajouter un système de plugins "au cas où on veuille étendre ça plus tard"
❌ Prévoir un cache "parce que ça risque d'être lent un jour"
❌ Créer une abstraction "pour quand on aura plusieurs implémentations"
❌ Ajouter des paramètres de configuration pour des comportements qui n'existent pas encore
```

Les abstractions "au cas où" sont du code mort dès le premier jour.
Elles complexifient sans apporter de valeur mesurable, et elles résistent souvent aux vrais besoins futurs — qui ne ressemblent jamais à ce qu'on avait imaginé.

**Règle :** si ce n'est pas dans le ticket, ne l'implémente pas. Si c'est important, ça sera un ticket.

---

## Pas d'abstraction prématurée

N'extrais une abstraction qu'à partir de **3 cas d'usage concrets et existants**.

```
1 cas  → implémente directement, pas d'abstraction
2 cas  → duplique si nécessaire, note la ressemblance
3 cas  → extrait l'abstraction avec la connaissance des 3 cas réels
```

Une abstraction créée sur 1 ou 2 cas encode les mauvaises hypothèses.
Elle contraint l'évolution au lieu de la faciliter.

---

## Duplication > mauvaise abstraction

Copier-coller du code une fois est acceptable.
Créer une abstraction forcée pour éviter cette duplication est souvent une dette plus lourde.

```
✅ Deux fonctions légèrement différentes, clairement nommées
❌ Une fonction générique avec 5 paramètres booléens pour couvrir les deux cas

✅ Deux composants similaires à 80%, avec des responsabilités distinctes
❌ Un composant "universel" avec une prop `mode` qui pilote des dizaines de comportements
```

**Critère :** si l'abstraction nécessite plus de paramètres que ce qu'elle économise en lignes, elle n'est pas prête.

---

## Pas d'optimisation prématurée

N'optimise pas sans mesure préalable.

```
❌ Ajouter un cache Redis parce que "ça va être lent"
❌ Paralléliser des opérations sans avoir mesuré leur durée
❌ Dénormaliser une base de données par anticipation
❌ Utiliser une structure de données complexe parce qu'elle est "théoriquement plus rapide"
```

**Processus correct :**
1. Implémenter la version lisible et correcte
2. Mesurer (profiler, bench, APM)
3. Identifier le vrai goulot
4. Optimiser uniquement ce goulot, avec un test de non-régression perf

La lisibilité et la correction passent toujours avant la performance, sauf contrainte explicite dans le ticket.

---

## Limites de complexité mesurables

Ces seuils sont des signaux d'alerte, pas des règles absolues.
Les dépasser nécessite une justification explicite dans le code (commentaire ou PR description).

| Mesure | Seuil recommandé | Signal d'alerte |
|--------|-----------------|-----------------|
| Longueur d'une fonction | ≤ 20 lignes | > 30 lignes → à scinder |
| Complexité cyclomatique | ≤ 10 | > 15 → à refactorer |
| Nombre de paramètres | ≤ 4 | > 4 → introduire un objet de configuration |
| Profondeur d'imbrication | ≤ 3 niveaux | > 3 → extraire une fonction ou inverser la condition |
| Nombre de dépendances injectées | ≤ 5 | > 5 → la classe a trop de responsabilités |

---

## Signaux d'alerte — over-engineering à challenger

Ces patterns ne sont pas interdits, mais chacun doit être justifié par un besoin réel et actuel :

- `AbstractFactory` ou `Builder` pour un seul type d'objet
- `Interface` avec une seule implémentation (hors test)
- Classe avec un seul constructeur et une seule méthode publique → probablement une fonction
- Middleware générique pour un comportement utilisé à un seul endroit
- Configuration externalisée pour une valeur qui ne changera jamais
- Event bus interne pour des communications entre deux modules seulement
- Pattern Repository sur une source de données qui n'a pas de logique d'accès
- Paramètre `options?: {}` vide ajouté "pour l'extensibilité future"

**Réponse attendue face à ces signaux :** challenger, proposer la version simple, documenter si la complexité est retenue.

---

## Ce que ce skill ne dit PAS

La simplicité n'est pas l'absence de rigueur ni un prétexte pour éviter les bonnes pratiques.

```
✅ Une architecture hexagonale est justifiée si le domaine est complexe et les ports/adapters sont réels
✅ Un pattern Strategy est justifié si les variantes sont nombreuses et évolutives
✅ Un cache est justifié si un benchmark démontre un problème de performance réel
✅ Une abstraction est justifiée si elle réduit effectivement la complexité globale
```

Le critère n'est pas "est-ce que c'est complexe ?" mais "est-ce que cette complexité est justifiée par le besoin actuel ?"
