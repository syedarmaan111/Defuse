# Milestone 10: Timed Rewards and Power-Up Effects

## What This Milestone Adds

- One manager-owned reward at a time, first scheduled 12–20 gameplay seconds
  after run start and rescheduled after collection or expiry.
- A 5–7 second reward lifetime and 75% preference for inactive bomb cells.
- Gems-only selection until a power-up is unlocked; afterward, a 50/50 split
  between Gems and a random unlocked power-up.
- A reusable pulsing bomb-attached badge. Gem and power-up badges never
  intercept the bomb's full-cell touch target.
- Active reward taps claim and defuse. Inactive reward taps safely claim without
  score, explosion, life loss, sound, arming, or bomb-state changes.
- Immediate saved Gem and consumable inventory updates plus signal-driven badge
  cleanup on claim, expiry, timeout, chain resolution, grid change, and run end.
- All six automatic effects:
  - Shield blocks one life-losing explosion.
  - Slow Motion runs bomb timers at 55% speed for five gameplay seconds when
    two bombs become critical.
  - Scan highlights the most urgent bomb for three gameplay seconds.
  - Extra Life restores one newly opened life slot.
  - Combo Boost doubles score for eight gameplay seconds after a four-defusal
    rapid chain.
  - Chain Defuse resolves the most urgent additional active bomb.
- Power-up choices now occur every 1,500 lifetime defusals instead of 500.

## Scope Boundary

Milestone 11 still owns lifetime-defusal persistence, queued checkpoint choices,
the post-Game-Over selection overlay, and cloud-safe claiming. Until a power-up
is unlocked through seeded/development data or that future flow, live rewards
remain Gems only. Payments remain postponed indefinitely.

## Automated Validation

- Back navigation and Milestones 3 through 9 regression suites pass.
- `Tests/Milestone10Smoke.tscn` covers:
  - 12–20 second scheduling, Gems-only pre-unlock selection, and one visible
    reward maximum;
  - pulsing badge presentation and cleanup;
  - safe inactive Gem/power-up claims and active reward defusal;
  - persistent Gem and inventory increments plus unclaimed expiry;
  - Shield and Extra Life consumption;
  - Scan targeting and Slow Motion timer scaling;
  - Combo Boost scoring and Chain Defuse resolution; and
  - 1,500-defusal acquisition metadata.
- The configured main scene starts headlessly without runtime errors.
- `git diff --check` passes.

## Edited Files

- `Scripts/Autoloads/game_manager.gd`: reward scheduling/claiming and effect
  integration with bombs, timers, lives, score, and stage waves.
- `Scripts/Autoloads/power_up_manager.gd`: automatic activation conditions and
  timed effect state.
- `Scenes/UI/Components/RewardBadge.tscn` and `Scripts/UI/reward_badge.gd`:
  reusable pulsing reward presentation.
- `Scenes/Gameplay/BombCell.tscn`, `Scripts/Gameplay/bomb_cell.gd`, and
  `Scripts/Gameplay/gameplay.gd`: reward, scan, and protection feedback.
- Power-up Resources: effect durations/strengths and 1,500 checkpoint metadata.
- Shop scripts/tests and roadmap documents: 1,500-defusal presentation.
- `Tests/Milestone10Smoke.tscn` and `Tests/milestone_10_smoke.gd`: Milestone 10
  coverage.
