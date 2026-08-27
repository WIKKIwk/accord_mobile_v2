# Generic Apparatus Name in Admin Work Plan

## Root cause

The Work Plan watermark previously rendered `ProductionMapChainStage.displayTitle`, which is the map node's display/history snapshot and can be a generic stage label. The canonical apparatus ID was available separately in `stage.apparatusId`. The current branch partially corrected this with a catalog lookup, but still contains a hardcoded lamination-ID switch that must not be the source of truth.

## Implementation

1. Make the watermark label resolver depend only on canonical apparatus ID and the loaded `AdminApparatus` catalog.
2. Remove the stage-title parameter and the hardcoded lamination mapping; use the canonical ID only when the catalog has no name.
3. Add a focused regression fixture whose map stage title is generic while the catalog name remains canonical, covering active and waiting cards.
4. Run the focused Work Plan widget tests and inspect the scoped diff.

## Scope

Only the Flutter Work Plan watermark resolver and its focused regression fixture are changed. Backend/API/schema/migration changes are not warranted by the investigation evidence.
