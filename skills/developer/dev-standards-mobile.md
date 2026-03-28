---
name: dev-standards-mobile
description: Standards de développement mobile — React Native, Flutter, Swift (iOS natif) et Kotlin (Android natif). Conventions, architecture, performance et bonnes pratiques par framework.
---

# Skill — Standards Mobile

## Rôle

Ce skill définit les bonnes pratiques pour le développement mobile multi-plateforme
et natif. Il complète `dev-standards-universal.md`.

---

## 🔒 Règles absolues

❌ Jamais de secrets, tokens ou credentials dans le code de l'application mobile
❌ Jamais de données sensibles dans AsyncStorage / SharedPreferences non chiffrées
❌ Jamais de contournement des mécanismes de sécurité de la plateforme
✅ Les données sensibles utilisent le Keychain (iOS) ou Keystore (Android)
✅ Toute communication réseau passe par HTTPS — certificate pinning sur les apps critiques

---

## Principes communs (tous frameworks)

- **Offline-first** : l'app fonctionne en mode dégradé sans connexion
- **Performance perçue** : les interactions < 100ms, skeleton screens sur les chargements
- **Accessibilité native** : `accessibilityLabel`, `contentDescription`, rôles sémantiques
- **Deep linking** : les écrans principaux sont accessibles via URL scheme ou universal links
- **Gestion d'état** : distinguer état local (composant), état partagé (store) et état serveur (cache requêtes)

---

## React Native

### Architecture

- Utiliser **Expo** pour les nouveaux projets (bare workflow si accès natif avancé nécessaire)
- Séparation stricte : logique métier dans des hooks/services, UI dans les composants
- Navigation : **React Navigation** (stack, tab, drawer selon le besoin)
- État global : **Zustand** (léger) ou **Redux Toolkit** (complexe) — décision à valider avec l'utilisateur
- Cache des requêtes : **TanStack Query** (`useQuery`, `useMutation`)

### Composants

- Composants fonctionnels avec hooks uniquement — pas de class components
- Props typées avec TypeScript (`interface Props`)
- `StyleSheet.create()` pour les styles — pas de styles inline dans le JSX (sauf valeurs dynamiques)
- Les composants de présentation ne font pas d'appels réseau directement

```tsx
// ✅ Bon — composant typé, styles extraits
interface UserCardProps {
  name: string
  avatarUrl: string
  onPress: () => void
}

export function UserCard({ name, avatarUrl, onPress }: UserCardProps) {
  return (
    <Pressable style={styles.container} onPress={onPress} accessibilityRole="button">
      <Image source={{ uri: avatarUrl }} style={styles.avatar} accessibilityLabel={`Avatar de ${name}`} />
      <Text style={styles.name}>{name}</Text>
    </Pressable>
  )
}

const styles = StyleSheet.create({
  container: { flexDirection: "row", alignItems: "center", padding: 12 },
  avatar: { width: 40, height: 40, borderRadius: 20 },
  name: { marginLeft: 8, fontSize: 16 },
})
```

### Performance React Native

- Utiliser `FlatList` ou `FlashList` pour les listes longues (jamais `ScrollView` + `map`)
- `React.memo()` sur les composants purs qui re-renderent souvent
- `useCallback` et `useMemo` uniquement si un problème de perf est mesuré
- Éviter les fonctions anonymes dans les props de composants de liste (crée de nouveaux refs)
- Activer Hermes (moteur JS optimisé pour React Native)

### Sécurité React Native

- Secrets API stockés côté serveur — l'app ne contient jamais de clés privées
- `react-native-keychain` pour les tokens d'authentification
- Désactiver les logs en production (`__DEV__` guard ou `react-native-logs`)
- Certificate pinning via `react-native-ssl-pinning` pour les apps critiques

### Conventions de nommage

- Composants : PascalCase (`UserProfileScreen.tsx`)
- Hooks : camelCase préfixé `use` (`useAuthState.ts`)
- Stores Zustand : camelCase suffixé `Store` (`authStore.ts`)
- Screens : suffixe `Screen` (`HomeScreen.tsx`)
- Navigation : suffixe `Navigator` (`MainTabNavigator.tsx`)

---

## Flutter

### Architecture

- Pattern recommandé : **BLoC** (business logic component) pour les apps complexes,
  **Riverpod** ou **Provider** pour les apps plus simples — décision à valider avec l'utilisateur
- Séparation : `lib/features/<feature>/` avec `data/`, `domain/`, `presentation/`
- Utiliser `freezed` + `json_serializable` pour les modèles immuables et la sérialisation

```
lib/
├── features/
│   └── auth/
│       ├── data/          ← repositories, data sources, DTOs
│       ├── domain/        ← entités, use cases, interfaces
│       └── presentation/  ← widgets, blocs/cubits, pages
├── core/                  ← thème, routing, injection, utils
└── main.dart
```

### Widgets

- Préférer `StatelessWidget` — n'utiliser `StatefulWidget` que si l'état est vraiment local à l'UI
- Extraire les widgets dans des classes dédiées (pas de méthodes `_buildXxx()` dans un gros widget)
- `const` constructors sur tous les widgets qui le permettent (optimisation de rebuild)
- `Key` sur les items de listes dynamiques

```dart
// ✅ Widget extrait, const, avec accessibilité
class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.onTap,
  });

  final String name;
  final String avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profil de $name',
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
            const SizedBox(width: 8),
            Text(name, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
```

### Performance Flutter

- Utiliser `ListView.builder` pour les listes longues (jamais `ListView` + `children: [...]`)
- `RepaintBoundary` pour isoler les parties de l'UI qui se mettent à jour fréquemment
- Éviter les rebuilds inutiles : `const`, `select()` sur les providers, `BlocSelector`
- Analyser avec Flutter DevTools (Widget Rebuild tracker, Performance overlay)

### Sécurité Flutter

- `flutter_secure_storage` pour les tokens et données sensibles
- Pas de données sensibles dans `SharedPreferences`
- Obfuscation activée en release : `flutter build --obfuscate --split-debug-info`

### Conventions Flutter

- Fichiers : snake_case (`user_profile_page.dart`)
- Classes/Widgets : PascalCase (`UserProfilePage`)
- Variables/fonctions : camelCase
- Constantes : camelCase ou lowerCamelCase (pas de SCREAMING_SNAKE_CASE)
- BLoC : suffixes `Bloc`, `Event`, `State` (`AuthBloc`, `AuthEvent`, `AuthState`)

---

## Swift (iOS natif)

### Architecture

- **SwiftUI** pour les nouvelles vues (iOS 14+) — UIKit uniquement si nécessaire
- Pattern **MVVM** : View observe ViewModel via `@ObservableObject` / `@Observable` (Swift 5.9+)
- Découper en packages Swift (`swift-package-manager`) pour les modules réutilisables

### Swift moderne

- Swift Concurrency (`async/await`, `Task`, `Actor`) — pas de callback hell
- `Sendable` sur les types partagés entre actors
- Value types (`struct`) par défaut — `class` uniquement si héritage ou identité requise
- `enum` avec associated values pour les états (loaded, loading, error)

```swift
// ✅ ViewModel avec async/await et état typé
@MainActor
final class UserListViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[User]> = .idle

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
    case idle, loading
    case loaded(T)
    case error(String)
}
```

### Sécurité iOS

- `Keychain Services` ou `CryptoKit` pour les données sensibles — jamais `UserDefaults`
- App Transport Security (ATS) activé — pas de `NSAllowsArbitraryLoads`
- Certificate pinning via `URLSessionDelegate` pour les apps critiques
- Activer les capabilities de sécurité : Hardened Runtime, Data Protection

### Conventions Swift

- Types : UpperCamelCase (`UserProfileView`)
- Fonctions/variables : lowerCamelCase
- Protocols : nom + suffixe `Protocol` ou adjectif (`UserRepositoryProtocol`, `Sendable`)
- Extensions organisées par conformances (une extension par protocole implémenté)

---

## Kotlin (Android natif)

### Architecture

- **Jetpack Compose** pour les nouvelles UI (API stable)
- Architecture **MVVM + Clean** : `ViewModel` → `UseCase` → `Repository`
- `StateFlow` / `SharedFlow` pour les états réactifs
- Injection de dépendances : **Hilt** (recommandé) ou **Koin**

### Kotlin moderne

- Coroutines + Flow pour toute logique asynchrone — pas de callbacks
- `data class` pour les modèles immuables
- `sealed class` / `sealed interface` pour les états et les résultats
- Extension functions pour enrichir les types sans héritage
- `Result<T>` ou un type `Outcome<T>` pour les résultats avec erreur explicite

```kotlin
// ✅ ViewModel avec StateFlow et sealed state
@HiltViewModel
class UserListViewModel @Inject constructor(
    private val getUsersUseCase: GetUsersUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow<UiState>(UiState.Loading)
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    init {
        loadUsers()
    }

    private fun loadUsers() {
        viewModelScope.launch {
            getUsersUseCase()
                .onSuccess { users -> _uiState.value = UiState.Success(users) }
                .onFailure { error -> _uiState.value = UiState.Error(error.message ?: "Erreur inconnue") }
        }
    }

    sealed interface UiState {
        data object Loading : UiState
        data class Success(val users: List<User>) : UiState
        data class Error(val message: String) : UiState
    }
}
```

### Sécurité Android

- `EncryptedSharedPreferences` ou `Android Keystore` pour les données sensibles
- `Network Security Config` pour forcer HTTPS et le certificate pinning
- ProGuard/R8 activé en release (`minifyEnabled = true`)
- Pas de logs en production (`BuildConfig.DEBUG` guard)

### Conventions Kotlin

- Classes/Interfaces : UpperCamelCase
- Fonctions/variables : lowerCamelCase
- Constantes : SCREAMING_SNAKE_CASE dans `companion object`
- Packages : lowercase, arborescente (`com.exemple.feature.auth`)
- Composables Jetpack Compose : PascalCase (`UserProfileScreen`)

---

## Tests mobile

### React Native

- Tests unitaires : **Jest** + `@testing-library/react-native`
- Tests E2E : **Detox** ou **Maestro**
- Tester les hooks avec `renderHook`
- Mocker les modules natifs (`@react-native-async-storage/async-storage`, etc.)

### Flutter

- Tests unitaires : `flutter_test` (inclus dans le SDK)
- Tests de widget : `WidgetTester` pour les composants UI
- Tests d'intégration : `integration_test` (sur device ou emulateur)
- Mocker avec `mockito` + `build_runner`

### Swift / Kotlin

- Tests unitaires : XCTest (Swift) / JUnit 5 + Mockk (Kotlin)
- Tests UI : XCUITest (Swift) / Espresso ou Compose UI Test (Kotlin)
- Mocker les dépendances via les protocols (Swift) ou les interfaces (Kotlin)

---

## Ce que tu ne fais PAS

- Publier sur l'App Store ou le Play Store sans validation humaine
- Contourner les politiques de sécurité des plateformes (sandboxing, entitlements)
- Utiliser des APIs dépréciées sans justification documentée
- Implémenter des notifications push sans consentement explicite de l'utilisateur
