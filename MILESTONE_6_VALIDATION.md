# Milestone 6: Navigation and Profile

## What This Milestone Adds

- A dedicated `UIManager` for Home, Shop, and Profile menu navigation.
- Clear back navigation from Shop and Profile to the default Home screen.
- Working Home shortcuts for Shop and Profile, while Play continues through the
  existing internet/sign-in gate and gameplay shell.
- A Profile screen showing the equipped skin preview and name, best score,
  lifetime defusals, earned Gems, owned skin count, unlocked power-up count,
  and a Settings entry.
- Signal-driven Profile and Home values that refresh after local mutations or a
  cloud snapshot replaces the active save.
- A reachable Shop destination with the current Gem balance and an intentional
  catalog placeholder.
- Android-safe vector life hearts drawn by Godot rather than a device-dependent
  font glyph.

## Scope Boundary

This milestone does not build dynamic Shop cards, acquisition dialogs,
real-money purchases, or Settings controls. Those remain Milestones 7 and 13.
The Shop placeholder makes the navigation complete without prematurely
implementing commerce UI.

## Automated Validation

- Godot 4.6.2 headless editor import completes without script errors.
- The configured main scene starts headlessly without runtime errors.
- Milestones 3, 4, and 5 regression smoke tests still pass.
- `Tests/Milestone6Smoke.tscn` covers:
  - Home, Shop, and Profile navigation plus Shop/Profile back-button behavior;
  - equipped default skin presentation;
  - best score, lifetime defusals, Gems, owned skins, and unlocked power-ups;
  - presence of the Settings entry and its milestone-safe informational state;
  - signal-driven Gem refresh on the reachable Shop placeholder.
  - three canvas-drawn life icons that do not depend on a heart font glyph.
- `git diff --check` passes.

## Edited Files

- `Scripts/Autoloads/ui_manager.gd` and `project.godot`: menu navigation owner
  and autoload registration.
- `Scenes/UI/Components/ProfileStatCard.tscn` and
  `Scripts/UI/profile_stat_card.gd`: reusable Profile statistic presentation.
- `Scenes/UI/ProfileScreen.tscn` and `Scripts/UI/profile_screen.gd`: responsive,
  signal-driven Profile data presentation and Settings entry.
- `Scenes/UI/ShopScreen.tscn` and `Scripts/UI/shop_screen.gd`: navigable Shop
  placeholder with live Gem balance.
- `Scenes/UI/HomeScreen.tscn` and `Scripts/UI/home_screen.gd`: live summary data,
  Profile shortcut, Shop shortcut, and shared navigation.
- `Scenes/Main.tscn`, `Scripts/main.gd`, and
  `Scripts/Autoloads/game_manager.gd`: menu scene lifecycle integration.
- `Scenes/UI/Components/LifeHeart.tscn`, `Scripts/UI/life_heart.gd`, and
  `Scenes/Gameplay/Gameplay.tscn`: Android-safe canvas-rendered life display.
- `Tests/Milestone6Smoke.tscn` and `Tests/milestone_6_smoke.gd`: regression
  coverage for navigation and Profile presentation.
