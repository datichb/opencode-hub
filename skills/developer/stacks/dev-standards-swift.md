---
name: dev-standards-swift
description: Standards Swift / iOS natif — SwiftUI, MVVM, Swift Concurrency, sécurité Keychain, conventions de nommage.
---

# Skill — Standards Swift (iOS natif)

## Rôle

Ce skill définit les bonnes pratiques pour le développement iOS natif avec Swift et SwiftUI.
Il complète `dev-standards-universal.md`.

---

## 🔒 Règles absolues

❌ Jamais de données sensibles dans `UserDefaults`
❌ Jamais de secrets ou tokens dans le code de l'application
❌ Pas de `NSAllowsArbitraryLoads` dans App Transport Security (ATS)
✅ Les données sensibles utilisent Keychain Services ou CryptoKit
✅ Toute communication réseau passe par HTTPS — ATS activé

---

## Architecture

- **SwiftUI** pour toutes les nouvelles vues (iOS 14+) — UIKit uniquement si une API native l'impose
- Pattern **MVVM** : View observe ViewModel via `@Observable` (Swift 5.9+) ou `@ObservableObject`
- Découper en Swift Packages (`swift-package-manager`) pour les modules réutilisables
- Organisation par feature :

```
Sources/
├── Features/
│   └── Auth/
│       ├── AuthView.swift
│       ├── AuthViewModel.swift
│       └── AuthRepository.swift
├── Domain/               ← entités, protocols, use cases
├── Data/                 ← implémentations concrètes, DTOs, réseau
└── Core/                 ← thème, routing, injection, utils
```

---

## Swift moderne

- Swift Concurrency (`async/await`, `Task`, `Actor`) — pas de completion handlers ni de callbacks
- `Sendable` sur les types partagés entre actors
- Value types (`struct`) par défaut — `class` uniquement si héritage ou identité requise
- `enum` avec associated values pour les états (idle, loading, loaded, error)
- `Result<Success, Failure>` pour les opérations pouvant échouer

```swift
// ✅ ViewModel avec async/await, état typé, @Observable (Swift 5.9+)
@Observable
final class UserListViewModel {
    private(set) var state: ViewState<[User]> = .idle
    private let userRepository: UserRepositoryProtocol

    init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    func loadUsers() async {
        state = .loading
        do {
            let users = try await userRepository.fetchAll()
            state = .loaded(users)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

enum ViewState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)
}
```

### Protocols et injection de dépendances

- Les dépendances sont injectées via le constructeur — pas de singletons implicites
- Les repositories et services exposent un protocol — les ViewModels dépendent du protocol

```swift
// ✅ Protocol pour le repository (testabilité)
protocol UserRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [User]
    func findById(_ id: String) async throws -> User?
}
```

---

## Gestion des erreurs

- Les erreurs métier sont des `enum` conformes à `Error` avec des cas nommés
- Les erreurs ne sont jamais ignorées silencieusement

```swift
enum UserError: LocalizedError {
    case notFound(id: String)
    case unauthorized
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .notFound(let id): return "Utilisateur introuvable : \(id)"
        case .unauthorized: return "Accès non autorisé"
        case .networkUnavailable: return "Réseau indisponible"
        }
    }
}
```

---

## Performance

- `LazyVStack` / `LazyHStack` pour les listes longues dans SwiftUI
- `List` avec identifiants stables pour les collections dynamiques
- Éviter les calculs lourds dans `body` — les déplacer dans le ViewModel ou un `@State` calculé
- Instruments (Xcode) pour profiler avant d'optimiser

---

## Sécurité

- Keychain Services pour les tokens et données sensibles — jamais `UserDefaults`
- App Transport Security (ATS) activé — vérifier `Info.plist`
- Certificate pinning via `URLSessionDelegate` pour les apps critiques
- Activer Hardened Runtime et Data Protection dans les capabilities Xcode
- Pas de données sensibles dans les logs (`os_log`)

---

## Tests

- Tests unitaires : **XCTest** (inclus dans Xcode)
- Tests UI : **XCUITest**
- Mocker les dépendances via les protocols (injection dans le constructeur)
- Tests async avec `async/await` natif dans XCTest

```swift
// ✅ Test async avec mock
final class UserListViewModelTests: XCTestCase {
    func test_loadUsers_updatesStateToLoaded() async throws {
        // Arrange
        let mockRepo = MockUserRepository(users: [User(id: "1", name: "Alice")])
        let viewModel = UserListViewModel(userRepository: mockRepo)

        // Act
        await viewModel.loadUsers()

        // Assert
        if case .loaded(let users) = viewModel.state {
            XCTAssertEqual(users.count, 1)
            XCTAssertEqual(users.first?.name, "Alice")
        } else {
            XCTFail("État attendu : .loaded")
        }
    }
}
```

---

## Conventions

| Élément | Convention | Exemple |
|---|---|---|
| Types (class, struct, enum) | UpperCamelCase | `UserProfileView`, `AuthError` |
| Fonctions / variables | lowerCamelCase | `loadUsers()`, `currentUser` |
| Protocols | nom + `Protocol` ou adjectif | `UserRepositoryProtocol`, `Sendable` |
| Extensions | organisées par conformance | `extension User: Identifiable {}` |
| Fichiers | même nom que le type principal | `UserListViewModel.swift` |

---

## Ce que tu ne fais PAS

- Publier sur l'App Store sans validation humaine
- Stocker des données sensibles dans `UserDefaults`
- Utiliser UIKit pour de nouvelles vues sans justification
- Utiliser des callbacks ou delegates là où `async/await` est disponible
- Exposer des singletons non testables — injecter les dépendances via le constructeur
