extends Node

## Regression coverage for the revised selector, Precision, and Memory behavior.

const MAIN_SCENE := preload("res://Scenes/Main.tscn")


func _ready() -> void:
	AdManager._simulation_enabled = true
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	_apply_lifetime(1000)
	await _test_selector(main)
	_test_precision(main)
	_test_standard_multitouch_batch()
	await _test_memory(main)
	print("Game mode revision smoke test passed.")
	get_tree().quit()


func _test_selector(main: Node) -> void:
	GameManager.show_mode_select_if_ready()
	await get_tree().process_frame
	var selector: Control = main.get_node("ScreenRoot/ModeSelectScreen")
	var scroll := selector.get_node("SafeMargins/Content/Scroll") as ScrollContainer
	assert(scroll.scroll_deadzone == 8)
	assert(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page)
	var first_card := selector.get_node("%Cards").get_child(0) as ModeCard
	assert(first_card.mouse_filter == Control.MOUSE_FILTER_PASS)
	assert(first_card.get_node("%PlayButton").mouse_filter == Control.MOUSE_FILTER_PASS)
	assert(first_card.get_node("%BackgroundArt").texture != null)
	assert(first_card.get_node("%NameLabel").text == "CLASSIC")
	var cards: VBoxContainer = selector.get_node("%Cards")
	assert(
		(cards.get_child(2) as ModeCard).get_node("%RecordLabel").text
		== "MAXIMUM LEVEL REACHED  0"
	)
	assert(
		(cards.get_child(4) as ModeCard).get_node("%RecordLabel").text
		== "MAXIMUM LEVEL REACHED  0"
	)


func _test_precision(main: Node) -> void:
	GameManager.start_game("precision")
	assert(GameManager.get_current_mode_id() == "precision")
	assert(is_equal_approx(
		float(GameManager.get_current_stage_config()["timer_seconds"]), 1.3
	))
	var first_wave := GameManager.get_active_bomb_indices()
	assert(first_wave.size() == 1)
	var gameplay: Control = main.get_node("ScreenRoot/Gameplay")
	var precision_cell: BombCell = gameplay.get_node("%BombGrid").get_child(first_wave[0])
	var precision_material := precision_cell.bomb_image.material as ShaderMaterial
	assert(is_equal_approx(
		float(precision_material.get_shader_parameter("danger_progress")), 0.5
	))
	var precision_texture := precision_cell.bomb_image.texture as AtlasTexture
	assert(precision_texture.atlas.resource_path.ends_with("0030.png"))
	assert(gameplay.get_node("%ScoreLabel").text == "LEVEL  0")
	var game_over := main.get_node("OverlayRoot/GameOverScreen")
	game_over.set_scores(3, 7)
	assert(game_over.get_node("%ScoreCaption").text == "LEVEL")
	assert(game_over.get_node("%BestScoreCaption").text == "MAXIMUM LEVEL REACHED")
	assert(GameManager.handle_bomb_tapped(first_wave[0]))
	assert(GameManager.get_mode_phase_name() == "REST")
	assert(GameManager.get_active_bomb_indices().is_empty())
	GameManager._process(1.49)
	assert(GameManager.get_active_bomb_indices().is_empty())
	GameManager._process(0.02)
	assert(GameManager.get_mode_phase_name() == "ACTIVE")
	assert(GameManager.get_active_bomb_indices().size() == 1)
	GameManager.return_to_mode_select()


func _test_standard_multitouch_batch() -> void:
	GameManager.start_game("endless")
	GameManager.current_defusals = 10
	GameManager._sync_stage_to_progress()
	GameManager._build_initial_layout()
	var simultaneous_targets := GameManager.get_active_bomb_indices()
	assert(simultaneous_targets.size() == 2)
	var score_before := GameManager.current_score
	assert(GameManager.handle_bombs_tapped(simultaneous_targets) == 2)
	assert(GameManager.current_score == score_before + 2)
	GameManager.return_to_mode_select()


func _test_memory(main: Node) -> void:
	var gems_before := EconomyManager.get_gem_balance()
	GameManager.start_game("memory")
	var gameplay: Control = main.get_node("ScreenRoot/Gameplay")
	assert(GameManager.get_current_mode_id() == "memory")
	assert(GameManager.get_current_stage_config()["grid_side"] == 3)
	assert(GameManager.get_active_bomb_indices().size() == 4)
	assert(GameManager.get_mode_phase_name() == "PREVIEW")
	var preview_cell: BombCell = (
		main.get_node("ScreenRoot/Gameplay/%BombGrid").get_child(
			GameManager.get_active_bomb_indices()[0]
		)
	)
	var preview_texture := preview_cell.bomb_image.texture as AtlasTexture
	assert(preview_texture.atlas.resource_path.ends_with("0061.png"))
	assert(preview_cell.bomb_image.modulate == Color.WHITE)
	for target in GameManager.get_active_bomb_indices():
		assert(GameManager.get_bomb_timer_duration(target) == 0.0)
	assert(not GameManager.handle_bomb_tapped(GameManager.get_active_bomb_indices()[0]))

	GameManager._process(2.49)
	assert(GameManager.get_mode_phase_name() == "PREVIEW")
	GameManager._process(0.02)
	assert(GameManager.get_mode_phase_name() == "RECALL")
	await get_tree().process_frame
	var pattern := GameManager.get_active_bomb_indices()
	var first_target: int = pattern[0]
	for touch_index in 2:
		var touched_cell := gameplay.get_node("%BombGrid").get_child(
			pattern[touch_index]
		) as BombCell
		var touch_event := InputEventScreenTouch.new()
		touch_event.index = touch_index
		touch_event.pressed = true
		touch_event.position = touched_cell.get_global_rect().get_center()
		gameplay._input(touch_event)
	assert(gameplay._pending_touch_indices.size() == 2)
	gameplay._flush_touch_batch()
	assert(preview_cell._memory_state == "correct")
	var second_target_cell: BombCell = (
		main.get_node("ScreenRoot/Gameplay/%BombGrid").get_child(pattern[1])
	)
	assert(second_target_cell._memory_state == "correct")
	assert(GameManager.handle_bomb_tapped(first_target))
	assert(GameManager.current_score == 0)

	var wrong_index := -1
	for cell_index in 9:
		if not pattern.has(cell_index):
			wrong_index = cell_index
			break
	var lives_before := GameManager.current_lives
	assert(GameManager.handle_bomb_tapped(wrong_index))
	assert(GameManager.current_lives == lives_before - 1)
	assert(GameManager.get_mode_phase_name() == "RECALL")
	assert(preview_cell._memory_state == "correct")

	for target in pattern:
		assert(GameManager.handle_bomb_tapped(target))
	assert(GameManager.current_score == 1)
	assert(GameManager.get_mode_phase_name() == "INTERMISSION")
	assert(EconomyManager.get_gem_balance() > gems_before)
	assert(gameplay.get_node("%ScoreLabel").text == "LEVEL  1")
	assert(not gameplay.get_node("%ModePhaseLabel").visible)
	var game_over := main.get_node("OverlayRoot/GameOverScreen")
	game_over.set_scores(1, 4)
	assert(game_over.get_node("%ScoreCaption").text == "LEVEL")
	assert(game_over.get_node("%BestScoreCaption").text == "MAXIMUM LEVEL REACHED")
	for cell_index in 9:
		var memory_cell := gameplay.get_node("%BombGrid").get_child(cell_index) as BombCell
		assert(
			memory_cell._memory_state
			== ("correct" if pattern.has(cell_index) else "hidden")
		)

	GameManager._process(0.74)
	for target in pattern:
		var completed_cell := gameplay.get_node("%BombGrid").get_child(target) as BombCell
		assert(completed_cell._memory_state == "correct")
	GameManager._process(0.02)
	for cell in gameplay.get_node("%BombGrid").get_children():
		var memory_cell := cell as BombCell
		assert(memory_cell._memory_state == "hidden")
		var inactive_texture := memory_cell.bomb_image.texture as AtlasTexture
		assert(inactive_texture.atlas.resource_path.ends_with("0001.png"))

	GameManager._process(0.73)
	assert(GameManager.get_mode_phase_name() == "INTERMISSION")
	GameManager._process(0.02)
	assert(GameManager.get_mode_phase_name() == "PREVIEW")
	assert(GameManager.get_active_bomb_indices().size() == 4)
	for target in GameManager.get_active_bomb_indices():
		var next_preview_cell := gameplay.get_node("%BombGrid").get_child(target) as BombCell
		assert(next_preview_cell._memory_state == "preview")

	# Late Memory levels expand only this mode to 5x5, add more targets, and
	# retain a fair preview-time floor even after the progression curve saturates.
	GameManager.current_score = 24
	GameManager._begin_memory_pattern(false)
	assert(GameManager.get_current_stage_config()["grid_side"] == 5)
	assert(GameManager.get_active_bomb_indices().size() == 10)
	assert(is_equal_approx(GameManager.get_memory_preview_duration(), 1.8))
	assert(gameplay.get_node("%BombGrid").get_child_count() == 25)
	GameManager.return_to_mode_select()


func _apply_lifetime(lifetime_defusals: int) -> void:
	var snapshot := SaveData.new().to_dictionary(false)
	snapshot["lifetime_defusal_score"] = lifetime_defusals
	assert(SaveManager.apply_cloud_snapshot(snapshot))
