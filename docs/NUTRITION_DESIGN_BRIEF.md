# GymBro Mobile — Nutrition Module Design Brief

> **For:** a Claude Design pass on the Flutter (gymbroapp) **Nutrition** screens.
> **One-file brief.** Everything needed to design the screens: product intent, scope, the existing design
> language to extend, screen-by-screen specs (purpose · states · real data fields · reuse), and a data
> dictionary. Built from the **as-built** backend — every field listed is one the app actually receives.

## 0. How to use this

- **Extend the existing app, don't invent a new language.** GymBro mobile already ships Log · Plan · Progress ·
  Profile with a defined design system (see §2 and `docs/design-reference/`). Nutrition must look like it was
  always there.
- **Design the states, not just the happy path.** Each screen below lists its loading / empty / error /
  populated / per-item states. Cover them.
- **Stay in scope (§1).** Don't design deferred capabilities — they'll read as scope creep.

---

## 1. What we're building & scope

**Product wedge — completion-first, not calorie-counting.** A coach prescribes a daily meal/supplement plan; the
trainee sees **today as a checklist** and logs each item in *one tap* (ate it / skipped / swapped), plus quick
off-plan logging. The single daily question is *"did you follow your plan?"* — a sub-10-second, one-handed
interaction they'll actually sustain. Macros ride along invisibly (captured per item) so richer views can come
later. At day's end an **adherence ring** summarizes meals hit ÷ planned.

**Two roles** (the app is trainee-first with a coach-lite surface):
- **Trainee (primary):** the Today checklist, day history, food picker. *This is the hero of the design pass.*
- **Coach (secondary, coach-lite):** view a client's nutrition adherence + drill into a day. Plan **authoring**
  stays web/portal-first — **do not design plan-building here.**

### Design THIS pass
1. **Today** (trainee hero) — the daily checklist + adherence ring + logging actions.
2. **Food picker** — search the catalog to log an off-plan item or substitute.
3. **Nutrition history** — list of past days with adherence; tap → read-only day detail.
4. **No-plan empty state** — trainee with no active nutrition plan.
5. **Coach client-nutrition** — adherence list + day detail (secondary).

### Do NOT design this pass (deferred — would read as scope creep)
Reminders/notifications UI · offline/sync indicators · body-weight / water / sleep / mood **metrics** · macro
dashboards & trend charts · plan **authoring/builder** · visibility-redaction toggles · barcode scanning · AI
suggestions.

---

## 2. Design system to extend (hard constraints)

Pulled from the shipped app (`docs/ARCHITECTURE.md`, `docs/DESIGN_COMPLIANCE.md`, `docs/design-reference/`):

- **Material 3, themed to GymBro tokens.** Color via the `GbColors` `ThemeExtension` (`context.gb.*`); spacing /
  radius / shadows / sizes via the `App*` token classes. **Zero hex literals.** **Blue primary, no purple.**
  Typeface **Inter Tight**.
- **Reuse the ~40-widget kit** — don't build new primitives where one exists:
  - Surfaces: `GbCard`, `GbHeroCard` · Buttons: `GbButton` (filled / outlined / ghost; primary / secondary)
  - Async states: **`AsyncValueView` / `EmptyState` / `ErrorRetry` / `GbSkeleton`** (use these for every load)
  - `chips_badges` (status chips), `sheets` (bottom sheets), `headers`, `stats` (stat tiles / progress), the
    `session` set-card style (a close cousin of a logged item), `foundation` (Avatar, BrandMark).
- **Match the existing visual rhythm:** the **Log** screen's completion-ring + week-group cards and the
  **active-session** focused-logging screen are the two closest references — Today should feel like their child.
- **A11y:** tap targets ≥ 44px, icon buttons carry semantics, value+unit announced, reduced-motion safe (the kit
  already does this — keep it).

---

## 3. Navigation

The trainee shell is a bottom-tab `StatefulShellRoute` (today: Log · Plan · Progress · Profile). **Add a primary
`Nutrition` tab** — proposed trainee order **Log · Nutrition · Progress · Profile** (Nutrition is a daily-return
surface; the plan *view* folds into a header action rather than its own tab, so the bar stays at 4).

- **Tab icon:** a food/utensils or apple glyph (Material), consistent weight with the other tabs.
- **Full-screen routes above the shell** (like `/session/:id`): a **past-day detail** view and the **food
  picker** (can also be a bottom sheet — your call; sheet is preferred for the picker).
- **Coach** reaches client nutrition from the existing client-monitor screen (a segment/tab beside workout
  history) — not a new top-level tab.

---

## 4. Screen-by-screen

### A. Today (trainee hero) — `/nutrition` tab landing

**Purpose:** log today's plan fast; show adherence at a glance.

**Layout (top → bottom):**
1. **Header** — date ("Today, Mon 15 Mar"), and an **adherence ring** (the hero stat) showing
   `completedCount / plannedCount` with the `adherencePct` in the center. Reuse the Log screen's completion-ring
   visual. Optional tiny macro readout under it (sum of completed items' kcal/protein) — *secondary, can omit.*
2. **Meals list** — grouped by **meal**, in schedule order. Each meal is a section: meal **name** + **scheduled
   time** (e.g. "Breakfast · 8:00"), then its items.
3. Each **item row** (the core unit): food **name**, **serving** ("1 bowl", "100 g") × **quantity**, optional
   macro line (kcal · P/C/F), and a **leading state control** (tap target) reflecting status (below).
4. **Floating "+" (FAB)** — log an **off-plan** item (opens the Food picker → confirms an ad-hoc entry).

**Item interaction (completion-first):**
- **Single tap** on the row's control → **Completed** (instant optimistic check; ring animates).
- **Secondary action** (long-press, swipe, or a small kebab → bottom sheet) → **Skip** or **Swap (substitute)**.
- Swapping opens the Food picker; the row then shows the new food with a subtle "swapped" indicator.

**Item status visuals — all five must be distinct:**
| Status | Meaning | Visual direction |
|---|---|---|
| **Planned** | not yet logged | empty check / neutral row, fully legible |
| **Completed** | ate it | filled check, success accent (`gb` success) |
| **Skipped** | *chose* to skip | muted/strikethrough + "skipped" chip (intentional, calm) |
| **Substituted** | swapped food | completed-style check + small swap glyph; shows the new food |
| **Missed** | day closed, never logged | warning/danger accent + "missed" chip (only on closed days) |

> **Skipped ≠ Missed is a real product distinction** — a coach reads them differently. Make them visually
> separable (skip = deliberate/calm; missed = a gap/alert).

**States:**
- **Loading:** `GbSkeleton` rows under a skeleton ring (`AsyncValueView`).
- **No plan (`hasPlan: false`):** the **No-plan empty state** (screen E) — *not* an empty checklist.
- **Plan, nothing logged yet:** all items Planned, ring at 0%.
- **Day closed** (a past "today" the user reopens): read-only; still-Planned items show as **Missed**; no tap
  actions; show a small "locked / day closed" affordance.
- **Error:** `ErrorRetry`.

---

### B. Food picker — full-screen route or bottom sheet (sheet preferred)

**Purpose:** find a food to **add off-plan** or **substitute**.

**Layout:** search field (top) → results list. Each result: **name**, optional **brand**, a **kind** chip
(Food / Supplement / Beverage), serving label, and a compact macro line. Tapping a result → a small **confirm**
step (quantity stepper, defaulting to 1 serving) → returns to Today.

**States:** idle/typing prompt ("Search foods…"), loading (skeleton list), **empty results** ("No foods match
'…'"), error. **Note the MVP limit:** a trainee picks from the **catalog only** — they *cannot* create a custom
food (that's an Owner capability). So the empty state is "not found" guidance, **not** an "add custom food" CTA.

---

### C. Nutrition history — secondary tab content or a header action from Today

**Purpose:** see adherence over time; revisit a day.

**Layout:** a list of **day cards** (most-recent first), each: **date**, a small **adherence ring or %**,
`completedCount/plannedCount`, and a source hint (plan vs ad-hoc). Tapping → **read-only day detail** (same row
layout as Today but no actions; closed days show Missed items).

**States:** loading (skeleton cards), **empty** ("No nutrition logged yet — open Today to start"), error. Group
by week if it helps scannability (mirror the Log screen's week grouping), but a flat list is acceptable.

---

### D. Item action sheet (used by Today)

A small bottom sheet (reuse `sheets`) offering **Complete · Skip · Swap** for a planned item, and **Edit
quantity · Remove** for an ad-hoc item. Keep it 2–4 actions, thumb-reachable. (Or fold Complete into the row tap
and use the sheet only for Skip/Swap — designer's call; optimize for speed.)

---

### E. No-plan empty state (trainee with no active nutrition assignment)

**Purpose:** the trainee has *no* nutrition plan assigned, so there's nothing to log yet (MVP: logging requires an
active assignment).

**Content:** a friendly `EmptyState` — illustration/glyph, "No nutrition plan yet", one line ("Your coach
assigns a meal plan; it'll show up here."). **No primary CTA** that the trainee can't fulfill (they can't
self-assign). Keep it calm and informative.

---

### F. Coach — client nutrition (secondary, coach-lite)

**Purpose:** a coach monitors a client's nutrition adherence.

- **Adherence list:** the client's recent days, each with **date + adherence ring/% + completed/planned**, plus
  a **missed-vs-skipped** signal (e.g. a small "2 missed" flag) so the coach spots ghosting vs deliberate
  deviation. Tapping → the client's **day detail** (read-only, same row layout, full item statuses visible).
- Reachable from the existing client-monitor screen as a segment beside workout history.

---

## 5. Data dictionary (what each screen actually receives)

These are the real response shapes — design to these fields (camelCase on the wire).

**Day (`GET /api/me/nutrition/today`, `…/days/{date}`; coach `GET /api/nutrition/logs/{date}`):**
```
DailyNutritionLog {
  id, traineeId, localDate (YYYY-MM-DD),
  status: "open" | "closed",
  source: "fromAssignment" | "adhoc",
  hasPlan: bool,                 // false ⇒ No-plan empty state
  adherencePct: 0–100,           // the ring value
  plannedCount, completedCount,  // ring denominator / numerator
  meals: [ Meal ]
}
Meal { name, scheduledTime ("HH:mm:ss" | null), items: [ Item ] }
Item {
  id, planMealItemId (null ⇒ ad-hoc), isPlanned: bool,
  foodId, foodName, servingLabel, quantity,
  energyKcal, proteinG, carbsG, fatG, fiberG,   // any may be null
  status: "planned" | "completed" | "skipped" | "substituted" | "missed",
  loggedAtUtc (null until logged), note
}
```

**History / coach list (`GET …/days`, `GET /api/nutrition/logs`):** `items: [ DailyNutritionLogSummary {
id, traineeId, localDate, status, source, adherencePct, plannedCount, completedCount } ]` (paged).

**Food picker (`GET /api/foods?search=&kind=`):** `items: [ Food { id, name, brand, kind:
"food"|"supplement"|"beverage", servingLabel, servingSizeGrams, energyKcal, proteinG, carbsG, fatG, fiberG,
isCustom } ]` (paged).

**Write actions (drive the optimistic UI):**
- complete/skip → `POST /api/me/nutrition/items/status { date, itemId, status, note }`
- swap → `POST /api/me/nutrition/items/substitute { date, itemId, foodId, quantity, note }`
- add off-plan → `POST /api/me/nutrition/items { date, foodId, quantity, mealName, note }`

**Adherence rule (for the ring):** `adherencePct` = (Completed **+** Substituted planned items) ÷ planned items,
0–100; a day with **no planned items is 100%**. Ad-hoc items **don't** count toward the denominator.

---

## 6. Interaction principles (the feel)

- **Sub-10-second daily loop, one-handed.** The single tap to complete is sacred — everything else is secondary.
- **Optimistic & instant.** The check fills and the ring moves *immediately* on tap (the network catches up).
- **Calm, not gamified-loud.** A satisfying ring + gentle success accent; reserve alert color for **Missed**.
- **Legible at a glance** in a kitchen/gym: large rows, clear status, minimal chrome.

---

## 7. Deliverables for this pass

Hi-fi Flutter-styled mockups (extend `docs/design-reference/`) for: **Today** (states: loading, no-plan,
nothing-logged, partially-logged, day-closed), **Food picker** (idle, results, empty, confirm-quantity),
**Nutrition history** (list + read-only day detail), and the **coach client-nutrition** list + day detail. Plus
the five **item status** treatments and the **adherence ring** component. Match the existing tokens, widget kit,
and tab visual language — no new color/spacing systems.

---

### Source of truth (for deeper questions)
Product/UX rationale: `gymbro/docs/nutrition/CLIENT_UX.md` · domain states & adherence:
`…/DOMAIN_MODEL.md` · exact API/fields: `…/API_AND_PERMISSIONS.md` (as-built note) · existing app conventions:
this repo's `docs/ARCHITECTURE.md` + `docs/design-reference/`.
