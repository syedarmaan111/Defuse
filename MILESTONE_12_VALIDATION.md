# Milestone 12: Countdown, Pause, and Rewarded Revive

## What This Milestone Adds

- One reusable manager-owned `3 → 2 → 1` countdown before a new run, after
  Pause resume, and after a rewarded revive.
- Countdown state freezes bomb timers, reward spawning/expiry, power-up time,
  scoring, and bomb input without pausing unrelated UI.
- Game Over now matches the supplied ad-enabled mockup with a responsive
  `WATCH AD TO REVIVE` action.
- One rewarded revive per run preserves score, successful defusals, and stage,
  restores one life, clears old rewards/effects, and builds a fresh
  stage-appropriate bomb wave.
- The first five gameplay seconds after revive smoothly move bomb timer speed
  from 75% to 100%, with an amber HUD status for clear feedback.
- Reward requests use a provider-neutral success/failure boundary. Desktop and
  Android debug builds simulate the completion through
  `defuse/development/simulate_rewarded_ads=true`; Android release builds never
  grant simulated rewards. A real provider remains Milestone 13 work.
- Revive is unavailable offline and disappears permanently after it is used
  once in the current run.

## Automated Validation

- `Tests/Milestone12Smoke.tscn` covers:
  - exact `3 → 2 → 1` ticks on new run and Pause resume;
  - frozen bombs, rewards, score input, and duplicate countdown prevention;
  - Game Over revive availability and simulated reward completion;
  - one-life restoration with score/stage preservation and a fresh wave;
  - a timer multiplier of 0.75 at grace start, 0.875 halfway, and 1.0 after
    five gameplay seconds;
  - no save revision caused by temporary grace state;
  - one revive maximum per run; and
  - no rewarded revive while offline.
- Back Navigation and Milestones 3 through 11 remain regression coverage.
- The configured main scene starts headlessly without script/runtime errors.
- `git diff --check` passes.

## How to Verify It Yourself

### Quick automated check

From PowerShell in the project folder:

```powershell
godot --headless --path . --scene res://Tests/Milestone12Smoke.tscn
```

The last line must be:

```text
Milestone 12 smoke test passed.
```

### In-editor gameplay check

1. Run the project and press Play.
2. Confirm `3`, `2`, and `1` appear once. Tapping bombs during this countdown
   must do nothing, and the red bomb timer must remain full.
3. Pause after a bomb timer has started. Wait several seconds and confirm its
   red timer does not move.
4. Press Resume. Confirm a fresh `3 → 2 → 1` appears before the same timer
   continues.
5. Lose all three lives. Confirm Game Over shows `WATCH AD TO REVIVE`.
6. In the debug build, press it. The development reward completes
   automatically: one life returns, a fresh bomb layout appears, and a
   `REVIVED` countdown runs.
7. After the countdown, confirm the amber `REVIVE GRACE` status starts at
   `TIMERS ×0.75`, rises smoothly, and disappears at normal `×1.00` after five
   seconds.
8. Lose the restored life. Confirm the revive button no longer appears.
9. Press Play Again and confirm a new run receives its own one-revive
   allowance.

### Whole-project confidence check

Run every smoke scene and require its success message. Also test on at least
one physical Android phone for touch targets, portrait safe areas, audio,
pause/resume, app background/foreground behavior, and smooth 60 FPS gameplay.
Reopen the app afterward and confirm Best Score, lifetime defusals, Gems,
skins, power-up unlocks, and pending checkpoint choices are preserved.

## Edited Files

- `Scripts/Autoloads/game_manager.gd`: countdown, revive request/grant boundary,
  fresh-wave restoration, one-revive guard, and grace multiplier.
- `Scenes/UI/PrePlayCountdownOverlay.tscn` and
  `Scripts/UI/pre_play_countdown_overlay.gd`: reusable responsive countdown.
- `Scenes/UI/GameOverScreen.tscn` and `Scripts/UI/game_over_screen.gd`: mockup-
  aligned revive action and availability rendering.
- `Scenes/UI/Components/RewardButton.tscn`: shared amber rewarded-action style.
- `Scenes/Gameplay/Gameplay.tscn` and `Scripts/Gameplay/gameplay.gd`: revive
  grace feedback.
- `Scenes/Main.tscn`: countdown overlay composition.
- `project.godot`: explicit debug rewarded-ad simulation setting.
- `Tests/Milestone12Smoke.tscn` and `Tests/milestone_12_smoke.gd`: Milestone 12
  behavior coverage.
- Back Navigation and Milestone 8–10 smoke tests: advance the new countdown
  before exercising their original gameplay assertions.
- `PROJECT_PLAN.md`: Milestone 12 completion status and remaining scope.
