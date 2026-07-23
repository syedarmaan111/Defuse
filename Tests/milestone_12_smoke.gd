extends Node

## Headless coverage for immediate first-run play, reusable pause/revive
## countdowns, one rewarded revive per run, and five gameplay seconds of grace.

const MAIN_SCENE := preload("res://Scenes/Main.tscn")

var _countdown_ticks: Array[int] = []
var _countdown_reasons: Array[String] = []
var _rewarded_requests := 0


func _ready() -> void:
	assert(SaveManager.apply_cloud_snapshot(SaveData.new().to_dictionary(false)))
	GameManager.countdown_started.connect(
		func(reason: String) -> void: _countdown_reasons.append(reason)
	)
	GameManager.countdown_tick.connect(
		func(value: int, _reason: String) -> void: _countdown_ticks.append(value)
	)
	GameManager.rewarded_revive_requested.connect(
		func() -> void: _rewarded_requests += 1
	)

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await _test_immediate_new_run_and_pause_countdown(main)
	await _test_rewarded_revive_and_grace(main)
	_test_offline_revive_is_unavailable()
	print("Milestone 12 smoke test passed.")
	get_tree().quit()


func _test_immediate_new_run_and_pause_countdown(main: Node) -> void:
	GameManager.start_game()
	var countdown: Control = main.get_node(
		"NotificationRoot/PrePlayCountdownOverlay"
	)
	assert(GameManager.get_run_state_name() == "running")
	assert(GameManager.get_countdown_reason().is_empty())
	assert(GameManager.get_countdown_value() == 0)
	assert(not countdown.visible)
	assert(_countdown_reasons.is_empty())
	assert(_countdown_ticks.is_empty())

	var active_index: int = GameManager.get_active_bomb_indices()[0]
	var timer_before := GameManager.get_bomb_time_remaining(active_index)
	GameManager._process(0.1)
	assert(GameManager.get_bomb_time_remaining(active_index) < timer_before)
	GameManager.pause_game()
	assert(GameManager.get_run_state_name() == "paused")
	assert(main.get_node("OverlayRoot/PauseMenu").visible)
	var paused_timer := GameManager.get_bomb_time_remaining(active_index)
	var paused_reward := GameManager._reward_spawn_remaining
	GameManager._process(1.0)
	assert(is_equal_approx(GameManager.get_bomb_time_remaining(active_index), paused_timer))
	assert(is_equal_approx(GameManager._reward_spawn_remaining, paused_reward))

	var countdown_start_count := _countdown_reasons.size()
	GameManager.resume_game()
	assert(GameManager.get_run_state_name() == "countdown")
	assert(GameManager.get_countdown_reason() == "resume")
	assert(countdown.visible)
	assert(countdown.get_node("%CountdownLabel").text == "3")
	assert(not GameManager.handle_bomb_tapped(active_index))
	GameManager.resume_game()
	assert(_countdown_reasons.size() == countdown_start_count + 1)
	GameManager._process(GameManager.COUNTDOWN_STEP_SECONDS)
	assert(GameManager.get_countdown_value() == 2)
	GameManager._process(GameManager.COUNTDOWN_STEP_SECONDS)
	assert(GameManager.get_countdown_value() == 1)
	GameManager._process(GameManager.COUNTDOWN_STEP_SECONDS)
	assert(GameManager.get_run_state_name() == "running")
	assert(_countdown_ticks == [3, 2, 1])


func _test_rewarded_revive_and_grace(main: Node) -> void:
	var score_before_revive := GameManager.current_score
	var defusals_before_revive := GameManager.current_defusals
	var stage_before_revive := int(GameManager.get_current_stage_config()["stage"])
	GameManager.current_lives = 1
	assert(GameManager.lose_life())
	assert(GameManager.get_run_state_name() == "game_over")
	assert(GameManager.can_offer_rewarded_revive())
	var game_over := main.get_node("OverlayRoot/GameOverScreen")
	assert(game_over.get_node("%ReviveButton").visible)
	var save_revision_before_revive := int(
		SaveManager.get_snapshot()["save_revision"]
	)

	game_over.get_node("%ReviveButton").pressed.emit()
	await get_tree().process_frame
	assert(_rewarded_requests == 1)
	assert(GameManager.get_run_state_name() == "countdown")
	assert(GameManager.get_countdown_reason() == "revive")
	assert(GameManager.current_lives == 1)
	assert(GameManager.current_score == score_before_revive)
	assert(GameManager.current_defusals == defusals_before_revive)
	assert(int(GameManager.get_current_stage_config()["stage"]) == stage_before_revive)
	assert(
		GameManager.get_active_bomb_indices().size()
		== int(GameManager.get_current_stage_config()["active_bombs"])
	)
	assert(GameManager.get_revive_grace_remaining() == 0.0)
	assert(not GameManager.handle_bomb_tapped(GameManager.get_active_bomb_indices()[0]))

	GameManager._finish_countdown()
	assert(GameManager.get_run_state_name() == "running")
	assert(is_equal_approx(
		GameManager.get_revive_grace_remaining(),
		GameManager.REVIVE_GRACE_DURATION_SECONDS
	))
	assert(is_equal_approx(GameManager.get_revive_grace_timer_multiplier(), 0.75))
	var gameplay := main.get_node("ScreenRoot/Gameplay")
	assert(gameplay.get_node("%ReviveGraceStatus").visible)

	var active_index: int = GameManager.get_active_bomb_indices()[0]
	var timer_before_grace := GameManager.get_bomb_time_remaining(active_index)
	GameManager._process(1.0)
	assert(is_equal_approx(
		GameManager.get_bomb_time_remaining(active_index),
		timer_before_grace - 0.75
	))
	assert(is_equal_approx(GameManager.get_revive_grace_remaining(), 4.0))
	assert(is_equal_approx(GameManager.get_revive_grace_timer_multiplier(), 0.8))

	# Keep this bomb alive while directly validating the remainder of the smooth
	# five-second grace curve.
	GameManager._bomb_time_remaining[active_index] = 100.0
	GameManager._bomb_timer_durations[active_index] = 100.0
	GameManager._process(1.5)
	assert(is_equal_approx(GameManager.get_revive_grace_timer_multiplier(), 0.875))
	GameManager._process(2.5)
	assert(is_equal_approx(GameManager.get_revive_grace_remaining(), 0.0))
	assert(is_equal_approx(GameManager.get_revive_grace_timer_multiplier(), 1.0))
	assert(
		int(SaveManager.get_snapshot()["save_revision"])
		== save_revision_before_revive
	)

	GameManager.current_lives = 1
	assert(GameManager.lose_life())
	assert(GameManager.get_run_state_name() == "game_over")
	assert(not GameManager.can_offer_rewarded_revive())
	assert(not game_over.get_node("%ReviveButton").visible)
	assert(not GameManager.grant_rewarded_revive())


func _test_offline_revive_is_unavailable() -> void:
	GameManager.start_game()
	NetworkManager._online_gate_enabled = true
	NetworkManager._development_bypass = false
	NetworkManager._set_connection_state(false, false)
	GameManager.current_lives = 1
	assert(GameManager.lose_life())
	assert(GameManager.get_run_state_name() == "game_over")
	assert(not GameManager.can_offer_rewarded_revive())
	assert(not GameManager.request_rewarded_revive())
