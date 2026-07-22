extends Node

## Headless coverage for timed rewards, safe collection, persistence, and all
## six automatic power-up effects.

const GAMEPLAY_SCENE := preload("res://Scenes/Gameplay/Gameplay.tscn")
const PROFILE_SCENE := preload("res://Scenes/UI/ProfileScreen.tscn")
const POWER_UP_UNLOCK_OVERLAY := preload("res://Scenes/UI/PowerUpUnlockOverlay.tscn")
const POWER_IDS := [
	"shield", "slow_motion", "scan", "extra_life", "combo_boost", "chain_defuse"
]

var _activations: Array[String] = []
var _protected_indices: Array[int] = []


func _ready() -> void:
	assert(SaveManager.apply_cloud_snapshot(SaveData.new().to_dictionary(false)))
	PowerUpManager.power_up_activated.connect(
		func(power_up_id: String, _context: Dictionary) -> void:
			_activations.append(power_up_id)
	)
	GameManager.bomb_protected.connect(
		func(bomb_index: int, _power_up_id: String) -> void:
			_protected_indices.append(bomb_index)
	)

	var gameplay := GAMEPLAY_SCENE.instantiate()
	add_child(gameplay)
	await get_tree().process_frame
	GameManager.start_game()
	_test_reward_schedule_and_gem_collection(gameplay)
	await _test_lifetime_progression_and_unlocks()
	_unlock_remaining_power_up_catalog()
	GameManager.start_game()
	await get_tree().process_frame
	_test_power_up_collection(gameplay)
	_test_shield_and_extra_life()
	_score_to(10)
	_test_scan_and_slow_motion(gameplay)
	_test_combo_and_chain_defuse()
	_test_checkpoint_requirement()
	print("Milestone 10 smoke test passed.")
	get_tree().quit()


func _test_reward_schedule_and_gem_collection(gameplay: Control) -> void:
	var amount_counts := {1: 0, 2: 0, 5: 0}
	GameManager._random.seed = 123456
	for _roll_index in 10000:
		var rolled_amount := GameManager._roll_gem_reward_amount()
		assert(rolled_amount in amount_counts)
		amount_counts[rolled_amount] += 1
	assert(amount_counts[1] > amount_counts[2])
	assert(amount_counts[2] > amount_counts[5])
	GameManager._random.randomize()

	assert(GameManager.get_reward_snapshot().is_empty())
	assert(GameManager._reward_spawn_remaining >= 7.0)
	assert(GameManager._reward_spawn_remaining <= 11.0)
	GameManager._reward_spawn_remaining = 0.0
	GameManager._process_reward(0.0)
	assert(GameManager.get_reward_snapshot()["reward_type"] == "gem")
	GameManager._remove_reward("test_reset")

	var inactive_index := _find_inactive_index()
	assert(GameManager._place_reward(inactive_index, "gem", "gems", "Gem", 6.0))
	assert(not GameManager._place_reward(inactive_index, "gem", "gems", "Gem", 6.0))
	var badge: Control = gameplay.get_node("%BombGrid").get_child(inactive_index).reward_badge
	assert(badge.visible)
	assert(badge._pulse_tween != null)
	# The bomb's round body is below the cell midpoint because the fuse occupies
	# the top of the artwork. The reward marker follows that optical center.
	assert(badge.anchor_left == 0.5 and is_equal_approx(badge.anchor_top, 0.585))
	assert(badge.size.x >= 96.0 and badge.size.y >= 96.0)
	assert(badge.gem_icon.visible)
	assert(badge.gem_amount_label.text == "+1")
	assert(GameManager.get_reward_snapshot()["amount"] == 1)
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(EconomyManager.get_gem_balance() == 1)
	assert(GameManager.current_lives == 3)
	assert(GameManager.current_score == 0)
	assert(GameManager.get_reward_snapshot().is_empty())

	var active_index: int = GameManager.get_active_bomb_indices()[0]
	assert(GameManager._place_reward(active_index, "gem", "gems", "+5 Gems", 6.0, 5))
	badge = gameplay.get_node("%BombGrid").get_child(active_index).reward_badge
	assert(badge.gem_amount_label.text == "+5")
	assert(GameManager.handle_bomb_tapped(active_index))
	assert(EconomyManager.get_gem_balance() == 6)
	assert(GameManager.current_score == 1)

	inactive_index = _find_inactive_index()
	assert(GameManager._place_reward(inactive_index, "gem", "gems", "+2 Gems", 0.1, 2))
	badge = gameplay.get_node("%BombGrid").get_child(inactive_index).reward_badge
	assert(badge.gem_amount_label.text == "+2")
	GameManager._process_reward(0.11)
	assert(GameManager.get_reward_snapshot().is_empty())
	assert(EconomyManager.get_gem_balance() == 6)


func _test_lifetime_progression_and_unlocks() -> void:
	assert(SaveManager.get_lifetime_defusals() == 1)
	var profile := PROFILE_SCENE.instantiate()
	add_child(profile)
	await get_tree().process_frame
	assert(profile.get_presented_state()["lifetime_defusals"] == "1")

	assert(SaveManager.add_lifetime_defusals(59))
	assert(SaveManager.get_lifetime_defusals() == 60)
	assert(profile.get_presented_state()["lifetime_defusals"] == "60")
	assert(PowerUpManager.get_unlocked_ids().is_empty())

	GameManager.finish_run()
	assert(PowerUpManager.get_pending_unlock_choice_count() == 3)
	assert(SaveManager.get_claimed_power_up_checkpoints() == [20, 40, 60])
	var overlay: PowerUpUnlockOverlay = POWER_UP_UNLOCK_OVERLAY.instantiate()
	add_child(overlay)
	await get_tree().process_frame
	assert(overlay.show_if_pending())
	assert(overlay.visible)
	assert(overlay.items.get_child_count() == 6)
	for choice_index in 3:
		var card: PowerUpUnlockCard = overlay.items.get_child(0)
		var selected_id := card.power_up_id
		card.get_node("%UnlockButton").pressed.emit()
		assert(PowerUpManager.is_unlocked(selected_id))
		assert(PowerUpManager.get_pending_unlock_choice_count() == 2 - choice_index)
		if choice_index < 2:
			assert(overlay.visible)
			assert(overlay.items.get_child_count() == 5 - choice_index)
	assert(not overlay.visible)
	assert(profile.get_presented_state()["unlocked_power_ups"] == "3")
	profile.queue_free()
	overlay.queue_free()


func _unlock_remaining_power_up_catalog() -> void:
	var snapshot := SaveManager.get_snapshot(false)
	snapshot["unlocked_powerup_ids"] = POWER_IDS.duplicate()
	assert(SaveManager.apply_cloud_snapshot(snapshot))
	for power_up_id in POWER_IDS:
		assert(PowerUpManager.is_unlocked(power_up_id))
		assert(PowerUpManager.get_definition(power_up_id).icon != null)


func _test_power_up_collection(gameplay: Control) -> void:
	var inactive_index := _find_inactive_index()
	assert(GameManager._place_reward(
		inactive_index, "power_up", "shield", "Shield", 6.0
	))
	var badge: RewardBadge = gameplay.get_node("%BombGrid").get_child(inactive_index).reward_badge
	assert(badge.power_icon.visible)
	assert(not badge.gem_amount_label.visible)
	assert(badge.power_icon.texture == PowerUpManager.get_definition("shield").icon)
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(PowerUpManager.get_quantity("shield") == 1)
	assert(GameManager.current_lives == 3)
	assert(not gameplay.get_node("%BombGrid").get_child(inactive_index).reward_badge.visible)

	# Collecting Extra Life while a heart is missing restores it immediately and
	# gives the player a visible pop-back animation.
	GameManager.current_lives = 2
	GameManager.lives_changed.emit(2, GameManager.MAXIMUM_LIVES)
	inactive_index = _find_inactive_index([inactive_index])
	assert(GameManager._place_reward(
		inactive_index, "power_up", "extra_life", "Extra Life", 6.0
	))
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(GameManager.current_lives == 3)
	assert(PowerUpManager.get_quantity("extra_life") == 0)
	var restored_heart: LifeHeart = gameplay.get_node("%Life3")
	assert(restored_heart.filled)
	assert(restored_heart.scale.x < 1.0)

	# At three hearts, another Extra Life is collected but never stored.
	assert(GameManager._place_reward(
		inactive_index, "power_up", "extra_life", "Extra Life", 6.0
	))
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(GameManager.current_lives == 3)
	assert(PowerUpManager.get_quantity("extra_life") == 0)


func _test_shield_and_extra_life() -> void:
	var inactive_index := _find_inactive_index()
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(PowerUpManager.get_quantity("shield") == 0)
	assert(GameManager.current_lives == 3)
	assert(_protected_indices.has(inactive_index))
	assert(_activations.has("shield"))

	assert(PowerUpManager.add_quantity("extra_life", 1))
	var another_inactive := _find_inactive_index([inactive_index])
	assert(GameManager.handle_bomb_tapped(another_inactive))
	assert(PowerUpManager.get_quantity("extra_life") == 0)
	assert(GameManager.current_lives == 3)
	assert(_activations.has("extra_life"))


func _test_scan_and_slow_motion(gameplay: Control) -> void:
	assert(GameManager.get_active_bomb_indices().size() == 2)
	var active := GameManager.get_active_bomb_indices()
	assert(PowerUpManager.add_quantity("scan", 1))
	GameManager._bomb_time_remaining[active[0]] = 0.9
	GameManager._bomb_time_remaining[active[1]] = 2.0
	PowerUpManager.evaluate_timer_pressure(
		active, GameManager._bomb_time_remaining, GameManager._bomb_timer_durations
	)
	assert(PowerUpManager.get_quantity("scan") == 0)
	assert(_activations.has("scan"))
	assert(gameplay.get_node("%BombGrid").get_child(active[0])._is_scanned)
	assert(gameplay.get_node("%ScanShade").visible)
	for bomb_index in active:
		var active_cell: BombCell = gameplay.get_node("%BombGrid").get_child(bomb_index)
		assert(active_cell.scan_glow.visible)
		assert(active_cell.z_index == 11)
	var inactive_index := _find_inactive_index()
	assert(not gameplay.get_node("%BombGrid").get_child(inactive_index).scan_glow.visible)

	assert(PowerUpManager.add_quantity("slow_motion", 1))
	GameManager._bomb_time_remaining[active[0]] = 0.5
	GameManager._bomb_time_remaining[active[1]] = 0.5
	PowerUpManager.evaluate_timer_pressure(
		active, GameManager._bomb_time_remaining, GameManager._bomb_timer_durations
	)
	assert(PowerUpManager.get_quantity("slow_motion") == 0)
	assert(is_equal_approx(PowerUpManager.get_timer_speed_multiplier(), 0.35))
	assert(is_equal_approx(PowerUpManager.get_timed_effect_remaining("slow_motion"), 8.0))
	assert(gameplay.get_node("%SlowMotionStatus").visible)
	assert(gameplay.get_node("%SlowMotionTint").visible)
	GameManager._bomb_time_remaining[active[0]] = 1.0
	GameManager._process(0.1)
	assert(is_equal_approx(GameManager.get_bomb_time_remaining(active[0]), 0.965))

	# The timer rate eases back to normal over two seconds instead of snapping.
	PowerUpManager._process(8.0)
	assert(is_equal_approx(PowerUpManager.get_timer_speed_multiplier(), 0.35))
	PowerUpManager._process(1.0)
	var recovering_multiplier := PowerUpManager.get_timer_speed_multiplier()
	assert(recovering_multiplier > 0.35 and recovering_multiplier < 1.0)
	PowerUpManager._process(1.0)
	assert(is_equal_approx(PowerUpManager.get_timer_speed_multiplier(), 1.0))


func _test_combo_and_chain_defuse() -> void:
	assert(PowerUpManager.add_quantity("combo_boost", 1))
	for _index in 4:
		PowerUpManager.register_successful_defusal()
	assert(PowerUpManager.get_quantity("combo_boost") == 0)
	assert(PowerUpManager.get_score_multiplier() == 2)
	assert(_activations.has("combo_boost"))

	assert(PowerUpManager.add_quantity("chain_defuse", 1))
	var score_before := GameManager.current_score
	var defusals_before := GameManager.current_defusals
	var lifetime_before := SaveManager.get_lifetime_defusals()
	var active_index: int = GameManager.get_active_bomb_indices()[0]
	assert(GameManager.handle_bomb_tapped(active_index))
	assert(PowerUpManager.get_quantity("chain_defuse") == 0)
	assert(_activations.has("chain_defuse"))
	assert(GameManager.current_score == score_before + 4)
	assert(GameManager.current_defusals == defusals_before + 2)
	assert(SaveManager.get_lifetime_defusals() == lifetime_before + 2)
	assert(is_equal_approx(PowerUpManager.get_timed_effect_remaining("chain_defuse"), 6.0))
	assert(GameManager.get_active_bomb_indices().size() == 2)

	# A second manual defusal within the window chains again without consuming a
	# second item. This is the behavior that distinguishes it from the old one-shot.
	active_index = GameManager.get_active_bomb_indices()[0]
	assert(GameManager.handle_bomb_tapped(active_index))
	assert(GameManager.current_score == score_before + 8)
	assert(GameManager.current_defusals == defusals_before + 4)
	assert(SaveManager.get_lifetime_defusals() == lifetime_before + 4)
	assert(PowerUpManager.get_quantity("chain_defuse") == 0)
	PowerUpManager._process(6.01)
	assert(is_equal_approx(PowerUpManager.get_timed_effect_remaining("chain_defuse"), 0.0))


func _test_checkpoint_requirement() -> void:
	var definition := PowerUpManager.get_definition("shield")
	var option: AcquisitionOption = definition.acquisition_options[0]
	assert(option.lifetime_score_required == 20)


func _score_to(target_score: int) -> void:
	while GameManager.current_score < target_score:
		var active_index: int = GameManager.get_active_bomb_indices()[0]
		assert(GameManager.handle_bomb_tapped(active_index))


func _find_inactive_index(excluded: Array[int] = []) -> int:
	var grid_side := int(GameManager.get_current_stage_config()["grid_side"])
	for bomb_index in grid_side * grid_side:
		if (
			not GameManager.get_active_bomb_indices().has(bomb_index)
			and not excluded.has(bomb_index)
			and not GameManager._resolution_cooldowns.has(bomb_index)
		):
			return bomb_index
	return -1
