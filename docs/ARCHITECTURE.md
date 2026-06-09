# GymBro Mobile — Architecture (as built)

> The **shipped** architecture of the GymBro Flutter client. This describes what the code actually does today,
> so a future session can work without re-scanning the tree. For the *original* pre-build design rationale and
> the roads not taken (codegen, native refresh transport, offline queue), see the deploy-root
> `MOBILE_STACK_RECOMMENDATION.md` — note that several of its proposals were intentionally **not** adopted (see
> [§11 Deviations](#11-deviations-from-the-original-plan)).

**Source of truth — do not duplicate here.** API contracts, permissions, and business rules live in
[`../../gymbro/docs/`](../../gymbro/docs/) (`AUTHENTICATION.md`, `PERMISSIONS.md`, `BUSINESS_RULES.md`,
`USER_FLOWS.md`, `DATABASE.md`). This document is the *client* architecture only.

---

## 1. What this app is

A Flutter client for the existing GymBro platform. It consumes the production .NET 10 API exactly as the Angular
portal does — **the API is the only security/business boundary; the client renders and lightly derives.** It ships
both roles, role-adapted from the active workspace:

- **Trainee (Client)** — the primary experience: assigned-plan consumption, the full workout-session lifecycle,
  history + progress.
- **Coach (Owner), "coach-lite"** — roster + invites, plan **view** + assign, client monitoring, self-train.
  Plan *authoring* stays portal-first (intentionally not built here).

UI is Material 3 themed to the design tokens; it's structured so styling can be reskinned without touching logic.

## 2. Stack

| Concern | Choice |
|---|---|
| State | `flutter_riverpod` (providers ≈ the portal's service signals) |
| Networking | `dio` + `dio_cookie_manager` + `cookie_jar` |
| Secrets at rest | `flutter_secure_storage` (refresh cookie persisted to the OS keystore) |
| Navigation | `go_router` (`StatefulShellRoute`) |
| Typeface | `google_fonts` (Inter Tight, the portal/design face) |

Models are **hand-written** to mirror the C# DTOs (no codegen — see §11). Lints: `flutter_lints` +
`strict-casts`/`strict-raw-types`/`avoid_print` (`analysis_options.yaml`).

## 3. Folder structure

```
lib/
├── main.dart                 # bootstrap: load tenant + silent refresh + pre-resolve role, then runApp
├── app/
│   ├── app.dart              # MaterialApp.router
│   ├── router.dart           # go_router; role-adaptive StatefulShellRoute + full-screen routes
│   └── theme.dart            # legacy re-export shim → core/theme (kept for back-compat)
├── core/
│   ├── config/app_config.dart    # baked-in dev/prod hosts + dart-define overrides
│   ├── network/                  # Dio wiring, interceptors, ApiException, secure cookie jar
│   ├── auth/                     # TokenStore (in-memory access), TokenRefresher (single-flight)
│   ├── tenant/tenant_store.dart  # synchronous active X-Tenant-Id + active role; persisted
│   ├── storage/secure_store.dart # flutter_secure_storage wrapper
│   ├── tokens/                   # design primitives: spacing, radius, shadows, sizes, durations
│   ├── theme/                    # palette → GbColors ThemeExtension → ThemeData; barrel: theme.dart
│   ├── utils/json.dart           # tolerant asString/asInt/asBool/asDate parse helpers
│   └── providers.dart            # DI graph (stores → dios → refresher); repos provide their own
├── domain/                   # PURE Dart (no Flutter): enums (tolerant wire), metrics, week grouping
├── data/
│   ├── models/               # hand-mirrored DTOs (camelCase JSON, tolerant enums)
│   └── repositories/         # one per API area: auth · tenant · session · plan · exercise
├── features/                 # auth · tenant · shell · log · plan · progress · profile · session · coach
│                             #   each: Riverpod controller/providers + thin screens
└── shared/widgets/           # ~40 reusable widgets + design-system barrel; import widgets.dart
```

Import discipline: feature code imports `shared/widgets/widgets.dart`, which **re-exports** the design-system
barrel (`core/theme/theme.dart`) — one import yields both tokens and widgets. Don't style with raw colors/magic
numbers; use `context.gb.*` (the `GbColors` extension) and the `App*` token classes.

## 4. Networking & DI (`core/providers.dart`)

Acyclic graph: `stores → authDio → tokenRefresher → apiDio → repositories`.

- **`authDio`** — interceptor-free, cookie-manager only. Used for the auth endpoints
  (login/register/refresh/logout/forgot/reset) so a 401 there never recurses into a refresh.
- **`apiDio`** — cookie manager + `AuthInterceptor` + `RefreshInterceptor`. Used by every authenticated repo.
- **`AuthInterceptor`** attaches `Authorization: Bearer`, the membership-validated `X-Tenant-Id` (only when a
  tenant is active), and optional `X-Api-Version`. Direct port of the portal's `authInterceptor`.
- **`RefreshInterceptor`** (a `QueuedInterceptor`): on a 401 from a non-auth call, runs **one** single-flight
  refresh (deduped by `TokenRefresher`) and replays the original request once with the fresh token. On failure it
  clears the token store and the router redirect bounces to login. Port of the portal's `error-interceptor`.

**Error mapping** — `ApiException.fromDio` (`core/network/api_exception.dart`) maps HTTP status → a typed
`ApiErrorKind` (network/unauthorized/forbidden/notFound/conflict/validation/rateLimited/server/unknown) and reads
either body shape (bare string from `ToFailureResult`, or `{code,message}` from auth). UI branches on the kind
(e.g. `isConflict` for a second active session). Wrap repo calls in `apiCall(...)` to get this typing.

## 5. Auth & session restore

- **Access token** in memory only (`TokenStore`, also a `Listenable` the router refreshes on).
- **Refresh token** is the existing **httpOnly cookie**, persisted to the OS keystore via a
  `flutter_secure_storage`-backed `PersistCookieJar` (`core/network/secure_cookie_storage.dart`). The app speaks
  the *exact* cookie refresh protocol the API already has — no API change was required (see §11).
- **Boot** (`main.dart`): load persisted tenant → silent `restoreSession()` against the stored cookie →
  pre-resolve the active workspace role → `runApp`. So the first router redirect already knows auth + role.

## 6. State management (Riverpod)

Providers are the analogue of the portal's "state in services + signals."

- **Tenant-scoped providers watch `activeTenantId`** so a workspace switch resets them — no cross-workspace
  bleed (the portal rule, ported).
- **Server state** via `FutureProvider`/controllers per feature; `ref.invalidate` covers refetch.
- **Derivations** (volume, weekly totals, progress %, PR flags, week grouping) live in `domain/` pure functions —
  client-side, exactly as the portal computes them with `computed()`.

## 7. Navigation (`app/router.dart`)

`StatefulShellRoute.indexedStack`, branches in fixed order: **log · plan · progress** (trainee), **clients ·
coach-plans** (coach), **profile** (shared). `/log` is the universal landing for both roles.

- **Role-adaptive redirect** (re-runs on token/tenant change): unauthenticated → `/login`; an Owner is bounced off
  trainee-only `/plan`,`/progress`; a Client is bounced off coach roots and `/client/`,`/assign/`,`/plan-view/`.
  These guards are **UX-only** — the server 403s regardless.
- **Full-screen routes above the shell**: `/session/:id` (live session), `/session-detail/:id` (carries `?me=1`
  to pick self- vs tenant-scoped detail), `/start`, `/join`, `/workspaces`, and the coach screens.

## 8. The two API surfaces (critical)

| Surface | Header | Scope | Used by |
|---|---|---|---|
| `/api/me/*`, `/api/sessions/active` | **no** `X-Tenant-Id` | self, **cross-gym** | trainee Log / history / progress / own detail / resume |
| `/api/sessions/*` (and plans/assignments) | `X-Tenant-Id` **required** | one gym | coach client-monitor (`WorkoutLogViewAll`), session mutations |

`SessionRepository.myHistory`/`myDetail` fall back to the tenant-scoped `list`/`detail` on a `404` — a
graceful-degradation shim for live servers that predate `MeController` (see [MOBILE_MVP_STATUS](MOBILE_MVP_STATUS.md)).

## 9. Design system

`core/tokens/*` (primitives: spacing, radius, shadows, sizes, durations) + `core/theme/*` (palette → `GbColors`
`ThemeExtension` → `ThemeData`) → barrel → re-exported by `shared/widgets/widgets.dart`. Blue primary, no purple;
1:1 port of the design `--inv-*` / `--gb-*` tokens. Feature code carries **zero hex literals**. Reusable kit
(~40 widgets) covers cards, buttons, chips, steppers, sheets, headers, stats, and the async-state trio
(`AsyncValueView` / `EmptyState` / `ErrorRetry` / `GbSkeleton`). A11y: icon buttons carry `Semantics`, steppers
announce value+unit, infinite animations hold a steady end state under reduced motion.

## 10. Business rules the client honors

Server-enforced; the client only gates UX and surfaces failures. Single active session across all gyms (a 2nd
`POST /api/sessions` → 409); mutations only while `InProgress`; `Skip` needs zero logged sets (else 409);
`Substitute` records provenance; weights stored/displayed in **kg**; **RPE is an integer 1–10**; Full/Guided/Blind
visibility is redacted server-side (render as-is; `Blind` start seeds no snapshot). See
`gymbro/docs/BUSINESS_RULES.md`.

## 11. Deviations from the original plan

The pre-build design (`MOBILE_STACK_RECOMMENDATION.md` and earlier drafts of this doc) proposed several things that
were **deliberately not adopted** — recorded here so they aren't mistaken for missing work:

| Proposed | Shipped instead | Why |
|---|---|---|
| `openapi.json` → `dart-dio` generated client | **Hand-written models** mirroring the C# DTOs, tolerant enums | No committed spec / codegen toolchain; hand models are small and stable |
| New **native (body) refresh transport** added to the API | Reuse the **existing cookie** refresh via a keystore-backed cookie jar | No API change needed; the cookie protocol already works |
| `drift`/`isar` **offline mutation queue** | Online-only (Riverpod caching + `ref.invalidate`) | Out of MVP scope; metrics are server-computed |
| `fl_chart` for progress charts | Lightweight custom painters / bars | Avoid a dependency for simple visuals |
| "Member-only; coaches keep the portal" | **Coach-lite shipped** (view + bounded mutations) | Later product decision |

## 12. Testing

`test/` covers the business-critical pure logic + wire parsing, no device needed: `domain/enums_test.dart`,
`domain/session_metrics_test.dart`, `domain/session_grouping_test.dart`, `data/session_models_test.dart`,
`data/session_repository_fallback_test.dart`, `core/api_exception_test.dart`, `widgets/a11y_motion_test.dart`.
Run `flutter analyze && flutter test`. (31 tests at time of writing.)
