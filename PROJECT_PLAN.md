# DEFUSE Project Plan

## Purpose and Authority

DEFUSE is a portrait Android game built in Godot 4.6. The player defuses armed bombs before they explode, earns Gems and power-ups, unlocks cosmetic skins, and progresses through increasingly difficult stages.

> **Payment hold (user-directed):** Real-money payments for skins, power-ups,
> offers, and any other content are postponed indefinitely. Do not add billing
> UI, paid catalog entries, provider integration, product IDs, purchase restore,
> or paid-entitlement behavior until the user explicitly asks to resume this
> work. Existing provider-neutral shell code may remain dormant for forward
> compatibility, but it is not an active feature or milestone dependency.

This document is the implementation roadmap. Its rules supersede older conflicting statements in `GAME_SPEC.md`, `UI_SPEC.md`, `README_FOR_CODEX.md`, and earlier revisions of this plan. The user-approved UI references in `Assets/UI/UI mockups/` define the visual language and quality bar; they are not flattened UI assets to place on screens.

## Current Repository Status

- Milestones 1 through 13 are complete.
- `Main.tscn` coordinates responsive Home, Shop, Profile, Gameplay, network,
  sign-in, Pause, and Game Over scenes built from real Godot `Control` nodes.
- Manager-owned, signal-driven foundations cover launch gating, cloud/local
  saves, progression, catalog content, inventory, navigation, and run state.
- Core gameplay now includes reusable bomb cells, responsive 2x2 through 4x4
  grids, independent timers, supplied armed animation/audio, defusal, localized
  explosions, score, lives, exact active-bomb counts, all five stages, pause
  gating, guarded resolution, wave-safe stage changes, game-over finalization,
  best-score persistence, and an enlarged finger-friendly 4x4 layout.
- Android release configuration and final device validation remain in Milestone 14.
- Live billing and real-money content remain deliberately unimplemented under
  the payment hold above.

## Non-Negotiable UI Architecture

- Recreate each screen using real Godot `Control` nodes. Never use a mockup as a screen background, layout image, or source of invisible hitboxes.
- Match the reference aesthetic rather than copying coordinates exactly: premium semi-flat design, warm off-white panels, dark display typography, restrained color accents, soft shadows, rounded controls, and clear hierarchy.
- Theme consistency, visual beauty, readability, safe areas, accessibility, and responsive behavior take priority over pixel-for-pixel mimicry.
- Support small/large Android phones, tablets, different aspect ratios/resolutions, display cutouts, and safe areas through containers, anchors, size flags, responsive spacing, and dynamic layouts.
- UI scripts render state and emit user intent only. Managers own gameplay, purchases, persistence, and inventory mutation.
- New screens may be designed from the established reference language without a new mockup.

### Shared UI Scenes

```text
Scenes/UI/
  Components/
	PrimaryButton.tscn
	SecondaryButton.tscn
	PopupPanel.tscn
	DialogWindow.tscn
	CurrencyDisplay.tscn
	TabButton.tscn
	SectionHeader.tscn
	BottomNavigation.tscn
	NavigationTab.tscn
	ShopCard.tscn
	SkinCard.tscn
	PowerUpCard.tscn
	ConfirmationPopup.tscn
	NotificationPopup.tscn
	ProfileStatCard.tscn
	RewardBadge.tscn
  Screens/
	HomeScreen.tscn
	HUD.tscn
	PauseOverlay.tscn
	GameOverScreen.tscn
	ShopScreen.tscn
	ProfileScreen.tscn
	NetworkRequiredScreen.tscn
	SignInScreen.tscn
  Overlays/
	PrePlayCountdownOverlay.tscn
	PowerUpUnlockOverlay.tscn
	SaveConflictDialog.tscn
	ConnectionStatusOverlay.tscn
	ReviveOverlay.tscn
  UIManagerRoot.tscn
```

`UIManagerRoot` has a safe-area-aware `ScreenRoot`, `OverlayRoot`, and `NotificationRoot`. Every popup, card, confirmation flow, and state animation uses the shared components.

### Shared UI Animation Rules

- Buttons have a subtle press scale/tint response and disabled state.
- Popups and dialogs use consistent fade/scale/backdrop transitions.
- Tabs, card selection, owned/equipped states, notifications, and currency changes animate without shifting layout.
- All Gem and power-up icons attached to bombs use one reusable pulse: slightly larger, then smaller, looping until claimed, expired, exploded, or freed.

## Online, Sign-In, and Cloud Save Requirements

Implementation note: the Android online launch gate is enabled through
`defuse/online_gate/enabled=true`. Desktop/headless development uses the explicit
non-Android bypass; Android exports ignore that bypass and fail closed.

### Internet Connection Gate

- An Android network reporting validated internet access is required before the game restores progression or starts a new run. Both Wi-Fi and cellular data are supported.
- Use an Android `ConnectivityManager` bridge to inspect the active network. If the bridge itself is unavailable, fail closed so an integration problem cannot bypass the online-only launch requirement.
- If internet disconnects during a live run, allow that run to finish. Block restarting, new runs, commerce, restore purchases, and other online-only actions until internet returns.
- `NetworkRequiredScreen` provides Retry; `ConnectionStatusOverlay` tells the player that the live run can finish; a notification confirms reconnection.

### Google Play Games Saved Games

- Google Play Games sign-in is required; guest progression is not supported.
- Restore the cloud save before Home appears. Local save is an encrypted/validated cache and offline sync queue, not the reinstall-recovery authority.
- Sync every persisted progression change: Gems, scores, owned/equipped content, power-up inventory, checkpoint choices, settings, and ad counters.
- Pending local changes from a run completed after a disconnect queue and upload before the next run begins.
- Use save revision and modified timestamp to detect divergent saves. Restore the clearly newer one; show `SaveConflictDialog` when two divergent versions cannot be safely ordered. The player explicitly chooses Cloud or This Device; never silently overwrite a conflict.
- Google Play Games integration requires Play Console configuration, Android credentials, a Godot Android bridge/plugin, and Saved Games enablement. It does not require a custom backend.
- Cloud saves protect against uninstall/reinstall and device changes, but without a custom server they do not make gameplay values cheat-proof.

### Manager Interfaces

```text
NetworkManager
  is_wifi_connected() -> bool
  has_internet_access() -> bool
  can_start_game() -> bool
  refresh_connection_state()

CloudSaveManager
  sign_in()
  restore_progress()
  queue_sync()
  sync_now()
  resolve_conflict(source)
```

Required signals:

```text
wifi_connection_changed(is_connected)
internet_availability_changed(is_available)
gameplay_connection_lost()
gameplay_connection_restored()
cloud_sign_in_succeeded()
cloud_sign_in_failed(error_code)
cloud_restore_completed()
cloud_sync_completed()
cloud_sync_failed(error_code)
cloud_conflict_detected(local_summary, cloud_summary)
```

## Data-Driven Content and Economy

### Content Resources

```text
Scripts/Data/
  save_data.gd
  skin_definition.gd
  power_up_definition.gd
  shop_offer_definition.gd
  acquisition_option.gd
  content_catalog.gd

Resources/Content/
  ContentCatalog.tres
  Skins/default_bomb.tres
  PowerUps/
  Offers/
```

`SkinDefinition` and `PowerUpDefinition` include stable ID, display name, description, icon, gameplay assets, availability, and `acquisition_options`. A standard future addition requires only assets plus a Resource/catalog entry; never item-specific screen code or layout nodes.

`AcquisitionOption` supports:

```text
DEFAULT_GRANT
GEM_PURCHASE
LIFETIME_SCORE_CHECKPOINT
REAL_MONEY_PURCHASE
```

`REAL_MONEY_PURCHASE` is reserved schema metadata only while the payment hold
is active. The game must not author or expose paid acquisition options until
the user explicitly resumes payment work.

### Economy Rules

- Gems are earn-only gameplay currency. The game never sells, tops up, exchanges, or provides a Gem-purchase screen.
- Remove the `+` Gem purchase affordance from all implemented screens.
- Skins may be default grants or earned with Gems while payments are deferred.
- Power-ups are temporarily unlocked through a 20-lifetime-defusal checkpoint
  flow for testing while payments are deferred. Restore the release threshold
  before shipping. They never use Gem purchase.
- `default_bomb` is the sole initial skin and is granted, owned, equipped, and selected on first launch.
- No real-money entitlement is offered or processed during the payment hold.

### Managers

Register these autoloads when their milestone begins:

```text
UIManager
NetworkManager
CloudSaveManager
EconomyManager
ShopManager
SkinManager
PowerUpManager
CommerceManager
SettingsManager
GameManager
SaveManager
AudioManager
AdManager
```

- `UIManager`: screen, overlay, modal, navigation, and notification lifecycle.
- `EconomyManager`: Gem balances, affordability, and Gem debits only.
- `ShopManager`: catalog queries, category filtering, and acquisition orchestration.
- `SkinManager`: ownership, equip validation, and current skin gameplay assets.
- `PowerUpManager`: ownership, quantities, checkpoint eligibility, automatic effect activation.
- `CommerceManager`: dormant provider-neutral compatibility boundary; it must
  remain unavailable and must not be expanded while payments are deferred.
- `SaveManager`: schema validation, migration, local cache persistence, and cloud-sync requests.
- `GameManager`: run state, gameplay clocks, score, lives, stages, countdown, and revive grace.
- `AdManager`: banner/interstitial/rewarded-ad behavior only.

Key event contracts:

```text
currency_changed(currency_id, new_balance)
skin_owned(skin_id)
skin_equipped(skin_id)
power_up_quantity_changed(power_up_id, quantity)
inventory_updated()
purchase_succeeded(product_id)
purchase_cancelled(product_id)
purchase_failed(product_id, error_code)
purchases_restored(product_ids)
```

## Save Data

Use a versioned, stable-ID progression record:

```text
save_version
save_revision
modified_at_unix
best_score
lifetime_defusal_score
currencies["gems"]
owned_skin_ids
equipped_skin_id
purchased_content_ids
unlocked_powerup_ids
owned_power_up_quantities
claimed_powerup_checkpoints
pending_powerup_unlock_choices
settings
completed_run_count
pending_interstitial
```

Migrate legacy `total_gems` to `currencies["gems"]` and `selected_skin` to `equipped_skin_id`. Missing/invalid equipped skin defaults to `default_bomb`; initial ownership always contains `default_bomb`.

## Shop, Profile, and Checkpoint Choice

### Shop

- Provide Skins and Power-ups sections from dynamic catalog data. The existing
  Purchases section remains an intentional unavailable/empty state during the
  payment hold and may be removed in later UI polish if the user requests it.
- The Skins section initially renders only the owned/equipped/selected default bomb.
- Power-ups render their locked checkpoint-eligible catalog entries. Purchases
  renders a safe intentional unavailable/empty state during the payment hold.
- Cards render locked, Gem-purchasable, checkpoint-eligible, owned, selected,
  and equipped states from managers/signals. Paid controls stay hidden.
- Confirmation, insufficient-Gem, purchase failure, and success feedback use reusable dialogs/notifications.

### Profile

Profile displays selected skin preview, best score, lifetime defusals, earned Gems, owned skin count, unlocked power-up count, and settings entry. It does not add social features, avatars, cloud-account management, achievements, or leaderboards.

### Temporary 20-Defusal Power-Up Choice

- Every eligible 20 lifetime successful defusals queues one choice until all defined power-ups are owned.
- Persist the queue before presentation.
- After Game Over, `PowerUpUnlockOverlay` reuses the shop Power-up catalog/card layout, filtering to locked checkpoint-eligible entries and replacing acquisition controls with `CHOOSE`.
- Claim exactly one item per pending choice. Real-money buttons are hidden in checkpoint-choice mode.
- Any future paid unlock behavior and its checkpoint interaction remain
  undecided until payment work is explicitly resumed.

## Gameplay Rules

### Stages

```text
Stage 1: 2x2 grid, 1 active bomb, 2.60s, advance at 10 defusals
Stage 2: 2x2 grid, 2 active bombs, 2.25s, advance at 25 defusals
Stage 3: 3x3 grid, 2 active bombs, 1.95s, advance at 45 defusals
Stage 4: 3x3 grid, 3 active bombs, 1.70s, advance at 70 defusals
Stage 5: 4x4 grid, 3 active bombs, 1.50s, terminal stage
```

When a score threshold is reached, queue the next stage and stop spawning
replacement bombs. Existing active bombs keep their individual timers. After
the last bomb in that wave resolves, replace the grid and arm a completely
fresh stage-appropriate set. Stage changes happen silently; no stage, grid, or
active-count text is displayed in the HUD or in a popup.

### Bomb Interaction

| Bomb state | Reward attached | Tap result |
|---|---:|---|
| Active | No | Defuse and award score. |
| Active | Yes | Defuse, award score, and claim reward. |
| Inactive | No | Localized explosion; lose exactly one life. |
| Inactive | Yes | Claim reward only; no score, explosion, life loss, arming, sound, or state change. |

Bombs guard against double resolution. Bomb explosion is local; neighboring bombs remain visible. Bomb assets and supplied audio remain the base gameplay assets.

### Timed Rewards

- At most one reward is visible across the grid.
- Spawn after a random 12–20 second cooldown, including at run start; prefer an inactive bomb 75% of the time.
- Every reward expires unclaimed after exactly 6 seconds.
- A Gem grants one permanently saved Gem. Until any power-up is unlocked, all rewards are Gems; afterward, reward selection is 50% Gem and 50% a random unlocked power-up.
- Power-ups are single-use and activate as soon as their reward icon is tapped.
  Reactive effects such as Shield arm immediately and wait only for the event
  they affect.
- Implement Shield, Slow Motion, Scan, Extra Life, Combo Boost, and Super Defuse from Resource definitions.
- Shield blocks the next timeout or inactive-tap life loss. Extra Life restores
  one life immediately after a life is lost when a slot is available.
- Scan starts on pickup and highlights the most urgent armed bomb.
- Slow Motion starts on pickup and immediately slows active bomb timers.
- Combo Boost starts on pickup and doubles scoring for its configured duration.
- Super Defuse starts its configured window on pickup; each manual defusal in
  that window automatically resolves every bomb currently armed, and unarmed
  bomb taps do not cost lives while the effect is active.

### Pre-Play Countdown and Revive Grace

- New runs start immediately. Show the reusable `3 → 2 → 1` countdown only after Pause resume and a rewarded revive.
- During countdown, bomb timers, reward spawns, score progression, and gameplay input are paused. Only one countdown can exist at once.
- A rewarded revive restores one life, rebuilds fresh stage-appropriate bombs, shows the countdown, and then starts one temporary grace effect.
- For five gameplay seconds after the revive countdown, active bomb timer speed smoothly changes from 75% to 100%. All bombs armed in that window use the live rate multiplier.
- The grace effect does not alter saved stage data, future runs, score, Gems, or later normal bomb timing.

## Advertising and Revenue Protection

- Reserve a safe-area banner slot that never covers gameplay or controls.
- Attempt an interstitial after every fourth completed run.
- Atomically persist `completed_run_count` and `pending_interstitial` before Game Over controls appear.
- If an interstitial is due while offline, retain one pending opportunity. On internet reconnection, attempt it before the next run.
- After one normal no-fill/failure, clear the pending flag and allow play; never create an infinite retry block.
- Rewarded revive is unavailable offline and proceeds directly to normal Game Over.
- Never count an offline/failed request as an impression or reward.
- A real ad SDK and ad unit IDs are integrated only in Android release
  readiness. Google Play Billing and product IDs are excluded while the payment
  hold is active.

## Final Milestones

1. **Plan Consolidation and Baseline Verification** — Verify current navigation and record existing code as partial/unverified.
2. **Responsive UI Foundation Refactor** — Replace mockup-image/fixed-coordinate UI with reusable safe-area-aware Control layouts and shared animation/theme components.
3. **Internet Gate and Google Play Games Sign-In** — Add native connectivity bridge, connection UI, mandatory sign-in, and launch gating.
4. **Versioned Local/Cloud Save Foundation** — Add migration, cloud restore/sync, conflict dialog, sync queue, and uninstall/reinstall recovery validation.
5. **Content Catalog and Progression Managers** — Add Resource definitions, catalog, save ownership model, and managers.
6. **Navigation and Profile** — Add Home/Shop/Profile navigation and basic Profile data presentation.
7. **Data-Driven Shop and Commerce Shell** — Complete. Dynamic shop cards,
   skin details, earned acquisition options, confirmations, and a dormant
   provider-neutral compatibility boundary are in place. No live payments.
8. **Core Gameplay Foundation** — Complete. Reusable bombs, responsive grids,
   HUD, score, lives, all five stages, pause-safe input, best-score persistence,
   and manager-owned state signals are in place.
9. **Bomb Resolution and Difficulty** — Complete. Independent timers, defusal,
   guarded wrong-tap and timeout explosions, life loss, wave-safe stage
   transitions, supplied armed frames/audio, red danger fill, and localized
   effects are in place.
10. **Timed Rewards and Power-Up Effects** — Complete. One timed pulsing reward,
   safe inactive claims, active reward defusal, saved Gem/inventory collection,
   expiry cleanup, and all six automatic power-up effects are in place.
11. **Lifetime Score and Checkpoint Choice** — Complete. Lifetime defusals
   persist per successful resolution; every 20 defusals temporarily queues one saved
   choice; the post-Game-Over/restored-pending overlay grants exactly one
   catalog power-up per atomic, cloud-queued claim.
12. **Countdown, Pause, and Rewarded Revive** — Complete. Pause resumes and
   rewarded revives use one manager-owned 3–2–1 countdown that
   freezes gameplay. One revive per run restores one life and a fresh wave,
   followed by a five-second 75%–100% timer grace curve.
13. **Ads, Settings, and Audio** — Complete. Persisted sound enable/volume
   controls, supplied-audio playback settings, safe banner reservations, atomic
   fourth-run interstitial cadence, offline deferral, single-failure release,
   earned-callback-only rewarded revive, debug simulation, and a release-safe
   native adapter boundary are in place. Billing and purchase restoration are
   not in scope.
14. **Android Release Readiness and Final Validation** — Configure Play
   Console, export/signing, ad identifiers, and complete end-to-end tests. Paid
   product configuration is excluded.

### Deferred, Unscheduled Work

- **Payments and Paid Content** — Only after an explicit future user request:
  decide whether skins and/or power-ups should be sold, then design the billing
  UX, author paid catalog entries, integrate Google Play Billing, configure
  product IDs, restore purchases, test entitlements, and update release checks.
  This is not assigned a milestone number and does not block Milestones 8–14.

## Required Validation

- Fresh install and legacy-save migration yield `default_bomb` owned/equipped/selected.
- Same Google Play Games account restores Gems, scores, settings, ownership, and pending choices after uninstall/reinstall.
- Cloud conflict always prompts for a choice rather than silently losing state.
- New runs are blocked without validated internet; active runs can finish after disconnect.
- UI works on small phone, large phone, tablet, cutout, and varying portrait aspect ratios.
- New catalog Resources render in Shop without per-item UI code/layout changes.
- No UI contains a mockup screenshot as the implemented screen.
- No Gem-purchase route exists.
- Every inactive non-reward bomb tap costs one life; inactive reward-bomb taps are safe claims.
- Reward icons pulse and clean up correctly.
- New runs start immediately; resume and revive each show one 3–2–1 countdown with no gameplay time advancing.
- Revive grace begins at 75% timer speed and reaches normal speed after five gameplay seconds.
- Offline interstitial deferral is persisted and attempted once after reconnection; ad failure never traps the player.
- All save, inventory, and currency UI refreshes are signal-driven.
- No paid acquisition button, billing request, product ID, or purchase-restore
  path is active while the payment hold remains in effect.

## Explicit Defaults

- Portrait Android, Godot 4.6, GL Compatibility renderer, and 60 FPS target.
- Gems remain the only active in-game currency.
- Initial Gem reward chance is 15% unless balance design changes it.
- No custom backend is currently planned; Google Play Games Saved Games is the cloud-recovery service.
- Local/global leaderboards, achievements, daily rewards, events, bundles, extra currencies, and social features remain future work, but the catalog/UI architecture must not block them.
- One milestone is implemented, tested, and approved per future prompt.
