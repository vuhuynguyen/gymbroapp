# GymBro Mobile — Design Compliance

> The mobile **design rules** (navigation, screen responsibilities, interaction standards) extracted from the
> Claude Design bundle vendored to [`design-reference/`](design-reference/), and a current snapshot of how the
> implementation conforms. The design bundle is the reference for *flows / navigation / UX*; the GymBro API and
> portal are the reference for *business rules*. For build status and scope see
> [`MOBILE_MVP_STATUS.md`](MOBILE_MVP_STATUS.md); for structure see [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## 1. Design rules — see `design-reference/`

The authoritative design rules (navigation, screen responsibilities, interaction standards, the token system) are
the **Claude Design bundle vendored to [`design-reference/`](design-reference/)** — that is the source of truth;
this doc does **not** restate it. The conformance table (§2) and the deliberate divergences (§3) below are what's
unique here.

A few load-bearing **as-built** anchors the conformance table checks against (where the shipped app deviates from,
or pins down, the bundle):

- **Shell:** bottom-tab `StatefulShellRoute`; trainee tabs **Log · Plan · Progress · Profile** (Workout Log is
  home); coach tabs **as built** are **Coach · Log · Progress · Profile** (`features/shell/home_shell.dart`; the
  bundle's "Plans · Log · Clients · Profile" names are superseded by the as-built order). `/log` is the universal
  landing.
- **Full-screen routes above the shell:** `/session/:id` (live session, focus mode), `/session-detail/:id`, and
  the nutrition routes `/nutrition-history`, `/nutrition-day/:date`, `/my-foods`. The daily food log itself is a
  section on the Log home (no dedicated Nutrition tab).
- **Interaction:** dialogs are bottom sheets; weight/reps steppers; rest timer auto-starts after a logged set
  (UI-only, not persisted); weights in **kg**; **RPE integer 1–10**; loading/empty/error on every async surface;
  a11y (Semantics labels, stepper value+unit announce, reduced-motion safe).
- **Tokens:** `inv-*`/`gb-*` → typed `GbColors` `ThemeExtension`; **blue primary, no purple**; "Inter Tight";
  **zero hex literals** in feature code (`context.gb.*` + `App*` token classes).

---

## 2. Current compliance

The implementation conforms to the rules above. Spot-check anchors:

| Area | Conforms | Where |
|---|:---:|---|
| Role-adaptive shell + universal `/log` landing | ✅ | `app/router.dart` |
| Live session full-screen + session-detail (self/tenant scope via `?me=1`) | ✅ | `features/session/*` |
| Steppers, rest timer, ⋯ substitute/skip, bottom-sheet pickers | ✅ | `live_session_screen.dart`, `shared/widgets/sheets.dart` |
| Log: hero/resume, week ring, filter chips, collapsible week groups | ✅ | `features/log/log_screen.dart` |
| Plan read-only redacted render; Progress client-derived stats | ✅ | `features/plan`, `features/progress` |
| Loading / empty / error on async surfaces | ✅ | `AsyncValueView` / `EmptyState` / `ErrorRetry` / `GbSkeleton` |
| Tokenised styling, zero hex in features; Inter Tight | ✅ | `core/theme`, `core/tokens` |
| A11y (Semantics, stepper announce, reduced motion) | ✅ | `widgets/a11y_motion_test.dart` |

## 3. Deliberate divergences from the prototype mock (business-correctness wins)
- **Skip** = skip a whole exercise, allowed only with **zero logged sets** (else 409) — not the mock's local
  per-set marking.
- **Substitute** uses a real catalog `exerciseId` from the `GET /exercises` picker — not the mock's canned list.
- **"Repeat workout"** (a mock detail action) has no dedicated API; implemented as start-from-the-same-assignment
  or omitted — no invented endpoint.

## 4. Deferred polish (post-MVP)
Platform-adaptive Cupertino chrome; pixel-exact shadow stacks; the separate `mobile/reimagined/` exploration in the
bundle (the target was the polished Prototype, not Reimagined).
