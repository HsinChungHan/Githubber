# Githubber

A sample GitHub user & repository browser app built with **Clean Architecture** + **MVVM**, featuring pagination, search, caching, and favorites.

---

## Features

### Core
- ✅ Paginated browsing of public GitHub users (`GET /users`)  
- ✅ User search (`GET /search/users`)  
- ✅ Display user details (followers / following / avatar)  
- ✅ List user repositories  
- ✅ Built-in WebView to open repository pages  

### Extras
- ✅ **Local Cache**  
  - Cache user lists, user details, repo lists, and avatars locally  
  - Uses a custom Actor–Codable store based on `RHCacheStoreAPI`  
- ✅ **Favorites**  
  - Mark/unmark repositories as favorites  
  - View favorites in the “Favorites” tab  
- ✅ **Pagination**  
  - All `UITableView`s implement infinite scroll: load next page automatically when scrolled to bottom  

---

## Architecture

```
Presentation Layer (MVVM)
├─ ViewControllers
│   ├─ UserListViewController
│   ├─ UserRepoViewController
│   └─ FavoriteReposViewController
└─ ViewModels
    ├─ UserListViewModel
    ├─ UserRepoViewModel
    └─ FavoriteReposViewModel

Domain Layer
└─ UseCases
    ├─ GetUsersUseCase
    ├─ SearchUsersUseCase
    └─ FavoriteReposUseCase

Data Layer (Clean Architecture)
├─ Repositories
│   ├─ RemoteUserRepository          ← `RHNetworkAPIProtocol`
│   ├─ StoreUsersRepository          ← `RHCacheStoreAPIProtocol`
│   ├─ StoreUsersReposRepository     ← `RHCacheStoreAPIProtocol`
│   └─ StoreFavoriteReposRepository  ← `RHCacheStoreAPIProtocol`
└─ Data Sources
    ├─ Remote Network Framework (custom)
    └─ Local Store Framework (custom)
```

## API Validation & DTO

- **End-to-End Testing**  
  - Write e2e tests for each GitHub API endpoint to verify response formats  
  - Define and generate matching Data Transfer Objects (DTOs) based on test results  

- **Dependency Inversion & Injection**  
  - Domain layer defines repository interfaces (protocols) so UseCases never depend on concrete implementations  
  - Inject Mock Repositories into UseCases during unit tests  
  - Example: `SearchUsersUseCaseTests` uses `MockSearchRemoteRepo` to validate search logic  

---

## Third-Party Libraries & SPM

- **SnapKit** – UI layout  
- **RHNetworkAPI** (Remote Network framework) – custom, provides `RHNetworkAPIProtocol`  
- **RHCacheStoreAPI** (Local Store framework) – custom, provides `RHActorCacheStoreAPIProtocol`  
- All managed via Swift Package Manager (SPM)  

---

## GitHub Personal Access Token

- To avoid GitHub API rate limits, `RemoteUserRepository` currently uses a PAT (Personal Access Token) from a disposable personal account for testing only.  
- **Future plan:** Remove the hard-coded token and switch to OAuth flow or CI/CD Secrets (environment variables).  

---

## Highlights

- **Clean Architecture + MVVM** – clear separation of concerns, easy to extend & test  
- **Custom Network & Cache Frameworks** – minimal external dependencies, fully customizable  
- **Pagination + Local Cache** – reduces unnecessary network calls, smooth UX  
- **Favorites** – swipe actions for quick favorite/unfavorite  
- **Mermaid UML** – visualizes high-level module dependencies  
- **Comprehensive Testing** – end-to-end & unit tests demonstrate DTO generation, UseCase logic, and mock repository injection  

