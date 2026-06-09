# GymBro Mobile — Design Compliance

> The mobile **design rules** (navigation, screen responsibilities, interaction standards) extracted from the
> Claude Design bundle vendored to [`design-reference/`](design-reference/), and a current snapshot of how the
> implementation conforms. The design bundle is the reference for *flows / navigation / UX*; the GymBro API and
> portal are the reference for *business rules*. For build status and scope see
> [`MOBILE_MVP_STATUS.md`](MOBILE_MVP_STATUS.md); for structure see [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## 1. Design rules (authoritative)

### Navigation
1. **Bottom-tab `StatefulShellRoute`**, per-tab navigator stacks preserved. Trainee tabs: **Log · Plan · Progress
   · Profile**; the **Workout Log is home**. Coach tabs (same shell, role-adapted): **Plans · Log · Clients ·
   Profile**. `/log` is the universal landing.
2. **Live Active Session is full-screen** (`/session/:id`, above the shell — focus mode, no tab bar).
3. **Session Detail is full-screen** (back chevron normally; `X` + "Workout complete" banner when opened straight
   from finishing).
4. Auth is a **pre-shell phase**: splash → silent refresh → target or Log; one refresh-and-replay before logout on 401.
5. **Start Workout** is the centre item of the bottom nav (in-row filled button, shared across both shells).

### Screen responsibilities
- **Log (home):** active-session hero (resume) · week goal ring · filter chips · collapsible Monday-anchored week
  groups (per-week ring + PR chip) · session rows · "Start Workout" → bottom sheet (today's plan vs ad-hoc).
- **Plan:** current-program hero (week x/total, days/wk, visibility) · day chips · **read-only** exercise list
  (render server-redacted data as-is).
- **Progress:** stat tiles (Sessions / Total kg / PRs) · weekly-volume bars · recent PRs — all client-derived.
- **Profile:** profile card · menu (my profile, join a coach, change password, workspace switch) · sign out.
- **Live session:** gradient header (leave · name·day·week · progress) · exercise pager chips (+ Add) ·
  current-exercise card with ⋯ = Substitute / Skip · set rows (done/skipped/current/pending) · WEIGHT (±2.5) +
  REPS (±1) steppers + Log set · rest-timer bar after each log · action bar (prev / Next / Finish). Bottom sheets
  for more / substitute / add-exercise / abandon / set-type.
- **Auth:** one screen, segmented Log in / Sign up, forgot-password link, join-with-invite-code.

### Interaction & UX standards
- **Dialogs are bottom sheets** on mobile (start, substitute, add, abandon, set-type, confirms).
- **Steppers** for weight/reps; **rest timer** auto-starts after a logged set (UI-only stopwatch — not persisted).
- **Weights display in kg**; **RPE is an integer 1–10**.
- **Loading (skeleton), empty, and error states for every async list/detail.**
- A11y: icon-only buttons carry a `Semantics` label; steppers announce value + unit; respect reduced motion.

### Design system
- `inv-*` / `gb-*` tokens → a typed `GbColors` `ThemeExtension`. **Blue primary, no purple** (`#3b82f6` /
  `#2563eb` / `#1d4ed8`); radii 8/12/16/20; "Inter Tight". **No hex literals in feature code** — use `context.gb.*`
  + the `App*` token classes.

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
