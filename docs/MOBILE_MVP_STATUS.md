# GymBro Mobile — MVP Status

> A snapshot of what's built, what's intentionally out of scope, and what remains. Pairs with
> [`ARCHITECTURE.md`](ARCHITECTURE.md) (the *how*). Keep this current; don't append a changelog here — git is the log.

_Last reviewed: 2026-06-09 · Flutter 3.44 / Dart 3.12 · `analyze` clean · **31 tests pass** · `build web` OK._

## Implemented

**Trainee (Client) — primary experience**
- Auth: login / sign-up / forgot-reset / **silent session restore** on cold start.
- Tenant: workspace picker, switching (resets scoped state), join-by-code.
- Plans: assigned-plan consumption — Full / Guided / Blind, all redacted **server-side**.
- Session lifecycle: resume · start-from-plan · ad-hoc · single-active rule · log/edit/delete sets · skip ·
  substitute · add exercise · remove exercise · rest timer · complete · abandon.
- History + progress: volume, PRs, Monday-anchored week grouping — all client-derived from the API.

**Coach (Owner) — "coach-lite"** (role-adapted from the active workspace)
- Clients roster + invite generate/list/revoke.
- Client monitor: assignments + sessions (`WorkoutLogViewAll`), pause/resume + apply-latest.
- Coach plans **view** + **assign** (pins current version; visibility + hide flags).
- Self-train (assign a plan to self at Full visibility, then log from the Log tab).

## Intentionally out of scope (not gaps)
- **Plan authoring / versioned editing** — portal-first by design; mobile is view + assign only.
- **Offline mode** — online-only for MVP (no `drift`/`isar` mutation queue). Metrics are server-computed.
- **Platform Admin** surface — excluded from mobile.
- **Push notifications / deep links / app-links** — deferred to hardening.
- **Codegen / committed `openapi.json`** — models are hand-written (see ARCHITECTURE §11).

## Known limitations / tech debt
- **`MeController` fallback shim** — `SessionRepository.myHistory`/`myDetail` fall back to tenant-scoped
  `list`/`detail` on a 404, so Log/Progress/post-finish detail work on live servers that predate `MeController`
  (single-gym instead of cross-gym aggregation). Remove once every target server exposes `/api/me/*`. Covered by
  `test/data/session_repository_fallback_test.dart`.
- **Two large screen files** — `features/session/live_session_screen.dart` (~1.4k lines) and
  `features/log/log_screen.dart` (~0.9k). Both are well-decomposed internally (many small private widgets), so this
  is navigation cost, not a god-class. Safe future refactor: extract the private widgets into sibling files under
  the feature folder; no logic change.
- **Dependencies pinned for stability** — `flutter pub outdated` lists newer majors (notably `riverpod` 2→3); not
  upgraded for MVP. Revisit deliberately, not casually.
- **iOS / `flutter_secure_storage`** — emits a Swift Package Manager deprecation warning (analyzer noise only).

## Remaining work after MVP (suggested order)
1. Deploy `MeController` everywhere, then delete the fallback shim + its test.
2. Hardening: offline session-logging queue, push/reminders, deep links.
3. Store launch: signing, real app icons, `flutter build ipa/appbundle` in CI (`gymbroapp` `ci.yml`).
4. Optional: split the two large screen files; revisit dependency majors.
