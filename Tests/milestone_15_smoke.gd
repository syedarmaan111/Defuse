extends Node

## Deterministic coverage for Time Attack, Zen, and Hardcore rules.

const MAIN_SCENE := preload("res://Scenes/Main.tscn")

var _run_finish_events: Array[Dictionary] = []
var _explosion_events: Array[Dictionary] = []


func _ready() -> void:
	AdManager._simulation_enabled = true
	GameManager.run_finished.connect(
		func(reason: String, final_score: int) -> void:
			_run_finish_events.append({"reason": reason, "score": final_score})
	)
	GameManager.bomb_exploded.connect(
		func(bomb_index: int, reason: String) -> void:
			_explosion_events.append({"bomb_index": bomb_index, "reason": reason})
	)

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame

	_test_authored_mode_curves()
	_test_time_attack(main)
	_test_zen()
	_test_hardcore()
	print("Milestone 15 smoke test passed.")
	get_tree().quit()


func _test_authored_mode_curves() -> void:
	var time_attack := GameManager.MODE_CATALOG.get_mode("time_attack")
	assert(time_attack != null)
	assert(time_attack.run_duration_seconds == 60.0)
	assert(not time_attack.has_life_system)
	assert(not time_attack.power_ups_enabled)
	assert(time_attack.grid_gem_rewards_enabled)
	assert(not time_attack.rewarded_revive_enabled)
	assert(not time_attack.lifetime_credit_enabled)
	var expected_time_attack := [
		[0, 2, 2, 2.2],
		[20, 3, 3, 1.95],
		[50, 3, 5, 1.7],
		[90, 4, 6, 1.5],
		[140, 4, 8, 1.3],
	]
	for index in expected_time_attack.size():
		var stage := time_attack.stages[index]
		var expected: Array = expected_time_attack[index]
		assert(stage.starts_at == expected[0])
		assert(stage.grid_side == expected[1])
		assert(stage.active_bombs == expected[2])
		assert(is_equal_approx(stage.timer_seconds, expected[3]))

	var zen := GameManager.MODE_CATALOG.get_mode("zen")
	var hardcore := GameManager.MODE_CATALOG.get_mode("hardcore")
	assert(zen.maximum_lives == 3)
	assert(zen.power_ups_enabled)
	assert(zen.grid_gem_rewards_enabled)
	assert(zen.rewarded_revive_enabled)
	assert(zen.lifetime_credit_enabled)
	assert(hardcore.maximum_lives == 1)
	assert(not hardcore.power_ups_enabled)
	assert(hardcore.grid_gem_rewards_enabled)
	assert(hardcore.rewarded_revive_enabled)
	assert(hardcore.lifetime_credit_enabled)
	for stage in zen.stages:
		assert(is_equal_approx(stage.timer_seconds, 2.6))
	for stage in hardcore.stages:
		assert(is_equal_approx(stage.timer_seconds, 1.0))


func _test_time_attack(main: Node) -> void:
	_apply_fresh_progress(1000)
	assert(PowerUpManager.unlock("shield", 2))
	GameManager.start_game("time_attack")
	assert(GameManager.get_run_state_name() == "running")
	assert(GameManager.get_current_stage_config() == {
		"stage": 1,
		"grid_side": 2,
		"active_bombs": 2,
		"timer_seconds": 2.2,
		"starts_at": 0,
	})
	assert(GameManager.current_lives == 0)
	assert(GameManager.get_active_bomb_indices().size() == 2)
	assert(not GameManager.are_power_ups_enabled_for_run())
	assert(not GameManager.can_offer_rewarded_revive())
	assert(not GameManager.grant_rewarded_revive())

	var gameplay: Control = main.get_node("ScreenRoot/Gameplay")
	assert(not gameplay.get_node("%Lives").visible)
	assert(gameplay.get_node("%ModePhaseLabel").text == "TIME  60")

	# Gems remain safe grid rewards, while power-up rewards are rejected at the
	# manager boundary even when a caller attempts to place one directly.
	var inactive_index := _find_inactive_index()
	var gems_before := EconomyManager.get_gem_balance()
	assert(GameManager._place_reward(inactive_index, "gem", "gems", "+2 Gems", 6.0, 2))
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(EconomyManager.get_gem_balance() == gems_before + 2)
	assert(not GameManager._place_reward(
		inactive_index, "power_up", "shield", "Shield", 6.0, 1
	))
	GameManager._spawn_random_reward()
	var spawned_reward := GameManager.get_reward_snapshot()
	assert(spawned_reward["reward_type"] == "gem")
	GameManager._remove_reward("test_cleanup")

	# Wrong taps and timer expiry still produce localized explosions, but the
	# no-life run continues and immediately restores the active count.
	var explosions_before := _explosion_events.size()
	var shields_before := PowerUpManager.get_quantity("shield")
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(_explosion_events.size() == explosions_before + 1)
	assert(_explosion_events.back()["reason"] == "inactive_tap")
	assert(GameManager.current_lives == 0)
	assert(PowerUpManager.get_quantity("shield") == shields_before)
	assert(GameManager.get_run_state_name() == "running")

	var expiring_index: int = GameManager.get_active_bomb_indices()[0]
	GameManager._bomb_time_remaining[expiring_index] = 0.01
	GameManager._process(0.02)
	assert(_explosion_events.back()["reason"] == "timer_expired")
	assert(PowerUpManager.get_quantity("shield") == shields_before)
	assert(GameManager.get_active_bomb_indices().size() == 2)
	assert(GameManager.get_run_state_name() == "running")

	var lifetime_before := SaveManager.get_lifetime_defusals()
	_defuse_until(20)
	_assert_current_curve(20, 3, 3, 1.95)
	_defuse_until(50)
	_assert_current_curve(50, 3, 5, 1.7)
	_defuse_until(90)
	_assert_current_curve(90, 4, 6, 1.5)
	_defuse_until(140)
	_assert_current_curve(140, 4, 8, 1.3)
	assert(GameManager.current_score == 140)
	assert(SaveManager.get_lifetime_defusals() == lifetime_before)

	# Only active gameplay advances the clock. Pause and the complete resume
	# countdown leave its exact value untouched.
	var time_before_pause := GameManager.get_run_time_remaining()
	GameManager.pause_game()
	GameManager._process(30.0)
	assert(is_equal_approx(GameManager.get_run_time_remaining(), time_before_pause))
	GameManager.resume_game()
	GameManager._process(3.0)
	assert(GameManager.get_run_state_name() == "running")
	assert(is_equal_approx(GameManager.get_run_time_remaining(), time_before_pause))
	GameManager._process(1.0)
	assert(is_equal_approx(
		GameManager.get_run_time_remaining(), time_before_pause - 1.0
	))

	var finish_count_before := _run_finish_events.size()
	GameManager._run_time_remaining = 0.05
	GameManager._process(0.1)
	assert(GameManager.get_run_state_name() == "game_over")
	assert(GameManager.get_run_end_reason() == "time_up")
	assert(GameManager.get_mode_phase_name() == "TIME UP")
	assert(GameManager.get_run_time_remaining() == 0.0)
	assert(GameManager.get_active_bomb_indices().is_empty())
	assert(_run_finish_events.size() == finish_count_before + 1)
	assert(_run_finish_events.back()["reason"] == "time_up")
	assert(_run_finish_events.back()["score"] == 140)
	GameManager._process(5.0)
	GameManager.finish_run("time_up")
	assert(_run_finish_events.size() == finish_count_before + 1)
	assert(not GameManager.can_offer_rewarded_revive())


func _test_zen() -> void:
	_apply_fresh_progress(1000)
	GameManager.start_game("zen")
	assert(GameManager.get_maximum_lives() == 3)
	assert(GameManager.current_lives == 3)
	assert(GameManager.are_power_ups_enabled_for_run())
	assert(is_equal_approx(
		float(GameManager.get_current_stage_config()["timer_seconds"]), 2.6
	))

	var lifetime_before := SaveManager.get_lifetime_defusals()
	_defuse_until(70)
	assert(GameManager.get_pending_stage_number() == 5)
	while GameManager.get_current_stage_config()["stage"] != 5:
		var outgoing_indices := GameManager.get_active_bomb_indices()
		assert(not outgoing_indices.is_empty())
		assert(GameManager.handle_bomb_tapped(outgoing_indices[0]))
	assert(GameManager.get_current_stage_config()["stage"] == 5)
	assert(is_equal_approx(
		float(GameManager.get_current_stage_config()["timer_seconds"]), 2.6
	))
	for bomb_index in GameManager.get_active_bomb_indices():
		assert(is_equal_approx(GameManager.get_bomb_timer_duration(bomb_index), 2.6))
	assert(
		SaveManager.get_lifetime_defusals()
		== lifetime_before + GameManager.current_defusals
	)

	var inactive_index := _find_inactive_index()
	assert(GameManager._place_reward(
		inactive_index, "power_up", "shield", "Shield", 6.0, 1
	))
	GameManager._remove_reward("test_cleanup")
	assert(GameManager._place_reward(inactive_index, "gem", "gems", "+1 Gem"))
	GameManager._remove_reward("test_cleanup")

	GameManager.current_lives = 1
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(GameManager.get_run_state_name() == "game_over")
	assert(GameManager.current_lives == 0)
	assert(GameManager.can_offer_rewarded_revive())
	assert(GameManager.grant_rewarded_revive())
	assert(GameManager.current_lives == 1)
	assert(GameManager.is_countdown_active())
	assert(GameManager.get_active_bomb_indices().size() == 3)
	for bomb_index in GameManager.get_active_bomb_indices():
		assert(is_equal_approx(GameManager.get_bomb_timer_duration(bomb_index), 2.6))
	GameManager._process(3.0)
	assert(GameManager.get_run_state_name() == "running")
	assert(is_equal_approx(GameManager.get_revive_grace_timer_multiplier(), 0.75))
	GameManager.return_to_mode_select()


func _test_hardcore() -> void:
	_apply_fresh_progress(1000)
	assert(PowerUpManager.unlock("shield", 2))
	GameManager.start_game("hardcore")
	assert(GameManager.get_maximum_lives() == 1)
	assert(GameManager.current_lives == 1)
	assert(not GameManager.are_power_ups_enabled_for_run())
	assert(is_equal_approx(
		float(GameManager.get_current_stage_config()["timer_seconds"]), 1.0
	))
	for stage in GameManager.get_current_mode_definition().stages:
		assert(is_equal_approx(stage.timer_seconds, 1.0))

	var inactive_index := _find_inactive_index()
	var gems_before := EconomyManager.get_gem_balance()
	assert(GameManager._place_reward(inactive_index, "gem", "gems", "+1 Gem"))
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(EconomyManager.get_gem_balance() == gems_before + 1)
	assert(not GameManager._place_reward(
		inactive_index, "power_up", "shield", "Shield", 6.0, 1
	))

	var lifetime_before := SaveManager.get_lifetime_defusals()
	var active_index: int = GameManager.get_active_bomb_indices()[0]
	assert(GameManager.handle_bomb_tapped(active_index))
	assert(GameManager.current_score == 1)
	assert(SaveManager.get_lifetime_defusals() == lifetime_before + 1)

	inactive_index = _find_inactive_index()
	var shields_before := PowerUpManager.get_quantity("shield")
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(GameManager.get_run_state_name() == "game_over")
	assert(GameManager.current_lives == 0)
	assert(PowerUpManager.get_quantity("shield") == shields_before)
	assert(GameManager.get_run_end_reason() == "lives_depleted")
	assert(GameManager.can_offer_rewarded_revive())

	assert(GameManager.grant_rewarded_revive())
	assert(GameManager.current_lives == 1)
	assert(GameManager.is_countdown_active())
	assert(GameManager.get_active_bomb_indices().size() == 1)
	GameManager._process(3.0)
	assert(GameManager.get_run_state_name() == "running")
	assert(is_equal_approx(GameManager.get_revive_grace_timer_multiplier(), 0.75))

	# The first unprotected timeout after the revive ends the one-life attempt.
	active_index = GameManager.get_active_bomb_indices()[0]
	GameManager._bomb_time_remaining[active_index] = 0.01
	GameManager._process(0.02)
	assert(GameManager.get_run_state_name() == "game_over")
	assert(GameManager.current_lives == 0)
	assert(not GameManager.can_offer_rewarded_revive())


func _defuse_until(target_defusals: int) -> void:
	while GameManager.current_defusals < target_defusals:
		var active_indices := GameManager.get_active_bomb_indices()
		assert(not active_indices.is_empty())
		assert(GameManager.handle_bomb_tapped(active_indices[0]))


func _assert_current_curve(
	expected_defusals: int,
	expected_grid_side: int,
	expected_active_bombs: int,
	expected_timer_seconds: float
) -> void:
	var config := GameManager.get_current_stage_config()
	assert(GameManager.current_defusals == expected_defusals)
	assert(config["grid_side"] == expected_grid_side)
	assert(config["active_bombs"] == expected_active_bombs)
	assert(is_equal_approx(float(config["timer_seconds"]), expected_timer_seconds))
	assert(GameManager.get_active_bomb_indices().size() == expected_active_bombs)
	for bomb_index in GameManager.get_active_bomb_indices():
		assert(is_equal_approx(
			GameManager.get_bomb_timer_duration(bomb_index), expected_timer_seconds
		))


func _find_inactive_index() -> int:
	var grid_side := int(GameManager.get_current_stage_config()["grid_side"])
	for bomb_index in grid_side * grid_side:
		if (
			not GameManager.get_active_bomb_indices().has(bomb_index)
			and not GameManager._resolution_cooldowns.has(bomb_index)
		):
			return bomb_index
	return -1


func _apply_fresh_progress(lifetime_defusals: int) -> void:
	var snapshot := SaveData.new().to_dictionary(false)
	snapshot["lifetime_defusal_score"] = lifetime_defusals
	assert(SaveManager.apply_cloud_snapshot(snapshot))
