# Milestone 11: Lifetime Score and Checkpoint Choice

## What This Milestone Adds

- Every successful bomb resolution permanently increments lifetime defusals.
- Each reached 1,000-lifetime-defusal checkpoint queues one permanent
  power-up choice until all six catalog power-ups are unlocked.
- Reached checkpoints and pending choices are saved atomically before their
  overlay is presented, preventing duplicate rewards after restart or sync.
- Game Over and restored Home sessions present a blocking, scrollable
  catalog-driven choice overlay with only locked eligible power-ups.
- Each selection atomically unlocks exactly one power-up, consumes exactly one
  pending choice, increments the save revision, and queues cloud sync.
- Multiple reached checkpoints can be claimed in sequence. Once the catalog is
  fully unlocked, later lifetime totals do not create unusable choices.

## Scope Boundary

Milestone 12 still owns the pre-play countdown, pause-resume countdown,
rewarded revive, and revive timer grace. Ads, Settings, and release integration
remain in Milestones 13 and 14. Payments remain postponed.

## Automated Validation

- `Tests/Milestone11Smoke.tscn` covers:
  - the exact 1,000-defusal interval and next-checkpoint presentation;
  - no reward below 1,000 and one reward at exactly 1,000;
  - idempotent checkpoint evaluation;
  - persisted pending state before overlay presentation;
  - one atomic, cloud-queued unlock per choice;
  - a returning-player backlog capped at the six catalog entries; and
  - no extra queue after every power-up is unlocked.
- Milestones 3 through 10 and Back Navigation remain regression coverage.
- The configured main scene starts headlessly without runtime errors.
- `git diff --check` passes.

## Edited Files

- `Resources/Content/AcquisitionOptions/Lifetime500.tres`: changes the shared
  checkpoint metadata to the user-approved 1,000 lifetime defusals. The legacy
  resource path remains stable for existing Godot references.
- `Scripts/Autoloads/game_manager.gd`: ensures every Game Over entry point
  evaluates and persists newly reached checkpoints before UI notification.
- `Scripts/main.gd` and `Scripts/UI/power_up_unlock_overlay.gd`: present saved
  pending choices only on Home or after Game Over, including restored saves.
- `Scenes/UI/PowerUpUnlockOverlay.tscn` and `Scripts/UI/shop_screen.gd`: update
  player-facing checkpoint copy to 1,000.
- `Tests/Milestone11Smoke.tscn` and `Tests/milestone_11_smoke.gd`: add dedicated
  Milestone 11 checkpoint, overlay, persistence, and catalog-cap coverage.
- Milestone 7/10 tests and milestone/plan documents: align prior catalog
  regression expectations and the active roadmap with the 1,000 threshold.
