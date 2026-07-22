# Milestone 5: Content Catalog and Progression Managers

## What This Milestone Adds

- A data-driven `ContentCatalog` with stable IDs, availability, presentation
  metadata, gameplay asset references, and reusable acquisition options.
- The owned/equipped `default_bomb` as the initial skin, backed by the supplied
  bomb image, animation directory, and original audio assets.
- Resource definitions for Shield, Slow Motion, Scan, Extra Life, Combo Boost,
  and Chain Defuse. Each is eligible for the future 1,500-lifetime-defusal choice.
- An intentionally empty purchase-offer list until real products are configured.
- `EconomyManager` as the sole gameplay-facing Gem credit/debit API. It does not
  expose any paid Gem top-up or currency exchange route.
- `SkinManager` for catalog-validated ownership and equip behavior. Equipping an
  unknown or unowned skin can no longer grant it implicitly.
- `PowerUpManager` for permanent unlocks, consumable quantities, safe
  consumption, and checkpoint-candidate queries.
- `ShopManager` for category queries, acquisition options, and stable content
  presentation state that later Shop cards can render without reading saves.
- Atomic `SaveManager` mutation methods. Every accepted manager action creates
  exactly one revision, persists locally, and joins the existing cloud-sync queue.
- Signal-driven currency, ownership, equip, and inventory updates, including
  when a cloud restore replaces the active progression snapshot.

## Scope Boundary

This foundation does not add the Shop or Profile screens, real purchases,
checkpoint presentation, or gameplay power-up effects. Those remain Milestones
6, 7, 10, 11, and 13. Power-up icons also remain unset until suitable standalone
supplied assets exist; full-screen UI mockups are never used as item artwork.

## Automated Validation

- Godot 4.6.2 headless editor import completes without script errors.
- The configured main scene starts headlessly without runtime errors.
- Milestone 3 and Milestone 4 regression smoke tests still pass.
- `Tests/Milestone5Smoke.tscn` covers:
  - catalog validity, the default skin, six approved power-ups, and empty offers;
  - checkpoint acquisition metadata and category queries;
  - earned/spent Gem balances, rejection of overspending, manager signals, and
    one save revision per accepted mutation;
  - unknown-skin rejection, permanent ownership, and owned-only equip behavior;
  - atomic power-up unlock/quantity grants, safe consumption, inventory signals,
    checkpoint-candidate filtering, and Shop presentation state;
  - cloud-sync queue preservation after manager mutations.
- `git diff --check` passes.

## Edited Files

- `Scripts/Data/acquisition_option.gd`: acquisition type/value resource.
- `Scripts/Data/skin_definition.gd`: extensible skin metadata/gameplay assets.
- `Scripts/Data/power_up_definition.gd`: approved power-up metadata/effect type.
- `Scripts/Data/shop_offer_definition.gd`: provider-neutral offer metadata.
- `Scripts/Data/content_catalog.gd`: typed catalog lookup and validation.
- `Resources/Content/`: initial default skin, six power-ups, shared checkpoint
  option, and the authoritative catalog resource.
- `Scripts/Autoloads/save_manager.gd`: atomic progression mutation APIs.
- `Scripts/Autoloads/economy_manager.gd`: earned Gem balance owner.
- `Scripts/Autoloads/skin_manager.gd`: skin ownership and equip validation.
- `Scripts/Autoloads/power_up_manager.gd`: unlock and quantity inventory owner.
- `Scripts/Autoloads/shop_manager.gd`: catalog/category/state query facade.
- `project.godot`: progression manager autoload registration.
- `Tests/Milestone5Smoke.tscn` and `Tests/milestone_5_smoke.gd`: regression
  coverage for the new content/progression layer.
