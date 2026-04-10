---
name: dev-standards-testing
description: Stratégie de tests — unitaires, intégration, E2E. Couverture obligatoire, TDD, mocking, et règles de non-régression.
---

# Skill — Standards de Tests

## Rôle

Tu es un assistant de développement qui applique une stratégie de tests rigoureuse.
Ce skill définit les standards de tests à respecter sur tous les projets :
couverture minimale, organisation, nomenclature et règles de non-régression.

---

## 🔒 Règles absolues

❌ Tu ne livres JAMAIS une fonctionnalité sans tests unitaires sur la logique métier
❌ Tu ne supprimes JAMAIS un test existant sans justification explicite de l'utilisateur
❌ Tu n'utilises JAMAIS `any` TypeScript dans les types de test pour contourner des erreurs
✅ Si une fonctionnalité n'est pas testable telle qu'elle est conçue, tu le signales avant d'implémenter

---

## Pyramide de tests

```
         /──────────\
        /   E2E      \         ← peu, lents, fragiles — réservés aux parcours critiques
       /──────────────\
      /  Intégration   \       ← interactions entre modules, appels API, DB (in-memory)
     /──────────────────\
    /     Unitaires       \    ← logique métier isolée — rapides, nombreux, déterministes
   /────────────────────────\
```

**Répartition cible :**
- 70 % tests unitaires
- 20 % tests d'intégration
- 10 % tests E2E

---

## Tests unitaires

### Quand écrire un test unitaire

- Toute fonction avec logique conditionnelle (if, switch, ternaire)
- Toute transformation de données (mapping, calcul, formatage)
- Toute validation ou parsing d'entrée
- Tout comportement qui doit rester stable à l'avenir

### Structure AAA (Arrange / Act / Assert)

```typescript
it('doit retourner le prix TTC quand la TVA est fournie', () => {
  // Arrange
  const prixHT = 100
  const tva = 0.2

  // Act
  const result = calculerPrixTTC(prixHT, tva)

  // Assert
  expect(result).toBe(120)
})
```

### Nommage

- Format : `doit <comportement attendu> quand <condition>`
- En français, en minuscules, descriptif
- Le nom du test est la documentation du comportement — il doit être lisible seul

### Couverture minimale

- Logique métier : **100 %** des branches (y compris les cas d'erreur)
- Composants Vue/React : les comportements visibles (rendu conditionnel, émission d'événements)
- Utilitaires : **100 %**
- Controllers/Routes : couverture par tests d'intégration, pas unitaires

---

## Tests d'intégration

- Tester les interactions réelles entre modules (service + repository, controller + service)
- Utiliser des bases de données in-memory (SQLite, testcontainers) ou des mocks de couche IO
- Chaque appel API exposé doit avoir au moins un test d'intégration couvrant :
  - Le cas nominal (200 OK)
  - Un cas d'erreur métier (400 / 422)
  - Le cas non authentifié si la route est protégée (401 / 403)

---

## Tests E2E

- Réservés aux parcours utilisateurs critiques : inscription, connexion, achat, etc.
- Utiliser Playwright (web) ou Cypress en dernier recours
- Chaque test E2E doit être **idempotent** : nettoyage en beforeEach/afterEach
- Pas de `cy.wait(1000)` ni de `page.waitForTimeout()` — utiliser les waits sémantiques

---

## Mocking

### Ce qu'on mocke

- Les appels réseau (fetch, axios, HTTP)
- Les accès fichier système
- Les dépendances externes (email, SMS, paiement)
- Le temps (`Date.now()`, `new Date()`) quand il influence la logique

### Ce qu'on ne mocke pas

- La logique métier que le test est censé vérifier
- Les transformations de données pures (pas de dépendance externe)
- Les composants UI quand on teste le comportement de rendu

### Syntaxe Vitest / Jest

```typescript
vi.mock('../services/emailService', () => ({
  sendEmail: vi.fn().mockResolvedValue({ success: true }),
}))

// Dans le test :
expect(emailService.sendEmail).toHaveBeenCalledWith({
  to: 'user@example.com',
  subject: expect.stringContaining('Bienvenue'),
})
```

---

## TDD — Développement piloté par les tests

### Quand appliquer le TDD

- Logique métier complexe (calculs, règles, validations)
- Correction de bugs (le test reproduit le bug avant le fix)
- API publiques (contrat défini avant l'implémentation)
- Tout ticket Beads portant le label **`tdd`**

### Processus Red / Green / Refactor

```
1. Red    — Écrire le(s) test(s) qui échoue(nt) (l'implémentation n'existe pas encore)
2. Green  — Écrire le minimum de code pour faire passer le(s) test(s)
3. Refactor — Améliorer le code sans casser les tests
```

### Workflow TDD en contexte Beads

Quand le ticket porte le label `tdd`, respecter impérativement cet ordre :

```
1. bd show <ID>                   → lire les critères d'acceptance — ils définissent les tests à écrire
2. bd update <ID> --claim         → clamer le ticket
3. [RED]    Écrire les tests qui couvrent les critères d'acceptance → vérifier qu'ils échouent
4. [GREEN]  Implémenter le minimum de code pour faire passer les tests
5. [REFACTOR] Nettoyer le code sans casser les tests
6. bd update <ID> -s review       → passer en review
```

❌ Ne jamais écrire l'implémentation avant que les tests rouges existent
❌ Ne jamais modifier un test pour le faire passer — modifier l'implémentation
❌ Ne jamais supprimer un test rouge "gênant" — s'il échoue, l'implémentation est incomplète
✅ Les tests rouges sont le contrat — l'implémentation les satisfait, pas l'inverse

### Critère de "done" en TDD

- Tous les tests écrits en phase Red sont verts
- Aucun test existant n'a été supprimé ou modifié pour forcer le green
- Le refactor n'a pas introduit de régression (tous les tests passent après refactor)
- Les critères d'acceptance du ticket sont couverts chacun par au moins un test

### Exemple — cycle Red / Green / Refactor

**Red — test écrit en premier (échoue) :**

```typescript
// Red : la fonction calculerRemise n'existe pas encore
it('doit appliquer 10% de remise quand le montant dépasse 100€', () => {
  expect(calculerRemise(150)).toBe(135)
})

it('doit retourner le montant sans remise quand il est inférieur à 100€', () => {
  expect(calculerRemise(80)).toBe(80)
})
```

**Green — implémentation minimale :**

```typescript
// Green : minimum pour faire passer les tests
export function calculerRemise(montant: number): number {
  return montant > 100 ? montant * 0.9 : montant
}
```

**Refactor — amélioration sans casser les tests :**

```typescript
// Refactor : constante nommée, seuil et taux extraits
const SEUIL_REMISE = 100
const TAUX_REMISE = 0.10

export function calculerRemise(montant: number): number {
  return montant > SEUIL_REMISE ? montant * (1 - TAUX_REMISE) : montant
}
// Les tests passent toujours — rien n'a changé du point de vue du comportement
```

### Impact sur le QA

Quand le ticket est en TDD, le `qa-engineer` est **inutile et contre-productif** :
les tests ont été écrits en premier par le developer dans sa boucle red/green/refactor.
L'`orchestrator-dev` saute automatiquement le CP-QA pour les tickets labellisés `tdd`.

---

## Organisation des fichiers

```
src/
├── services/
│   ├── paiement.service.ts
│   └── __tests__/
│       └── paiement.service.test.ts   ← co-localisé avec la source
├── components/
│   ├── PaiementForm.vue
│   └── __tests__/
│       └── PaiementForm.test.ts
tests/
├── integration/                        ← tests d'intégration multi-modules
│   └── checkout.integration.test.ts
└── e2e/                               ← tests E2E
    └── checkout.e2e.test.ts
```

---

## Non-régression

- Tout bug corrigé **doit** avoir un test qui le reproduit avant le fix
- Format du test de non-régression :
  ```typescript
  it('doit [comportement] — non-régression #<ID-ticket>', () => { ... })
  ```
- Ce test reste dans le code définitivement

---

## 🔎 Mode Auditeur

Quand l'utilisateur demande un audit, une review ou utilise le mot-clé **"audit tests"** :

1. Lister les fonctions/modules sans tests ou avec couverture insuffisante
2. Identifier les tests qui testent l'implémentation plutôt que le comportement
3. Signaler les `vi.mock`/`jest.mock` qui masquent du code jamais exécuté
4. Vérifier la nomenclature et la structure AAA
5. Proposer un plan de correction priorisé
