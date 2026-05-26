---
name: quick-fix
description: Corrections auto-applicables sans review — lint fix, import manquant, typo évidente, formatage. Ces corrections déterministes ne modifient pas la logique métier et peuvent être appliquées immédiatement.
---

# Skill — Corrections Auto-Applicables (Quick Fix)

## Rôle

Ce skill définit les corrections triviales qu'un agent developer peut appliquer
**immédiatement** sans passer par le cycle complet de review.

Ces corrections sont **déterministes** : elles n'impliquent aucun jugement,
aucune décision d'architecture, et aucune modification de la logique métier.

---

## ✅ Corrections éligibles (auto-applicables)

### Lint fix

Corrections automatiques suggérées par le linter du projet.

```typescript
// Avant — erreur ESLint : prefer-const
let value = 42;

// Après — quick fix applicable
const value = 42;
```

```typescript
// Avant — erreur ESLint : no-unused-vars (import)
import { foo, bar } from './utils';
console.log(foo);

// Après — quick fix applicable
import { foo } from './utils';
console.log(foo);
```

### Import manquant

Ajout d'un import pour un symbole utilisé mais non importé.

```typescript
// Avant — TypeScript error: Cannot find name 'ref'
const count = ref(0);

// Après — quick fix applicable
import { ref } from 'vue';
const count = ref(0);
```

```python
# Avant — NameError: name 'Path' is not defined
config_path = Path("./config.json")

# Après — quick fix applicable
from pathlib import Path
config_path = Path("./config.json")
```

### Typo évidente

Correction d'une faute de frappe dans un identifiant, un commentaire ou une chaîne
quand l'intention est **non ambiguë**.

```typescript
// Avant — typo évidente dans un commentaire
// Initialzie the counter
const counter = 0;

// Après — quick fix applicable
// Initialize the counter
const counter = 0;
```

```typescript
// Avant — typo dans une chaîne de message d'erreur
throw new Error('Invalide user ID');

// Après — quick fix applicable
throw new Error('Invalid user ID');
```

### Formatage

Corrections de formatage (indentation, espaces, sauts de ligne) conformes
à la configuration du projet (Prettier, EditorConfig, etc.).

```typescript
// Avant — formatage incohérent
function foo( a:number,b:string ){
return a+b}

// Après — quick fix applicable (Prettier)
function foo(a: number, b: string) {
  return a + b;
}
```

### Point-virgule manquant / en trop

Si le projet a une convention explicite (ESLint, Prettier).

```typescript
// Avant — point-virgule manquant (convention : semi)
const value = 42

// Après — quick fix applicable
const value = 42;
```

### Trailing comma

Ajout ou suppression des virgules finales selon la configuration du projet.

```typescript
// Avant — trailing comma manquante (convention : es5)
const config = {
  foo: 1,
  bar: 2
};

// Après — quick fix applicable
const config = {
  foo: 1,
  bar: 2,
};
```

---

## ❌ Corrections NON éligibles (nécessitent une review)

### Renommage de variable

Un renommage implique un jugement sur le nommage approprié et peut avoir des
impacts sur la lisibilité et la compréhension du code par l'équipe.

```typescript
// NON éligible — choix de nommage subjectif
const x = calculateTotal(items);      // → totalPrice ? orderTotal ? sum ?
```

**Justification :** Le nom d'une variable est une décision de design.
Même un "mauvais" nom peut avoir une raison historique ou contextuelle.

### Refactoring

Toute restructuration du code, même mineure, qui modifie l'organisation
sans changer le comportement.

```typescript
// NON éligible — extraction de fonction
if (user.age >= 18 && user.hasAcceptedTerms && user.isVerified) { ... }
// → isEligible(user) ?

// NON éligible — changement de structure de contrôle
if (condition) {
  return early;
}
doSomething();
// → condition ? early : doSomething() ?
```

**Justification :** Le refactoring implique des choix d'architecture locale
(extraction, inversion de condition, pattern). Ces choix doivent être validés.

### Changement de signature

Toute modification de la signature d'une fonction, méthode ou API.

```typescript
// NON éligible — ajout de paramètre optionnel
function fetchUser(id: string) { ... }
// → function fetchUser(id: string, options?: FetchOptions) { ... }

// NON éligible — changement de type de retour
function getUsers(): User[] { ... }
// → function getUsers(): Promise<User[]> { ... }

// NON éligible — réordonnancement des paramètres
function createOrder(userId: string, items: Item[], discount?: number) { ... }
// → function createOrder(items: Item[], userId: string, discount?: number) { ... }
```

**Justification :** Un changement de signature peut casser les appelants
et constitue un breaking change potentiel.

### Modification de logique métier

Tout changement qui affecte le comportement de l'application, même subtil.

```typescript
// NON éligible — changement de condition métier
if (user.age >= 18) { ... }  // → if (user.age > 18) { ... }

// NON éligible — changement de valeur par défaut
const timeout = options.timeout ?? 5000;  // → ?? 10000

// NON éligible — ajout/suppression de validation
if (!email.includes('@')) throw new Error('Invalid');  // → suppression
```

**Justification :** La logique métier est le cœur de l'application.
Toute modification doit être tracée, testée et validée.

### Changement de dépendance

Ajout, suppression ou mise à jour de dépendances.

```typescript
// NON éligible — remplacement d'une lib par une autre
import moment from 'moment';  // → import { format } from 'date-fns';

// NON éligible — suppression d'une dépendance
import _ from 'lodash';  // → utilisation native
```

**Justification :** Les dépendances impactent la taille du bundle,
la sécurité, la compatibilité et la maintenabilité.

### Suppression de code

Même du code apparemment mort ou inutilisé.

```typescript
// NON éligible — suppression de fonction non appelée
function legacyHelper() { ... }  // semble inutilisé → suppression ?
```

**Justification :** Le code "mort" peut être utilisé dynamiquement,
documenté pour un usage futur, ou avoir une raison d'exister non évidente.

---

## Conditions d'application

Une correction quick fix peut être appliquée **uniquement si** :

1. **Pas de changement de logique métier** — le comportement observable reste identique
2. **Correction déterministe** — une seule façon correcte de corriger (pas de choix)
3. **Changement local** — impact limité au fichier concerné, pas d'effet de bord
4. **Réversible trivialement** — un `git checkout` suffit à annuler
5. **Conforme aux conventions du projet** — respecte le linter, le formatter configuré

---

## Workflow

Quand tu identifies une correction éligible :

1. **Vérifier l'éligibilité** — la correction entre dans les catégories ✅ ci-dessus
2. **Appliquer directement** — sans demander confirmation
3. **Mentionner dans le compte rendu** — lister les quick fixes appliqués

```markdown
### Quick fixes appliqués
- `src/utils/format.ts` : lint fix (prefer-const, 2 occurrences)
- `src/components/Button.vue` : import manquant (ref)
- `src/services/user.ts` : formatage Prettier
```

---

## Ce que ce skill ne remplace PAS

Ce skill ne dispense pas de la review pour les modifications substantielles.
En cas de doute sur l'éligibilité d'une correction, **ne pas l'appliquer**
et la signaler comme suggestion dans le compte rendu.

```markdown
### Suggestions (non appliquées — nécessitent validation)
- `src/utils/date.ts:42` : variable `d` pourrait être renommée en `formattedDate`
- `src/services/api.ts:15-20` : code dupliqué, extraction possible
```
