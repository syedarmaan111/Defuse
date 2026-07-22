extends Node

## Headless coverage for Milestone 8 run state, responsive grids, HUD, and
## stage progression. Bomb timers and inactive-tap penalties remain Milestone 9.

const GAMEPLAY_SCENE := preload("res://Scenes/Gameplay/Gameplay.tscn")


func _ready() -> void:
	_seed_progression()
	var gameplay := GAMEPLAY_SCENE.instantiate()
	add_child(gameplay)
	await get_tree().process_frame

	_test_run_start(gameplay)
	_test_bomb_cell_intent(gameplay)
	_test_stage_progression(gameplay)
	_test_pause_and_lives(gameplay)
	print("Milestone 8 smoke test passed.")
	get_tree().quit()


func _seed_progression() -> void:
	var snapshot := SaveData.new().to_dictionary(false)
	snapshot["best_score"] = 5
	snapshot["currencies"] = {"gems": 9}
	assert(SaveManager.apply_cloud_snapshot(snapshot))


func _test_run_start(gameplay: Control) -> void:
	GameManager.start_game()
	assert(GameManager.get_current_screen_name() == "gameplay")
	assert(GameManager.get_run_state_name() == "running")
	assert(GameManager.current_score == 0)
	assert(GameManager.current_lives == 3)
	assert(gameplay.get_presented_score() == 0)
	assert(_get_stage_number() == 1)
	assert(gameplay.get_bomb_count() == 4)
	assert(gameplay.get_node("%GemCountLabel").text == "9")
	assert(gameplay.get_node_or_null("%StageLabel") == null)
	assert(gameplay.get_node_or_null("%ObjectiveLabel") == null)
	_assert_valid_layout(gameplay, 2, 1)
	for cell in gameplay.get_node("%BombGrid").get_children():
		assert(cell.get_node_or_null("StatusLabel") == null)


func _test_bomb_cell_intent(gameplay: Control) -> void:
	var active_index: int = GameManager.get_active_bomb_indices()[0]
	var active_cell: BombCell = gameplay.get_node("%BombGrid").get_child(active_index)
	active_cell.get_node("%TouchTarget").pressed.emit()
	assert(GameManager.current_score == 1)
	assert(gameplay.get_presented_score() == 1)

	assert(not GameManager.handle_bomb_tapped(-1))
	assert(GameManager.current_score == 1)
	assert(GameManager.current_lives == 3)


func _test_stage_progression(gameplay: Control) -> void:
	_score_to(10)
	assert(_get_stage_number() == 2)
	_assert_valid_layout(gameplay, 2, 2)
	assert(is_equal_approx(float(GameManager.get_current_stage_config()["timer_seconds"]), 2.25))
	_assert_only_tapped_bomb_is_replaced(gameplay)

	_score_to(24)
	var stage_two_wave := GameManager.get_active_bomb_indices()
	assert(stage_two_wave.size() == 2)
	assert(GameManager.handle_bomb_tapped(stage_two_wave[0]))
	assert(GameManager.current_score == 25)
	assert(_get_stage_number() == 2)
	assert(GameManager.get_pending_stage_number() == 3)
	assert(GameManager.get_active_bomb_indices() == stage_two_wave.slice(1))
	assert(GameManager.handle_bomb_tapped(stage_two_wave[1]))
	assert(_get_stage_number() == 3)
	assert(GameManager.get_pending_stage_number() == 0)
	assert(gameplay.get_bomb_count() == 9)
	_assert_valid_layout(gameplay, 3, 2)

	_score_to(44)
	var stage_three_wave := GameManager.get_active_bomb_indices()
	assert(GameManager.handle_bomb_tapped(stage_three_wave[0]))
	assert(_get_stage_number() == 3)
	assert(GameManager.get_pending_stage_number() == 4)
	assert(GameManager.get_active_bomb_indices() == stage_three_wave.slice(1))
	assert(GameManager.handle_bomb_tapped(stage_three_wave[1]))
	assert(_get_stage_number() == 4)
	_assert_valid_layout(gameplay, 3, 3)

	_score_to(69)
	var stage_four_wave := GameManager.get_active_bomb_indices()
	assert(stage_four_wave.size() == 3)
	assert(GameManager.handle_bomb_tapped(stage_four_wave[0]))
	assert(_get_stage_number() == 4)
	assert(GameManager.get_pending_stage_number() == 5)
	assert(GameManager.get_active_bomb_indices() == stage_four_wave.slice(1))
	assert(GameManager.handle_bomb_tapped(stage_four_wave[1]))
	assert(GameManager.get_active_bomb_indices() == stage_four_wave.slice(2))
	assert(GameManager.handle_bomb_tapped(stage_four_wave[2]))
	assert(_get_stage_number() == 5)
	assert(GameManager.get_pending_stage_number() == 0)
	assert(gameplay.get_bomb_count() == 16)
	_assert_valid_layout(gameplay, 4, 3)
	assert(is_equal_approx(float(GameManager.get_current_stage_config()["timer_seconds"]), 1.5))
	var first_cell: BombCell = gameplay.get_node("%BombGrid").get_child(0)
	assert(is_equal_approx(first_cell._base_visual_scale, 1.16))
	gameplay._refresh_grid_layout()
	assert(gameplay.get_node("SafeMargins").get_theme_constant("margin_left") == 20)
	assert(gameplay.get_node("%BombGrid").get_theme_constant("h_separation") == 6)


func _test_pause_and_lives(gameplay: Control) -> void:
	GameManager.pause_game()
	assert(GameManager.get_run_state_name() == "paused")
	var score_before_tap := GameManager.current_score
	assert(not GameManager.handle_bomb_tapped(GameManager.get_active_bomb_indices()[0]))
	assert(GameManager.current_score == score_before_tap)
	GameManager.resume_game()
	assert(GameManager.get_run_state_name() == "running")

	assert(GameManager.lose_life())
	assert(GameManager.lose_life())
	assert(GameManager.current_lives == 1)
	assert(gameplay.get_node("%Life1").filled)
	assert(not gameplay.get_node("%Life2").filled)
	assert(not gameplay.get_node("%Life3").filled)
	assert(GameManager.lose_life())
	assert(GameManager.get_run_state_name() == "game_over")
	assert(GameManager.get_current_screen_name() == "game_over")
	assert(SaveManager.get_best_score() == GameManager.current_score)
	assert(gameplay.get_presented_active_bomb_indices().is_empty())


func _score_to(target_score: int) -> void:
	while GameManager.current_score < target_score:
		var active_indices := GameManager.get_active_bomb_indices()
		assert(not active_indices.is_empty())
		assert(GameManager.handle_bomb_tapped(active_indices[0]))


func _assert_only_tapped_bomb_is_replaced(gameplay: Control) -> void:
	var previous_active := GameManager.get_active_bomb_indices()
	assert(previous_active.size() >= 2)
	var resolved_index: int = previous_active[0]
	assert(GameManager.handle_bomb_tapped(resolved_index))
	var next_active := GameManager.get_active_bomb_indices()
	assert(next_active.size() == previous_active.size())
	for surviving_index in previous_active.slice(1):
		assert(next_active.has(surviving_index))
	assert(not next_active.has(resolved_index))
	assert(gameplay.get_presented_active_bomb_indices() == next_active)


func _assert_valid_layout(gameplay: Control, grid_side: int, active_count: int) -> void:
	var active_indices: Array[int] = gameplay.get_presented_active_bomb_indices()
	assert(active_indices.size() == active_count)
	var unique_indices := {}
	for bomb_index in active_indices:
		assert(bomb_index >= 0 and bomb_index < grid_side * grid_side)
		unique_indices[bomb_index] = true
	assert(unique_indices.size() == active_count)


func _find_inactive_index(cell_count: int) -> int:
	for bomb_index in cell_count:
		if not GameManager.get_active_bomb_indices().has(bomb_index):
			return bomb_index
	return -1


func _get_stage_number() -> int:
	return int(GameManager.get_current_stage_config()["stage"])
