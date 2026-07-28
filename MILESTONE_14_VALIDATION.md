# Milestone 14 Validation

## Result

Milestone 14, **Game Mode Foundation, Selection, and Persistence**, is complete.
The existing game is now the `endless` mode, and all six planned modes share one
typed catalog, one gameplay scene, one manager boundary, and one versioned save
record.

Specialized Time Attack, Zen, Hardcore, Precision, and Memory mechanics remain
in Milestones 15-17. This milestone supplies their selection, unlock, record,
navigation, HUD, result, and life-policy foundation without duplicating gameplay.

## Implemented Scope

- Added `GameStageDefinition`, `GameModeDefinition`, and `GameModeCatalog`
  Resources with stable IDs and authored definitions in this order:
  Endless, Zen, Memory, Time Attack, Precision, Hardcore.
- Preserved the five existing Endless stage values as typed stage Resources.
- Raised save data to version 3 and added six validated
  `best_scores_by_mode` records.
- Migrated version-2 `best_score` into the Endless record and retained
  `best_score` as a serialized Endless compatibility alias.
- Ignored unknown mode IDs and normalized missing, malformed, and negative
  records to zero.
- Added mode-record APIs to `SaveManager`:
  `get_mode_best_score`, `set_mode_best_score`, and `get_mode_best_scores`.
- Added the responsive Mode Select screen, data-driven mode cards, current
  records, lifetime unlock progress, and safe banner reservation.
- Enforced exact unlock thresholds from saved lifetime defusals:
  0 / 500 / 500 / 700 / 1000 / 1000.
- Rejected unknown and locked manager starts before ad interception or run-state
  mutation.
- Added mode-aware manager contracts, signals, snapshots, phase data, run clock
  data, dynamic maximum lives, power-up policy queries, and selected-mode state.
- Home Play opens Mode Select; selector Back returns Home; Play Again repeats
  the selected mode; Pause Quit and Game Over Quit return to Mode Select.
- Gameplay HUD and Game Over results show the active mode and its score unit.
  Life rendering supports three, one, or no lives from mode metadata.
- Profile now presents six independent mode records. Home continues to show the
  Endless best.
- Parameterless `start_game()` still starts Endless with the unchanged five
  stages, three lives, power-ups, scoring, and progression behavior.

## Automated Validation

Dedicated coverage:

```text
godot --headless --path . --scene res://Tests/Milestone14Smoke.tscn -- --defuse-test-save-path=res://.godot/test_saves/milestone14.dat
```

Validated:

- catalog order, stable IDs, typed definitions, and typed stage data;
- version-2 migration and version-3 validation/round-trip behavior;
- six independent records and the Endless compatibility alias;
- exact 499/500, 699/700, and 999/1000 unlock edges;
- locked direct manager calls and selector rendering;
- Home / Mode Select / gameplay / pause / Game Over navigation;
- selected mode snapshots, mode phase/clock fields, and dynamic 3/1/0 lives;
- mode-aware Play Again and per-mode result presentation;
- unchanged parameterless Endless startup and first-stage configuration.

Result:

```text
Milestone 14 smoke test passed.
```

Regression coverage:

```text
BackNavigationSmoke
Milestone3Smoke through Milestone13Smoke
```

All legacy smoke scenes pass without script errors, parse errors, or failed
assertions. The stale Milestone 6 Settings caption assertion was aligned with
the already-shipped Milestone 13 text, `Sound and audio preferences`.

## Key Files

- `Scripts/Data/game_stage_definition.gd`
- `Scripts/Data/game_mode_definition.gd`
- `Scripts/Data/game_mode_catalog.gd`
- `Resources/Content/GameModes/`
- `Scripts/Data/save_data.gd`
- `Scripts/Autoloads/save_manager.gd`
- `Scripts/Autoloads/game_manager.gd`
- `Scenes/UI/ModeSelectScreen.tscn`
- `Scenes/UI/Components/ModeCard.tscn`
- `Scripts/UI/mode_select_screen.gd`
- `Scripts/UI/mode_card.gd`
- `Scenes/Gameplay/Gameplay.tscn`
- `Scenes/UI/GameOverScreen.tscn`
- `Scenes/UI/ProfileScreen.tscn`
- `Tests/Milestone14Smoke.tscn`
- `Tests/milestone_14_smoke.gd`
