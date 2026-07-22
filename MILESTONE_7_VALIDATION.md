# Milestone 7: Data-Driven Shop and Commerce Shell

## What This Milestone Adds

- A responsive Shop with Skins, Power-ups, and Purchases categories populated
  entirely from `ContentCatalog.tres`.
- Reusable catalog cards that present locked, Gem-purchasable,
  checkpoint-eligible, owned, selected, equipped, and quantity states.
- A reusable detail dialog that displays catalog art, description, ownership,
  and every acquisition option authored on the selected Resource.
- Confirmation and feedback dialogs for Gem purchases, insufficient Gems,
  provider failures, cancellations, and successful ownership/equip changes.
- Atomic earned-Gem skin purchases: the Gem debit and ownership grant share one
  persisted save revision.
- A provider-neutral `CommerceManager` contract for purchases and restoration.
  With no billing provider installed, it fails safely and grants no content.
- An intentional empty Purchases state that explicitly preserves the rule that
  Gems are earned during gameplay and are never sold.

## Current Catalog Presentation

- Skins renders the owned and equipped Default Bomb because it is the only
  supplied skin Resource.
- Power-ups renders all six defined items as locked 500-lifetime-defusal
  checkpoint choices. Claiming them remains Milestone 11.
- Purchases renders a safe empty state because no paid offers are authored.
- Adding a normal future catalog Resource automatically adds a card and detail
  view; no item-specific Shop node or script branch is required.

## Scope Boundary

This milestone does not add new skin art, grant checkpoint power-ups, connect
Google Play Billing, display provider-localized prices, or restore live Android
purchases. The provider adapter, product configuration, and release validation
remain Milestone 13.

## Automated Validation

- Godot 4.6.2 headless import and main-scene startup complete without errors.
- Milestones 3 through 6 regression smoke tests pass.
- `Tests/Milestone7Smoke.tscn` covers:
  - catalog-driven Skin and Power-up card counts and presentation states;
  - the intentional Purchases empty state and no-Gem-sale copy;
  - automatic UI rendering for a runtime-added catalog skin;
  - one-revision Gem debit plus ownership grant;
  - owned-skin equip/selected state and details presentation;
  - insufficient-Gem protection without balance or inventory mutation; and
  - safe provider-unavailable behavior without granting content.
- `git diff --check` passes.

## Edited Files

- `Scripts/Autoloads/commerce_manager.gd` and `project.godot`: provider-neutral
  billing boundary and autoload registration.
- `Scripts/Autoloads/shop_manager.gd`: acquisition validation, catalog state,
  Gem purchase orchestration, paid entitlement handling, and restore mapping.
- `Scripts/Autoloads/save_manager.gd`: atomic Gem-for-skin persistence helper.
- `Scenes/UI/ShopScreen.tscn` and `Scripts/UI/shop_screen.gd`: responsive dynamic
  Shop categories, cards, empty states, and manager-driven feedback.
- `Scenes/UI/Components/ShopCard.tscn` and `Scripts/UI/shop_card.gd`: reusable
  catalog item card and state presentation.
- `Scenes/UI/ShopDetailDialog.tscn` and
  `Scripts/UI/shop_detail_dialog.gd`: data-driven item details and actions.
- `Scenes/UI/ShopConfirmationDialog.tscn`,
  `Scripts/UI/shop_confirmation_dialog.gd`,
  `Scenes/UI/ShopFeedbackDialog.tscn`, and
  `Scripts/UI/shop_feedback_dialog.gd`: reusable acquisition modal flows.
- `Tests/Milestone7Smoke.tscn` and `Tests/milestone_7_smoke.gd`: Milestone 7
  regression coverage.
