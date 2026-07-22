# Milestone 4: Versioned Local/Cloud Save Foundation

## What This Milestone Achieves

- Progression now uses a versioned, stable-ID save schema ready for later Shop,
  Profile, power-up, advertising, and settings milestones.
- The old `best_score`, `total_gems`, and `selected_skin` JSON format migrates to
  the new schema without losing Gems or an equipped legacy skin.
- Missing, malformed, negative, corrupt, tampered, and unsupported future save
  values are rejected or normalized before managers can use them.
- The local cache is encrypted through Godot's encrypted `FileAccess` API and
  wrapped in a SHA-256 integrity envelope. This is corruption/tamper resistance,
  not server-authoritative anti-cheat protection.
- Every local progression mutation increments `save_revision`, records
  `modified_at_unix`, persists immediately, and leaves a cloud-sync queue flag
  that survives restart.
- A successful cloud upload clears only the exact uploaded revision. If another
  local edit occurs during upload, that newer revision remains queued.
- Google Play Games Saved Games now loads and saves the single
  `defuse_progress` snapshot through the bundled plugin.
- Fresh installs prefer a valid cloud snapshot. Existing local/cloud saves are
  reconciled using revision plus modification time when ordering is clear.
- Ambiguous or contradictory branches stop launch and show a responsive
  `CHOOSE YOUR SAVE` dialog with Best Score, lifetime defusals, Gems, revision,
  and last-updated time for Cloud and This Device.
- Home and new-run entry remain blocked until required sign-in and cloud restore
  have completed or the player has explicitly resolved a conflict.

## Save Schema

The current schema is version 2 and includes:

- save revision and modified timestamp;
- best and lifetime scores;
- Gem currency balance;
- owned/equipped skins and purchased content IDs;
- unlocked power-ups, quantities, checkpoints, and pending choices;
- settings;
- completed-run/interstitial state;
- the device-local cloud sync queue flag.

`default_bomb` is always owned. An invalid equipped skin falls back safely to
`default_bomb`. Future save versions are not partially interpreted by an older
build.

## Automated Validation

- Godot 4.6.2 strict headless editor import completes without script errors.
- The configured main scene starts headlessly without runtime errors.
- The Milestone 3 online-gate regression smoke test still passes.
- `Tests/Milestone4Smoke.tscn` passes coverage for:
  - legacy field migration;
  - non-negative value validation and default skin invariants;
  - checksum round-trip and tamper rejection;
  - fresh-install cloud recovery;
  - clearly newer local and cloud selection;
  - ambiguous equal-revision conflict detection;
  - explicit Cloud conflict resolution;
  - sync completion preserving a newer queued revision.
- Android debug export completes and produces a signed APK.
- `git diff --check` passes.

## Android Configuration Still Required

Real Saved Games acceptance remains dependent on the external setup already
listed in `MILESTONE_3_VALIDATION.md`: a Gradle build template, real Play Games
project/game ID, matching package/signing credential, Saved Games enabled in
Play Console, and a tester account. The current debug export warns that the
game ID is empty, so no real account/cloud claim is made by desktop automation.

## Manual Android Acceptance Checklist

1. Enable mandatory sign-in after configuring Play Games and launch with a
   clean app-data directory. Confirm cloud restore finishes before Home appears.
2. Earn or seed progression, allow sync to complete, uninstall/reinstall, sign
   in with the same account, and confirm the cloud values return.
3. Change progression on two devices from the same base revision, then confirm
   `CHOOSE YOUR SAVE` blocks Home and displays both summaries.
4. Select Cloud and confirm its values become local after relaunch.
5. Recreate a conflict, select This Device, and confirm that version uploads and
   restores on the other device.
6. Disconnect during a local change, relaunch, reconnect, and confirm the queued
   revision uploads without blocking or discarding the local change.

## Edited Files

- `Scripts/Data/save_data.gd`: versioned schema, migration, and validation.
- `Scripts/Autoloads/save_manager.gd`: encrypted local persistence, integrity
  envelope, revisions, and persistent sync queue.
- `Scripts/Autoloads/cloud_save_manager.gd`: Saved Games restore/sync,
  reconciliation, and conflict selection.
- `Scripts/Autoloads/game_manager.gd`: restore readiness gate.
- `Scripts/main.gd` and `Scenes/Main.tscn`: startup and conflict UI integration.
- `Scripts/UI/sign_in_screen.gd`: restore/retry status presentation.
- `Scenes/UI/SaveConflictDialog.tscn` and
  `Scripts/UI/save_conflict_dialog.gd`: responsive conflict comparison UI.
- `project.godot`: SaveManager autoload ordering before cloud restore.
- `Tests/Milestone4Smoke.tscn` and `Tests/milestone_4_smoke.gd`: regression
  coverage for the save pipeline.
