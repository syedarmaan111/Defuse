# Milestone 8: Core Gameplay Foundation

## What This Milestone Adds

- Manager-owned run states for idle, running, paused, and game over.
- A reusable `BombCell` scene that renders active/inactive state and emits tap
  intent without owning score or progression rules.
- A playable active-bomb loop: tapping an active bomb adds one score, leaves
  every other active bomb unchanged, and activates one different replacement;
  inactive taps are ignored in this milestone.
- Responsive 2x2, 3x3, and 4x4 grids that preserve the exact active-bomb count
  defined for each stage.
- Live HUD updates for score, earned Gems, and three drawn life icons. Stage,
  grid-size, and active-count debug text is intentionally not displayed.
- All five approved stage configurations and thresholds: 0, 10, 25, 45, and
  70 successful defusals.
- Wave-safe stage changes: after a threshold, no replacements spawn until every
  already-active bomb is cleared; the new grid then receives a fresh layout.
- Pause-safe gameplay input, life-state transitions ready for explosion logic,
  game-over finalization, and permanent best-score updates.
- Signals for run start/state, score, lives, stage, and bomb-layout changes so
  later gameplay systems do not need to couple themselves to UI scenes.

## Scope Boundary

Milestone 8 does not start bomb countdown timers, penalize inactive taps, play
defusal/explosion animation or audio, or display stage-transition popups. Those
resolution and difficulty details remain Milestone 9. Timed rewards and
power-up effects remain Milestone 10.

Real-money payments also remain on the user-directed indefinite hold recorded
in `PROJECT_PLAN.md`. This milestone adds no billing or paid-content behavior.

## Automated Validation

- Godot 4.6.2 headless import completes without script or resource errors.
- The configured main scene starts headlessly without runtime errors.
- Back-navigation and Milestones 3 through 7 regression smoke tests pass.
- `Tests/Milestone8Smoke.tscn` covers:
  - fresh-run score, lives, Gems, stage, grid, and active-bomb presentation;
  - reusable bomb-cell intent reaching `GameManager`;
  - no per-bomb `READY` or `ACTIVE` text;
  - resolving one active bomb preserving every other active bomb;
  - threshold transitions draining the existing wave without replacements;
  - a fresh bomb layout appearing only after the final old-stage bomb clears;
  - inactive taps remaining non-penalizing until Milestone 9;
  - exact, unique, in-range active cells at every stage;
  - 2x2 to 3x3 to 4x4 responsive grid rebuilding;
  - exact stage thresholds and timer metadata;
  - pause blocking score changes;
  - signal-driven life-heart updates; and
  - three-life game over with best-score persistence.
- `git diff --check` passes.

## Edited Files

- `PROJECT_PLAN.md`: payment work moved to an explicit unscheduled hold and
  Milestone 8 marked complete.
- `Scripts/Autoloads/game_manager.gd`: authoritative run state, stage table,
  active layouts, scoring, lives, pause, game over, and gameplay signals.
- `Scenes/Gameplay/BombCell.tscn` and `Scripts/Gameplay/bomb_cell.gd`: reusable
  manager-driven bomb presentation and tap intent.
- `Scenes/Gameplay/Gameplay.tscn` and `Scripts/Gameplay/gameplay.gd`: responsive
  dynamic grid plus signal-driven HUD.
- `Tests/Milestone8Smoke.tscn` and `Tests/milestone_8_smoke.gd`: Milestone 8
  regression coverage.
