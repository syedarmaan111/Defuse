# Milestone 13: Ads, Settings, and Audio

## What This Milestone Adds

- A responsive Settings screen reached from Profile, following the existing
  warm off-white panel, dark typography, rounded-control, and safe-margin
  language.
- Persisted `sound_enabled` and `sound_volume` preferences. Settings changes
  use the normal versioned save revision and cloud-sync queue.
- `AudioManager` now applies the saved enable/volume state to the supplied
  `Bomb.wav`, `bomb pop.wav`, and `explode.wav` assets. No replacement audio
  was introduced.
- Layout-owned banner reservations on Home, Gameplay, Pause, and Game Over.
  They remain inside container/safe-margin space and never cover controls.
- `AdManager`, a provider-neutral boundary for banner, interstitial, and
  rewarded formats:
  - development builds can simulate successful callbacks;
  - Android release builds never simulate an impression or reward;
  - a future native `DefuseAds` singleton must report readiness and callbacks;
  - no ad unit ID or provider credential is embedded in project code.
- Every completed run increments `completed_run_count`. Every fourth run sets
  `pending_interstitial` in the same atomic save mutation before Game Over
  controls appear.
- A due interstitial stays pending while offline. Reconnection attempts it
  once before another run; one normal no-fill/request failure clears the flag
  so the player cannot be trapped in an ad retry loop.
- Rewarded revive is available only online and only when a debug simulation or
  ready native provider exists. The revive is granted exclusively from the
  earned-reward callback.
- A debug-only `--defuse-test-save-path=` override keeps automated tests away
  from the normal playable local-save cache.

## Native Adapter Contract

Milestone 14 may install an Android singleton named `DefuseAds`. `AdManager`
expects provider methods for banner show/hide, interstitial readiness/show, and
rewarded readiness/show. It listens for:

```text
interstitial_shown
interstitial_closed
interstitial_failed(error_code)
rewarded_shown
rewarded_earned
rewarded_closed
rewarded_failed(error_code)
```

Ad unit identifiers, consent/provider configuration, and Play Console setup
remain Milestone 14 release work. Billing, product IDs, and purchase restoration
remain excluded under the payment hold.

## Automated Validation

`Tests/Milestone13Smoke.tscn` covers:

- Settings navigation and signal-driven control refresh.
- Saved sound enable and 0–100% volume values surviving snapshot restore.
- Disabled audio refusing playback and enabled audio using the supplied sound.
- Banner slots reserving container-owned layout space.
- Runs one through three not scheduling an interstitial.
- Run four atomically persisting one pending interstitial.
- Offline deferral producing no request or impression.
- Reconnection producing one request and one simulated impression.
- A release-style no-provider failure clearing the eighth-run opportunity.
- A new run starting normally after that one failure.

The complete isolated regression run passes with no logged Godot errors:

```text
BackNavigationSmoke
Milestone3Smoke
Milestone4Smoke
Milestone5Smoke
Milestone6Smoke
Milestone7Smoke
Milestone8Smoke
Milestone9Smoke
Milestone10Smoke
Milestone11Smoke
Milestone12Smoke
Milestone13Smoke
```

`git diff --check` also passes.

## How to Verify It Yourself

### Quick automated check

Create an isolated cache directory, then run:

```powershell
New-Item -ItemType Directory -Force .godot/test_saves | Out-Null
godot --headless --path . --scene res://Tests/Milestone13Smoke.tscn -- --defuse-test-save-path=res://.godot/test_saves/milestone13.dat
```

The Godot log must contain:

```text
Milestone 13 smoke test passed.
```

### In-editor check

1. Open Profile, press Settings, and confirm Back returns to Profile.
2. Disable Sound Effects. Start a run and confirm fuse, defuse, and explosion
   sounds are silent.
3. Re-enable Sound Effects, set volume to 40%, and use Test Defuse Sound.
4. Restart the project and confirm both settings remain selected.
5. Complete four runs in a debug build. Confirm the simulated interstitial
   resolves once and Play Again remains usable.
6. Disconnect during a live fourth run, finish it, and confirm no interstitial
   is requested while offline. Reconnect and confirm one attempt occurs.
7. Lose all lives while offline and confirm rewarded revive is unavailable.
8. On a physical Android release candidate, confirm no debug ad simulation is
   possible and missing/no-fill provider responses never block Play Again.

## Edited Files

- `Scripts/Autoloads/ad_manager.gd`: ad lifecycle, cadence, offline deferral,
  failure release, debug simulation, and native provider boundary.
- `Scripts/Autoloads/settings_manager.gd`: validated saved audio preferences.
- `Scripts/Autoloads/audio_manager.gd`: saved enable/volume application.
- `Scripts/Autoloads/save_manager.gd`: atomic run/ad mutations, settings API,
  and isolated debug-test cache override.
- `Scripts/Autoloads/game_manager.gd`: one completion record per run,
  interstitial startup gate, and earned-callback rewarded revive.
- `Scripts/Autoloads/ui_manager.gd`, `Scripts/main.gd`, and `Scenes/Main.tscn`:
  Settings navigation and screen composition.
- `Scenes/UI/SettingsScreen.tscn` and `Scripts/UI/settings_screen.gd`: responsive
  Settings controls.
- `Scenes/UI/ProfileScreen.tscn` and `Scripts/UI/profile_screen.gd`: live
  Settings entry.
- `Scenes/UI/Components/BannerAdSlot.tscn` and
  `Scripts/UI/banner_ad_slot.gd`: safe banner reservation lifecycle.
- `project.godot`: Settings/Ad manager registration and debug ad simulation.
- `Tests/Milestone13Smoke.tscn` and `Tests/milestone_13_smoke.gd`: milestone
  behavior coverage.
- `PROJECT_PLAN.md`: Milestone 13 completion status.
