# GymBro Mobile (`gymbroapp`)

A **Flutter client** for the existing GymBro platform. It is *not* a new product — it consumes the
production .NET API exactly as the Angular portal does, and follows the Claude Design mobile prototype for
navigation and screen structure. Business correctness is the priority; the UI is Material 3 themed to the
design tokens and meant to be reskinned later without touching logic. It ships **both roles**, role-adapted
from the active workspace: the **trainee (Client)** experience is primary, with a **coach-lite (Owner)**
surface alongside it.

> **Sources of truth**
> - System behavior / API / business rules → `../gymbro/docs/` (BUSINESS_RULES, AUTHENTICATION,
>   PERMISSIONS, DATABASE, USER_FLOWS, ARCHITECTURE).
> - **As-built client architecture** → [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
> - **Build status / scope / known limits** → [`docs/MOBILE_MVP_STATUS.md`](docs/MOBILE_MVP_STATUS.md).
> - Mobile navigation / screens / UX → [`docs/design-reference/`](docs/design-reference/) (the vendored
>   Claude Design prototype) and [`docs/DESIGN_COMPLIANCE.md`](docs/DESIGN_COMPLIANCE.md).

## Status

**Trainee (Client):** authentication (login / sign-up / forgot-reset / **session restore**), **tenant
selection + switching + join-by-code**, assigned **plan consumption** (Full/Guided/Blind, all redacted
server-side), the full **workout session lifecycle** (resume / start-from-plan / ad-hoc / single-active /
log·edit·delete sets / skip / substitute / add·remove exercise / rest timer / complete / abandon), and
**session history + progress** (volume, PRs, week grouping — all client-derived).

**Coach-lite (Owner):** clients roster + invite generate/list/revoke, plan **view** + assign, client
monitoring (assignments + sessions, pause/resume + apply-latest), and self-train. Plan **authoring** stays
portal-first (intentionally not built here). See [`docs/MOBILE_MVP_STATUS.md`](docs/MOBILE_MVP_STATUS.md).

## Quick start

Flutter/Dart are required (not bundled in this repo's dev environment). Then:

```bash
cd gymbroapp
# Generate the platform runners (android/ios/...) — preserves lib/ and pubspec.yaml:
flutter create --platforms=android,ios,web .
flutter pub get
flutter analyze
flutter test                     # pure-logic + model-parsing tests under test/
flutter run                      # dev → local API (http://localhost:5216), no flags needed
```

### Environments

Two environments are baked in (`lib/core/config/app_config.dart`). The default is **dev → local API**,
so a plain `flutter run` talks to a locally-running backend with zero flags. Switch to the live host
only when you need it:

```bash
flutter run                                          # dev  → http://localhost:5216 (local `dotnet run`)
flutter run --dart-define-from-file=config/prod.json # prod → https://gymbro.ddns.net (live)
flutter run --dart-define=GYMBRO_ENV=prod            # prod, flag form (no file)
```

`apiBaseUrl` resolves in this order: an explicit `GYMBRO_API_BASE_URL` wins (this is what
`config/dev.json` / `config/prod.json` set), otherwise `GYMBRO_ENV` (`dev` default → local, `prod` →
live) picks the baked-in host. Android emulators can't see the host's `localhost` — point dev at the
loopback with `--dart-define=GYMBRO_DEV_API_BASE_URL=http://10.0.2.2:5216` (or `:8080` for a Dockerised API).

## Architecture (feature-first, server-authoritative)

```
lib/
├── main.dart                 # bootstrap: load tenant + silent refresh, then runApp
├── app/                      # MaterialApp.router, go_router (StatefulShellRoute), theme + GbColors tokens
├── core/
│   ├── config/               # AppConfig (base URL, timeouts)
│   ├── network/              # Dio, AuthInterceptor (Bearer + X-Tenant-Id), single-flight 401 refresh,
│   │                         #   ApiException (status-driven), secure-storage cookie jar
│   ├── auth/                 # TokenStore (in-memory access), TokenRefresher (single-flight)
│   ├── tenant/               # TenantStore (synchronous active X-Tenant-Id, persisted)
│   ├── storage/              # secure storage wrapper
│   └── providers.dart        # DI graph (stores → dios → refresher → repos)
├── domain/                   # PURE Dart: enums (tolerant wire parsing), session metrics, week grouping
├── data/
│   ├── models/               # hand-mirrored DTOs (camelCase JSON, tolerant enums)
│   └── repositories/         # one per API area (auth, tenant, session, plan, exercise)
└── features/                 # auth · tenant · shell · log · plan · session · progress · profile · coach
                              #   (each: Riverpod controller/providers + thin screens; coach = Owner surface)
```

### Key decisions
- **Refresh transport = the existing cookie.** The API's `/api/auth/refresh` is cookie-only (the planned
  native body-transport was never built), so the client uses a `dio_cookie_manager` jar **backed by the
  OS keystore** to speak the exact protocol. Access token stays in memory. See
  `core/network/secure_cookie_storage.dart`.
- **No code-gen / openapi here.** There is no committed `openapi.json` and the codegen toolchain isn't
  available, so models are hand-written to mirror the C# DTOs, with tolerant enum (de)serialization
  (API emits camelCase; snapshot `setType` is PascalCase; both + ints are accepted).
- **The API is the only business/security boundary.** Visibility redaction, the session state machine,
  the single-active rule, and metric math are all server-enforced; the client renders and lightly
  derives. UI guards are UX-only.
- **State management = Riverpod.** Providers ≈ the portal's service signals; tenant-scoped providers
  watch `activeTenantIdProvider` so a workspace switch resets them (no cross-workspace bleed).

## Navigation (per the design prototype)

`StatefulShellRoute` with tabs **Log · Plan · Progress · Profile** (Log = home). Live session
(`/session/:id`) and session detail (`/session-detail/:id`) are full-screen routes pushed above the
shell. Auth is a pre-shell phase gated by an auth redirect that runs after the bootstrap silent refresh.

## Tests

`test/` covers the business-critical pure logic and wire parsing (no device needed):
`domain/enums_test.dart`, `domain/session_metrics_test.dart`, `domain/session_grouping_test.dart`,
`data/session_models_test.dart`.
