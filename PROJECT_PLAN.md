# PROJECT_PLAN.md

## Summary

DEFUSE is a Godot 4.6 portrait Android hypercasual game where the player taps active bombs before they explode. The roadmap must preserve the supplied specifications as authoritative: `GAME_SPEC.md`, `UI_SPEC.md`, and `README_FOR_CODEX.md`.

This plan does not implement gameplay. It defines the architecture, file layout, autoload responsibilities, asset strategy, and milestone order so future prompts can complete one small milestone at a time without rewriting completed systems.

## Existing Folder Structure Review

Current structure:

```text
/
  GAME_SPEC.md
  UI_SPEC.md
  README_FOR_CODEX.md
  project.godot
  Assets/
    Bomb/
      bomb_reference.png
      Animation/
      Audio/
    UI/
      Play screen.png
      Pause Screen.png
      Play Again Screen.png
      2x2 grid.png
      3x3 grid.png
      4x4 grid.png
      kenney_ui-pack-adventure/
    Coins/
    Effects/
    Fonts/
  Scenes/
  Scripts/
  Audio/
  Design/
```

Recommended minimal improvements:

- Keep `GAME_SPEC.md`, `UI_SPEC.md`, and `README_FOR_CODEX.md` at the repo root because the existing Codex instructions already reference them there.
- Keep all supplied assets in `Assets/`; do not recreate or replace them.
- Use `Scenes/` and `Scripts/` as the primary implementation folders.
- Leave the empty top-level `Audio/` folder unused unless future project-wide audio assets are added. The supplied sounds should remain referenced from `Assets/Bomb/Audio/`.
- Treat `Assets/Coins/` as legacy placeholder territory. The game must call the currency Gems everywhere, even if placeholder art is reused temporarily.

## Overall Project Architecture

Use a simple Godot scene-driven architecture:

- `Main.tscn` is the persistent root scene.
- Gameplay, menus, pause, and game-over UI are child scenes swapped or shown by managers.
- Bomb logic lives in small reusable scripts.
- Global state and persistent services live in autoloads.
- Visual screens follow the supplied mockups exactly.
- Gameplay systems communicate through signals instead of hard references where possible.

Target platform decisions:

- Portrait only.
- Android first.
- 60 FPS target.
- Godot 4.6 GL Compatibility renderer, matching `project.godot`.

## Scene Hierarchy

Planned scene tree:

```text
Scenes/
  Main.tscn
  Gameplay/
    GameplayScene.tscn
    BombGrid.tscn
    BombCell.tscn
    Bomb.tscn
  UI/
    HomeScreen.tscn
    HUD.tscn
    PauseOverlay.tscn
    GameOverScreen.tscn
    StagePopup.tscn
  Effects/
    ExplosionEffect.tscn
```

Runtime hierarchy under `Main.tscn`:

```text
Main
  Background
  ScreenRoot
    HomeScreen | GameplayScene | GameOverScreen
  OverlayRoot
    PauseOverlay
    StagePopup
```

Gameplay hierarchy:

```text
GameplayScene
  HUD
  BombGrid
    BombCell instances
      Bomb
  EffectsRoot
```

## Script Architecture

Planned script layout:

```text
Scripts/
  Autoloads/
    game_manager.gd
    save_manager.gd
    audio_manager.gd
    settings_manager.gd
  Gameplay/
    gameplay_scene.gd
    bomb_grid.gd
    bomb_cell.gd
    bomb.gd
    bomb_state.gd
    difficulty_config.gd
    difficulty_manager.gd
    gem_reward.gd
  UI/
    home_screen.gd
    hud.gd
    pause_overlay.gd
    game_over_screen.gd
    stage_popup.gd
  Data/
    save_data.gd
    skin_config.gd
    shop_item_config.gd
```

Script rules:

- Keep each script focused on one responsibility.
- Use descriptive variable and signal names.
- Comment important functions with what they do, why they exist, and when they are called.
- Never rewrite working systems during later milestones.
- Future prompts should modify only the files listed for the active milestone.

## Recommended Autoloads

Configure these in `project.godot` when the relevant milestone begins.

### `GameManager`

Responsibilities:

- Own current run state.
- Track score, lives, total successful defusals for the run, current stage, and game state.
- Start, pause, resume, restart, and end a run.
- Emit game-wide signals.

Public API:

```text
start_game()
pause_game()
resume_game()
restart_game()
return_to_home()
register_defusal(has_gem: bool)
register_explosion()
get_current_stage_config()
```

Signals:

```text
game_started
game_paused
game_resumed
game_over(final_score, best_score, gems_earned)
score_changed(score)
lives_changed(lives)
stage_changed(stage_index)
gems_changed(total_gems)
```

### `SaveManager`

Responsibilities:

- Load and save permanent data.
- Store best score, total Gems, selected skin, and settings.
- Provide safe defaults if no save exists.

Public API:

```text
load_save()
save_now()
get_best_score()
set_best_score(value)
get_total_gems()
add_gems(amount)
get_selected_skin()
set_selected_skin(skin_id)
get_setting(key, default_value)
set_setting(key, value)
```

### `AudioManager`

Responsibilities:

- Centralize all sound paths.
- Play supplied sounds only.
- Respect settings volume/mute values.

Sound mapping:

```text
bomb_armed: res://Assets/Bomb/Audio/Bomb.wav
bomb_defused: res://Assets/Bomb/Audio/bomb pop.wav
bomb_exploded: res://Assets/Bomb/Audio/explode.wav
```

### `SettingsManager`

Responsibilities:

- Hold runtime settings.
- Forward persisted setting changes to `SaveManager`.
- Provide values for audio mute/volume and future vibration options.

## Asset Usage Strategy

Use supplied assets exactly:

- UI mockups in `Assets/UI/` are the visual source of truth.
- Bomb idle art uses `Assets/Bomb/bomb_reference.png`.
- Armed bomb animation uses PNG frames in `Assets/Bomb/Animation/`.
- Explosion and bomb sounds use `Assets/Bomb/Audio/`.
- Kenney UI assets may be used only when recreating controls from the mockups.
- Do not recreate, redraw, replace, or restyle supplied assets.
- Rename labels and UI text from Coins to Gems everywhere.
- If a Gem icon is missing, use a temporary clearly named placeholder asset path and isolate it behind a UI component so it can be swapped later without logic changes.

## Animation Architecture

Bomb animation should be separated by state:

- Idle: static supplied bomb PNG.
- Armed: supplied PNG sequence plus red fill overlay showing remaining time.
- Explosion: localized explosion animation at the bomb position.

Implementation approach:

- `Bomb.tscn` owns visual state switching.
- `bomb.gd` owns timer and state transitions.
- `ExplosionEffect.tscn` owns explosion playback and frees itself after completion.
- Red fill should be a child visual overlay controlled by timer progress.
- No screen-wide explosion effects; neighboring bombs must remain visible.

## UI Architecture

UI must match supplied mockups exactly:

- `HomeScreen.tscn`: start button, best score, total Gems, selected skin entry point later.
- `HUD.tscn`: score, lives, Gems indicator if required by mockup, pause button.
- `PauseOverlay.tscn`: resume, restart, home/settings controls based on mockup.
- `GameOverScreen.tscn`: final score, best score, Gems, play again.
- `StagePopup.tscn`: short stage transition popup whenever stage changes.

UI rules:

- Do not redesign spacing, margins, padding, typography hierarchy, shadows, rounded corners, layout, or component positions.
- Replace every Coin reference with Gem.
- UI scripts only display state and emit user intent.
- Game decisions stay in `GameManager` and gameplay scripts.

## Bomb System Architecture

Bomb states:

```text
Idle
Armed
Explosion
```

Bomb responsibilities:

- Display current state.
- Track its own countdown only while armed.
- Report defusal or explosion upward.
- Ignore taps when idle or already exploding.
- Award score only through `GameManager.register_defusal()`.

Bomb grid responsibilities:

- Build the current grid size: 2x2, 3x3, or 4x4.
- Maintain the required number of active bombs.
- Choose inactive cells to arm.
- Keep active bomb count stable during gameplay.
- Rebuild grid only when stage grid size changes.

Wrong taps:

- No penalty.
- No score.
- No sound unless the UI spec later requires one.

## Difficulty Progression System

Difficulty is based only on successful defusals.

Create a static difficulty table:

```text
Stage 1: grid 2x2, active bombs 1, timer 3.8s, advance at 10 total defusals
Stage 2: grid 2x2, active bombs 2, timer 3.5s, advance at 25 total defusals
Stage 3: grid 3x3, active bombs 2, timer 3.2s, advance at 45 total defusals
Stage 4: grid 3x3, active bombs 3, timer 3.0s, advance at 70 total defusals
Stage 5: grid 4x4, active bombs 3, timer 2.8s, terminal difficulty
```

Rules:

- Timer remains constant during each stage.
- Stage changes only immediately after successful defusal thresholds.
- Show `StagePopup.tscn` on every stage change.
- Stage 5 has no further increases.

## Gem System

Rules:

- Currency name is always Gems.
- Random armed bombs may contain one Gem.
- Defusing a Gem bomb awards exactly one Gem.
- Exploding a Gem bomb awards nothing.
- Total Gems are permanently saved.
- Score and Gems are separate systems.

Recommended architecture:

- `gem_reward.gd` decides whether a newly armed bomb contains a Gem.
- `Bomb` displays Gem indicator if required by UI/visual design.
- `GameManager.register_defusal(has_gem)` increments run score and saved Gem total.
- `SaveManager.add_gems(1)` persists collected Gems.

Default assumption:

- Initial Gem chance should be defined as a constant in `gem_reward.gd`, starting at `0.15`, unless later design docs specify a different value.

## Save System

Save permanently:

```text
best_score
total_gems
selected_skin
settings
```

Recommended save path:

```text
user://save_data.json
```

Default save data:

```text
best_score: 0
total_gems: 0
selected_skin: "default_bomb"
settings:
  master_volume: 1.0
  sfx_volume: 1.0
  muted: false
```

Save timing:

- Load once during startup.
- Save immediately after best score changes.
- Save immediately after Gems change.
- Save immediately after selected skin or settings change.
- Save on game over as a final safety pass.

## Audio System

Use only supplied sounds:

- `Assets/Bomb/Audio/Bomb.wav`
- `Assets/Bomb/Audio/bomb pop.wav`
- `Assets/Bomb/Audio/explode.wav`

Audio events:

- Bomb armed: optional, only if it does not become noisy with multiple active bombs.
- Bomb defused: play `bomb pop.wav`.
- Bomb exploded: play `explode.wav`.
- Pause/resume UI sounds: defer unless supplied assets support them.

Implementation:

- `AudioManager` owns audio players or creates pooled one-shot players.
- Gameplay scripts request named sounds; they do not reference file paths directly.
- Respect mute and volume settings.

## Future Skin Architecture

Skins must not change gameplay.

Create `skin_config.gd` later as a Resource-like data model with:

```text
skin_id
display_name
idle_texture
armed_animation_frames
explosion_animation_frames
is_unlocked
price_gems
```

Default planned skins:

```text
default_bomb
alarm_clock
plasma_bomb
```

Rules:

- `Bomb` asks for current skin visuals through a skin provider, not hardcoded paths.
- Selected skin is saved.
- Locked/unlocked state should be shop-ready but can remain dormant until the shop milestone.

## Future Shop Architecture

Shop should be planned but not implemented in the core gameplay milestones.

Future files:

```text
Scenes/UI/ShopScreen.tscn
Scripts/UI/shop_screen.gd
Scripts/Data/shop_item_config.gd
```

Shop responsibilities:

- Display available skins.
- Show Gem prices.
- Allow purchase only if enough Gems exist.
- Save unlocked skins and selected skin.
- Never affect bomb gameplay rules.

Default assumption:

- Shop data should be resource/config driven so new skins do not require changes to shop UI logic.

## Recommended Git Workflow

Use one milestone per branch or commit:

```text
main
feature/m01-project-setup
feature/m02-autoload-foundation
feature/m03-ui-shell
```

Commit rules:

- One milestone per commit or PR.
- Do not mix refactors with feature work.
- Do not modify unrelated assets.
- Do not rewrite completed systems.
- Before coding any milestone, read `GAME_SPEC.md`, `PROJECT_PLAN.md`, and any relevant UI spec.
- After each milestone, run the smallest meaningful Godot validation available and record what was tested.

Suggested commit message format:

```text
M01: Configure project foundation
M02: Add autoload foundations
M03: Build home and navigation shell
```

## Milestones

### Milestone 1: Project Foundation

Goal:

- Configure the Godot project for portrait Android planning and establish empty architecture folders without gameplay.

Files created or modified:

```text
project.godot
Scenes/Main.tscn
Scripts/Autoloads/
Scripts/Gameplay/
Scripts/UI/
Scripts/Data/
Scenes/Gameplay/
Scenes/UI/
Scenes/Effects/
```

Acceptance criteria:

- Project has a main scene assigned.
- Folder structure exists.
- No gameplay logic is implemented.

### Milestone 2: Autoload Foundations

Goal:

- Add empty but callable manager scripts with signals and safe defaults.

Files created or modified:

```text
Scripts/Autoloads/game_manager.gd
Scripts/Autoloads/save_manager.gd
Scripts/Autoloads/audio_manager.gd
Scripts/Autoloads/settings_manager.gd
project.godot
```

Acceptance criteria:

- Autoloads are registered.
- Public APIs exist as stubs or minimal safe implementations.
- No bomb gameplay exists yet.

### Milestone 3: Save Data Foundation

Goal:

- Implement permanent save/load for best score, total Gems, selected skin, and settings.

Files created or modified:

```text
Scripts/Autoloads/save_manager.gd
Scripts/Data/save_data.gd
```

Acceptance criteria:

- Missing save file creates defaults.
- Save file persists and reloads.
- Corrupt save falls back safely without crashing.

### Milestone 4: Audio Foundation

Goal:

- Centralize supplied sound playback.

Files created or modified:

```text
Scripts/Autoloads/audio_manager.gd
```

Acceptance criteria:

- Named sound events map to supplied files.
- Volume and mute settings are respected.
- No script outside `AudioManager` needs raw audio paths.

### Milestone 5: UI Shell And Navigation

Goal:

- Create screen flow without gameplay: Home, Gameplay placeholder, Pause, Game Over placeholder.

Files created or modified:

```text
Scenes/Main.tscn
Scripts/Autoloads/game_manager.gd
Scenes/UI/HomeScreen.tscn
Scenes/UI/PauseOverlay.tscn
Scenes/UI/GameOverScreen.tscn
Scripts/UI/home_screen.gd
Scripts/UI/pause_overlay.gd
Scripts/UI/game_over_screen.gd
Scenes/Gameplay/GameplayScene.tscn
Scripts/Gameplay/gameplay_scene.gd
```

Acceptance criteria:

- User can move Home -> Gameplay placeholder -> Pause -> Resume/Home -> Game Over placeholder.
- UI uses Gem wording, never Coin wording.
- No bomb grid is implemented.

### Milestone 6: HUD And Run State

Goal:

- Display score, lives, best score, and Gems from manager state.

Files created or modified:

```text
Scenes/UI/HUD.tscn
Scripts/UI/hud.gd
Scripts/Autoloads/game_manager.gd
Scenes/Gameplay/GameplayScene.tscn
```

Acceptance criteria:

- New game starts at score 0 and 3 lives.
- HUD updates via signals.
- Game over triggers at 0 lives.

### Milestone 7: Static Bomb Visual

Goal:

- Add a reusable bomb scene with idle visual only.

Files created or modified:

```text
Scenes/Gameplay/Bomb.tscn
Scripts/Gameplay/bomb.gd
Scripts/Gameplay/bomb_state.gd
```

Acceptance criteria:

- Bomb displays `Assets/Bomb/bomb_reference.png`.
- Tap handling exists but does not yet score, explode, or animate.

### Milestone 8: Bomb Grid Layout

Goal:

- Build 2x2, 3x3, and 4x4 grid layouts matching supplied grid mockups.

Files created or modified:

```text
Scenes/Gameplay/BombGrid.tscn
Scenes/Gameplay/BombCell.tscn
Scripts/Gameplay/bomb_grid.gd
Scripts/Gameplay/bomb_cell.gd
Scenes/Gameplay/GameplayScene.tscn
```

Acceptance criteria:

- Grid can be rebuilt by size.
- Bomb positions remain stable.
- Layout follows mockup proportions.

### Milestone 9: Difficulty Manager

Goal:

- Add stage configuration and expose current grid size, active bomb count, and timer.

Files created or modified:

```text
Scripts/Gameplay/difficulty_config.gd
Scripts/Gameplay/difficulty_manager.gd
Scripts/Autoloads/game_manager.gd
```

Acceptance criteria:

- Successful defusal count maps to the five specified stages.
- Stage 5 is terminal.
- Stage changes emit a signal.

### Milestone 10: Armed Bomb Timers

Goal:

- Enable active bombs, countdown timers, and defusal scoring.

Files created or modified:

```text
Scripts/Gameplay/bomb.gd
Scripts/Gameplay/bomb_grid.gd
Scripts/Autoloads/game_manager.gd
Scripts/UI/hud.gd
```

Acceptance criteria:

- Required number of bombs are armed for the current stage.
- Defusing active bombs increases score by 1.
- Wrong taps have no penalty.
- Active bomb count is replenished.

### Milestone 11: Red Fill And Armed Animation

Goal:

- Add armed visual urgency using supplied PNG sequence and red timer fill.

Files created or modified:

```text
Scenes/Gameplay/Bomb.tscn
Scripts/Gameplay/bomb.gd
```

Acceptance criteria:

- Armed bomb uses supplied animation frames.
- Bomb does not flash.
- Red fill communicates remaining time.
- Timer duration comes from current stage.

### Milestone 12: Explosion And Lives

Goal:

- Add localized explosions, life loss, and game over.

Files created or modified:

```text
Scenes/Effects/ExplosionEffect.tscn
Scripts/Gameplay/bomb.gd
Scripts/Gameplay/bomb_grid.gd
Scripts/Autoloads/game_manager.gd
Scripts/Autoloads/audio_manager.gd
```

Acceptance criteria:

- Expired bomb plays localized explosion.
- Explosion sound plays.
- One life is lost per explosion.
- Neighboring bombs remain visible.
- Game over occurs after three lost lives.

### Milestone 13: Stage Popup

Goal:

- Show a short transition popup when stage changes.

Files created or modified:

```text
Scenes/UI/StagePopup.tscn
Scripts/UI/stage_popup.gd
Scripts/Autoloads/game_manager.gd
Scenes/Main.tscn
```

Acceptance criteria:

- Popup appears on stages 2, 3, 4, and 5.
- Popup does not block long-term gameplay.
- Popup is driven by `stage_changed`.

### Milestone 14: Gem Rewards

Goal:

- Add random Gem bombs and permanent Gem collection.

Files created or modified:

```text
Scripts/Gameplay/gem_reward.gd
Scripts/Gameplay/bomb.gd
Scripts/Gameplay/bomb_grid.gd
Scripts/Autoloads/game_manager.gd
Scripts/Autoloads/save_manager.gd
Scripts/UI/hud.gd
```

Acceptance criteria:

- Some armed bombs contain one Gem.
- Defusing a Gem bomb awards one permanent Gem.
- Exploding a Gem bomb awards nothing.
- UI says Gems only.

### Milestone 15: Best Score And Game Over Polish

Goal:

- Persist best score and display final run results accurately.

Files created or modified:

```text
Scripts/Autoloads/game_manager.gd
Scripts/Autoloads/save_manager.gd
Scripts/UI/game_over_screen.gd
Scenes/UI/GameOverScreen.tscn
```

Acceptance criteria:

- Best score updates only when final score exceeds saved best.
- Game Over screen displays final score, best score, and total Gems.
- Play Again starts a fresh run.

### Milestone 16: Skin Data Foundation

Goal:

- Add data structure for future skins without building the shop.

Files created or modified:

```text
Scripts/Data/skin_config.gd
Scripts/Gameplay/bomb.gd
Scripts/Autoloads/save_manager.gd
```

Acceptance criteria:

- Default skin is selected and saved.
- Bomb visuals are read through skin data.
- Gameplay behavior is unchanged.

### Milestone 17: Settings Foundation

Goal:

- Add settings persistence and connect audio mute/volume.

Files created or modified:

```text
Scripts/Autoloads/settings_manager.gd
Scripts/Autoloads/save_manager.gd
Scripts/Autoloads/audio_manager.gd
Scenes/UI/PauseOverlay.tscn
Scripts/UI/pause_overlay.gd
```

Acceptance criteria:

- Settings persist.
- Audio mute/volume affects sound playback.
- UI remains faithful to supplied mockups.

### Milestone 18: Shop Planning Stub

Goal:

- Prepare future shop architecture without implementing purchasing UI.

Files created or modified:

```text
Scripts/Data/shop_item_config.gd
Scripts/Data/skin_config.gd
```

Acceptance criteria:

- Shop item data can describe a skin price and unlock state.
- No gameplay or UI flow depends on shop yet.

### Milestone 19: Android Export Readiness

Goal:

- Prepare project settings for Android portrait export.

Files created or modified:

```text
project.godot
export_presets.cfg
```

Acceptance criteria:

- Portrait orientation is configured.
- Android export preset exists.
- No gameplay behavior changes.

### Milestone 20: Final Integration Pass

Goal:

- Verify the full loop against the specs without redesigning or rewriting systems.

Files created or modified:

```text
Only files with confirmed defects from prior milestones.
```

Acceptance criteria:

- Home -> Gameplay -> Pause -> Resume -> Game Over -> Play Again works.
- Difficulty progression follows exact thresholds.
- Save data persists best score and Gems.
- UI uses Gems only.
- Supplied assets and sounds are used.
- No completed system is rewritten unnecessarily.

## Testing And Validation Scenarios

Run these after relevant milestones:

- Fresh install save defaults.
- Best score persistence after game over.
- Total Gems persistence after collecting Gems.
- Wrong taps cause no penalty.
- Bomb explosion removes exactly one life.
- Three explosions trigger game over.
- Stage thresholds occur at 10, 25, 45, and 70 successful defusals.
- Stage 5 does not advance further.
- 2x2, 3x3, and 4x4 grids remain readable in portrait.
- Pause and resume do not corrupt active timers.
- Audio mute suppresses supplied sound playback.
- Selected skin persists and does not affect gameplay.

## Explicit Assumptions And Defaults

- Authoritative docs are currently at repo root, not under `/docs/`.
- `Scenes/`, `Scripts/`, and top-level `Audio/` are currently empty.
- Supplied UI mockups are exact visual targets.
- Coins must always be renamed to Gems in UI and code naming.
- Initial Gem chance defaults to `15%` until a design document specifies otherwise.
- The empty top-level `Audio/` folder should remain unused for now.
- The future shop is data-planned only and should not be implemented until requested.
- Each future prompt should complete exactly one milestone.
