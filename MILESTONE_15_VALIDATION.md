# Milestone 15 Validation

## Result

Milestone 15, **Time Attack, Zen, and Hardcore**, is complete.

All three modes use the shared gameplay scene and mode-aware manager boundary
introduced in Milestone 14. Their specialized rules are authored through typed
mode stage data and enforced without duplicating gameplay scenes.

## Implemented Scope

- Added the exact five-step Time Attack curve:
  - 0 defusals: 2x2, 2 active bombs, 2.20 seconds;
  - 20 defusals: 3x3, 3 active bombs, 1.95 seconds;
  - 50 defusals: 3x3, 5 active bombs, 1.70 seconds;
  - 90 defusals: 4x4, 6 active bombs, 1.50 seconds;
  - 140 defusals: 4x4, 8 active bombs, 1.30 seconds.
- Added the exact 120-second active-gameplay Time Attack clock.
- Pausing and the complete resume countdown freeze the Time Attack clock.
- Reaching zero clears the board and finalizes exactly once with `time_up`.
- Time Attack wrong taps and expired bombs retain localized explosions but do
  not remove lives or end the attempt.
- Time Attack defusals immediately restore the configured active set and never
  grant lifetime/checkpoint credit.
- Added a live mode clock to the shared gameplay HUD; Time Attack hides Lives.
- Authored Zen stage data with a fixed 2.60-second base bomb timer at every
  Endless progression threshold.
- Authored Hardcore stage data with a fixed 1.50-second base bomb timer and one
  maximum life at every Endless progression threshold.
- Preserved Gem grid rewards in Time Attack, Zen, and Hardcore.
- Preserved power-ups in Zen and disabled their spawning, activation,
  automatic scoring, timer effects, and stored-inventory protection in Time
  Attack and Hardcore.
- Preserved lifetime/checkpoint credit in Zen and Hardcore.
- Preserved one rewarded revive in Zen and Hardcore. Hardcore restores its
  single life; both modes rebuild a fresh stage-appropriate wave, use the
  shared countdown, and receive normal revive grace.
- Rejected rewarded revive in Time Attack at both the offer and grant
  boundaries.
- Added a run-finalization reason contract and `run_finished` signal while
  preserving existing Game Over and best-score behavior.

## Automated Validation

Dedicated coverage:

```text
godot --headless --path . --scene res://Tests/Milestone15Smoke.tscn -- --defuse-test-save-path=res://.godot/test_saves/milestone15.dat
```

Validated deterministically:

- all authored Time Attack, Zen, and Hardcore stage values;
- Time Attack active-count backfill and every exact curve boundary;
- fixed Zen and Hardcore timers across progression;
- Time Attack wrong-tap and timeout behavior with no lives;
- Hardcore first unprotected wrong tap and timeout ending the attempt;
- Gem reward availability in all three modes;
- power-up reward rejection and pre-owned Shield non-consumption in disabled
  modes;
- Time Attack scoring and lifetime-credit exclusion;
- Zen and Hardcore lifetime credit;
- pause/countdown clock freezing and active-gameplay clock advancement;
- one-time `time_up` finalization, board cleanup, and saved result;
- Zen and Hardcore fresh-wave rewarded revive, countdown, and 75% grace start;
- Time Attack revive rejection.

Result:

```text
Milestone 15 smoke test passed.
```

Regression coverage:

```text
BackNavigationSmoke
Milestone3Smoke through Milestone14Smoke
```

All regression scenes pass without script errors, parse errors, or failed
assertions.

## Key Files

- `Resources/Content/GameModes/TimeAttack.tres`
- `Resources/Content/GameModes/Zen.tres`
- `Resources/Content/GameModes/Hardcore.tres`
- `Scripts/Autoloads/game_manager.gd`
- `Scripts/Gameplay/gameplay.gd`
- `Tests/Milestone15Smoke.tscn`
- `Tests/milestone_15_smoke.gd`
- `PROJECT_PLAN.md`
