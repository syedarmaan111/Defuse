# Milestone 9: Bomb Resolution and Difficulty

## What This Milestone Adds

- Independent manager-owned countdowns for every active bomb using the exact
  timer configured for the current stage.
- A faster difficulty curve of 2.60, 2.25, 1.95, 1.70, and 1.50 seconds for
  Stages 1 through 5, replacing the original 3.8–2.8 second curve.
- Active-bomb defusal that awards one score, preserves every other active bomb
  and its timer, and starts one replacement bomb outside stage transitions.
- Timer-expiry explosions that cost exactly one life and replace only the
  expired bomb while neighboring active bombs remain unchanged.
- Inactive-bomb taps that cause one localized explosion and one-life loss
  without changing score or active neighbors.
- Per-cell resolution guards so repeated input during a defuse or explosion
  cannot resolve the same bomb twice.
- Immediate touch restoration when a cell is re-armed before its previous
  effect finishes, preventing intermittent missed defusals during rapid play.
- Supplied armed PNG sequence playback, a rising red danger fill, defuse motion,
  and localized explosion flash/shake effects.
- Supplied fuse, defuse, and explosion audio with independently stoppable fuse
  playback and pause/resume handling.
- Wave-safe difficulty transitions: threshold crossings stop replacement
  spawns, allow the old wave to drain, then create the new grid and a completely
  fresh active set.
- Silent stage changes with no stage/grid/active HUD text or popup.
- A larger 4x4 play area using reduced outer margins, tighter grid spacing,
  enlarged bomb artwork, and full-cell touch targets.

## Scope Boundary

Timed Gem/power-up rewards and automatic power-up effects remain Milestone 10.
The reusable 3–2–1 countdown and revive grace remain Milestone 12. Real-money
payments remain on the user-directed indefinite hold in `PROJECT_PLAN.md`.

## Automated Validation

- Godot 4.6.2 imports and starts the project headlessly without errors.
- Back-navigation and Milestones 3 through 8 regression smoke tests pass.
- `Tests/Milestone9Smoke.tscn` covers:
  - the faster stage timer metadata and live timer progress;
  - pause freezing gameplay time;
  - supplied animation-frame and red-fill presentation;
  - defusal score, effect, audio, and double-resolution protection;
  - rapid cell reactivation restoring its touch target immediately;
  - absence of stage text and stage popups;
  - two active bombs retaining independent timers;
  - timer expiry costing one life and preserving the neighboring active bomb;
  - localized timeout and inactive-tap explosion reasons/effects;
  - inactive-tap score/layout protection;
  - guarded repeated inactive taps costing only one life; and
  - enlarged 4x4 presentation and spacing, covered by the Milestone 8
    regression suite.
- `git diff --check` passes.

## Edited Files

- `Scripts/Autoloads/game_manager.gd`: timers, resolution rules, stage draining,
  armed state, and gameplay signals.
- `Scripts/Autoloads/audio_manager.gd`: overlapping one-shots and tracked fuse
  playback using the supplied WAV assets.
- `Shaders/bomb_alpha_cleanup.gdshader`: timer-driven red danger fill.
- `Scenes/Gameplay/BombCell.tscn` and `Scripts/Gameplay/bomb_cell.gd`: armed
  frames plus localized defuse/explosion presentation.
- `Scenes/Gameplay/Gameplay.tscn` and `Scripts/Gameplay/gameplay.gd`: rendering
  of timer and resolution signals.
- `Tests/Milestone9Smoke.tscn` and `Tests/milestone_9_smoke.gd`: Milestone 9
  regression coverage.
- `PROJECT_PLAN.md`: Milestone 9 completion and approved wave-safe transitions.
