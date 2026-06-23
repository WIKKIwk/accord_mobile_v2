# Mobile Refactor Optimization Plan

## Goal

Reduce real copy-paste, move reusable UI/logic into shared components, and split oversized files without changing product behavior.

## Phase 1: Safe Reusable UI Pieces

- Extract repeated small widgets: `InfoRow`, `MetricTile`, `SummaryChip`, `StatusChip`, picker fields, notice cards.
- Extract repeated dialogs such as phone/text input confirmation dialogs.
- Continue replacing raw `InputDecoration(...)` blocks with shared decoration helpers.
- Keep each change small, run `flutter analyze`, and commit independently.

## Phase 2: Large Screen Decomposition

- Split `admin_production_map_orders_screen.dart` into smaller widgets, dialogs, and logic modules.
- Split `gscale_mobile_app.dart` into discovery, warehouse picker, printer, server list, and manual server modules.
- Split `admin_production_map_test_screen.dart` into canvas, node sheets, picker sheets, and formula fields.

## Phase 3: API Layer Decomposition

- Split `mobile_api_admin.dart` by domain: users, suppliers, warehouses, raw materials, production map, roles.
- Keep public API compatibility first, then gradually move call sites if needed.

## Phase 4: Runtime Performance

- Review timers, polling, and rebuild-heavy screens.
- Add pagination or virtualization where lists can grow large.
- Add `const` and smaller widgets where it measurably reduces rebuild scope.

## Rules

- Do not refactor by visual similarity only; extract only behaviorally identical or intentionally shared pieces.
- Do not mix risky business logic changes with UI cleanup commits.
- Every phase-1 refactor must pass `flutter analyze`.
