# GymBro Design System — Component Inventory

> **Source of truth: the codebase.** This inventory is generated against
> `GymBroPortal/src/app/shared/ui/index.ts` (the shipped UI Kit) and reconciled
> against the `preview/` gallery cards in this design system. Keep it in sync
> whenever a `shared/ui/` component is added, renamed, or removed.
>
> Last reconciled: **June 2026** (post-cleanup).

---

## 1. Shipped UI Kit — `shared/ui/` (single source of truth)

16 components + 1 directive are exported from `shared/ui/index.ts`. "Preview card"
is the matching gallery file in this DS; **✗ = documentation gap** (shipped but
not represented in the gallery).

| Component (class) | Selector | Preview card | Status |
|---|---|---|---|
| ButtonComponent | `app-button` | `components-buttons.html` · `components-buttons-hero.html` | ✓ Documented |
| InputComponent | `app-input` | `components-input-states.html` | ✓ Documented |
| SelectComponent | `app-select` | `components-select.html` | ✓ Documented |
| FormFieldComponent | `app-form-field` | — | ✗ **Gap** — shown only implicitly inside input/select cards |
| PageHeaderComponent | `app-page-header` | `components-page-header.html` | ✓ Documented |
| PanelCardComponent | `app-ui-panel-card` | `components-panel-card.html` | ✓ Documented |
| DataTableComponent (+ `appDataTableCell`) | `app-data-table` | `components-data-table.html` | ✓ Documented |
| PageStickyFooterComponent | `app-ui-page-sticky-footer` | `components-sticky-footer.html` | ✓ Documented |
| ChipRemovableListComponent | `app-chip-removable-list` | `components-chips-tags.html` | ✓ Documented |
| ConfirmSplitDialogComponent | `app-confirm-split-dialog` | `components-confirm-dialog.html` | ✓ Documented |
| PageContainerComponent | `app-ui-page-container` | — | ✗ Gap (layout wrapper) |
| FilterBarComponent | `app-filter-bar` | — | ✗ **Gap** |
| FormGridComponent | `app-ui-form-grid` | — | ✗ Gap (layout wrapper) |
| FormInlineComponent | `app-ui-form-inline` | — | ✗ Gap (layout wrapper) |
| SuccessDialogComponent | `app-success-dialog` | — | ✗ **Gap** |
| InfoDialogComponent | `app-info-dialog` | — | ✗ **Gap** |
| `attach-centered-dialog` | (CDK util) | — | n/a — shared dialog plumbing, not a UI component |

**Coverage: 9 / 16 components have a dedicated gallery card.** Seven shipped
components are undocumented in the gallery (4 are layout wrappers shown implicitly;
**`app-filter-bar`, `app-success-dialog`, `app-info-dialog` are the real gaps**).

---

## 2. Screen / feature references (NOT shared UI Kit)

These gallery cards depict **feature or core-layout** components. They are valid
visual references, but they are not `shared/ui/` and should not be treated as
reusable kit primitives.

| Preview card | Backed by (codebase) | Layer |
|---|---|---|
| `components-sidebar.html` | `core/layout/app-shell` sidebar | Core layout |
| `components-breadcrumb.html` | `core/layout/app-shell` breadcrumb bar | Core layout |
| `components-login-card.html` | `features/auth/login` | Feature (off-system — see audit H-1) |
| `components-exercise-preview.html` | `features/exercises/exercise-preview-card` | Feature |
| `components-history-row.html` | `features/workspace/logs` session row | Feature |

---

## 3. Proposed components (documented but NOT shipped)

These gallery cards depict patterns that **do not yet exist as shared
components**. They are the README §9 "Target" extractions. Mark them clearly as
*proposed* so consumers don't import a component that isn't there.

| Preview card | Proposed component | Today's reality |
|---|---|---|
| `components-empty-state.html` | `app-empty-state` | Feature-local `app-trainer-plans-empty-state` + ad-hoc empties |
| `components-kpi-tiles.html` | `app-kpi-tile` | Hand-built in the workout-log weekly grid |

Additional proposed extractions with **no gallery card yet**: `app-side-panel`,
`app-modal-shell`, `app-tag-chip` (see the UX & Design System Review).

---

## 4. Reconciliation actions

1. **Add gallery cards** for `app-filter-bar`, `app-success-dialog`,
   `app-info-dialog` (real gaps; shipped + user-visible).
2. **Label** `components-empty-state` and `components-kpi-tiles` as
   **"Proposed — not shipped."**
3. Layout wrappers (`page-container`, `form-grid`, `form-inline`) may stay
   implicit — optionally add one combined "layout primitives" card.
4. Keep this file as the **single source of truth for kit ↔ gallery mapping**;
   the per-component API reference is the kit barrel itself,
   `GymBroPortal/src/app/shared/ui/index.ts`.
