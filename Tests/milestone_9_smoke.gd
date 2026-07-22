extends Node

## Headless coverage for independent timers, guarded defusal/explosion rules,
## armed presentation, audio requests, and localized replacement behavior.

const GAMEPLAY_SCENE := preload("res://Scenes/Gameplay/Gameplay.tscn")

var _defused_indices: Array[int] = []
var _explosions: Array[Dictionary] = []
var _played_sounds: Array[String] = []


func _ready() -> void:
	_seed_progression()
	GameManager.bomb_defused.connect(
		func(bomb_index: int) -> void: _defused_indices.append(bomb_index)
	)
	GameManager.bomb_exploded.connect(
		func(bomb_index: int, reason: String) -> void:
			_explosions.append({"index": bomb_index, "reason": reason})
	)
	AudioManager.sound_played.connect(
		func(sound_name: String, _playback_id: String) -> void:
			_played_sounds.append(sound_name)
	)

	var gameplay := GAMEPLAY_SCENE.instantiate()
	add_child(gameplay)
	await get_tree().process_frame
	_test_initial_timers_and_pause(gameplay)
	_test_defusal_and_stage_presentation(gameplay)
	_test_localized_timeout_and_independent_timer(gameplay)
	_test_inactive_tap_guard(gameplay)
	print("Milestone 9 smoke test passed.")
	get_tree().quit()


func _seed_progression() -> void:
	assert(SaveManager.apply_cloud_snapshot(SaveData.new().to_dictionary(false)))


func _test_initial_timers_and_pause(gameplay: Control) -> void:
	GameManager.start_game()
	var active_index: int = GameManager.get_active_bomb_indices()[0]
	assert(is_equal_approx(GameManager.get_bomb_timer_duration(active_index), 2.6))
	assert(GameManager.get_bomb_time_remaining(active_index) > 2.5)
	assert(_played_sounds.has("bomb_armed"))
	assert(gameplay.get_node_or_null("%StagePopup") == null)

	GameManager._process(0.5)
	var cell: BombCell = gameplay.get_node("%BombGrid").get_child(active_index)
	assert(cell.timer_ratio < 1.0 and cell.timer_ratio > 0.8)
	assert(cell.bomb_image.texture is AtlasTexture)
	var cleanup_material := cell.bomb_image.material as ShaderMaterial
	assert(float(cleanup_material.get_shader_parameter("danger_progress")) > 0.1)

	GameManager.pause_game()
	var paused_remaining := GameManager.get_bomb_time_remaining(active_index)
	GameManager._process(1.0)
	assert(is_equal_approx(GameManager.get_bomb_time_remaining(active_index), paused_remaining))
	GameManager.resume_game()


func _test_defusal_and_stage_presentation(gameplay: Control) -> void:
	var resolved_index: int = GameManager.get_active_bomb_indices()[0]
	assert(GameManager.handle_bomb_tapped(resolved_index))
	assert(_defused_indices.has(resolved_index))
	assert(_played_sounds.has("bomb_defused"))
	assert(GameManager.current_score == 1)
	assert(GameManager.current_lives == 3)
	assert(not GameManager.get_active_bomb_indices().has(resolved_index))
	var resolved_cell: BombCell = gameplay.get_node("%BombGrid").get_child(resolved_index)
	assert(resolved_cell._effect_tween != null)
	# The resolution guard prevents a fast second tap becoming an accidental
	# inactive-bomb penalty.
	assert(not GameManager.handle_bomb_tapped(resolved_index))
	assert(GameManager.current_lives == 3)

	_score_to(10)
	assert(int(GameManager.get_current_stage_config()["stage"]) == 2)
	assert(GameManager.get_active_bomb_indices().size() == 2)
	assert(gameplay.get_node_or_null("%StagePopup") == null)


func _test_localized_timeout_and_independent_timer(gameplay: Control) -> void:
	var previous_wave := GameManager.get_active_bomb_indices()
	var expiring_index: int = previous_wave[0]
	var surviving_index: int = previous_wave[1]
	GameManager._bomb_time_remaining[expiring_index] = 0.01
	GameManager._bomb_time_remaining[surviving_index] = 2.0
	GameManager._process(0.02)

	assert(GameManager.current_lives == 2)
	assert(_has_explosion(expiring_index, "timer_expired"))
	assert(_played_sounds.has("bomb_exploded"))
	assert(GameManager.get_active_bomb_indices().has(surviving_index))
	assert(not GameManager.get_active_bomb_indices().has(expiring_index))
	assert(GameManager.get_active_bomb_indices().size() == 2)
	assert(is_equal_approx(GameManager.get_bomb_time_remaining(surviving_index), 1.98))
	var exploded_cell: BombCell = gameplay.get_node("%BombGrid").get_child(expiring_index)
	assert(exploded_cell._effect_tween != null)


func _test_inactive_tap_guard(gameplay: Control) -> void:
	var inactive_index := _find_available_inactive_index()
	assert(inactive_index >= 0)
	assert(GameManager.handle_bomb_tapped(inactive_index))
	assert(GameManager.current_lives == 1)
	assert(_has_explosion(inactive_index, "inactive_tap"))
	assert(not GameManager.handle_bomb_tapped(inactive_index))
	assert(GameManager.current_lives == 1)
	# A wrong tap is local: active neighbors and score are unchanged.
	assert(GameManager.get_active_bomb_indices().size() == 2)
	assert(GameManager.current_score == 10)


func _score_to(target_score: int) -> void:
	while GameManager.current_score < target_score:
		var active_indices := GameManager.get_active_bomb_indices()
		assert(not active_indices.is_empty())
		assert(GameManager.handle_bomb_tapped(active_indices[0]))


func _find_available_inactive_index() -> int:
	var grid_side := int(GameManager.get_current_stage_config()["grid_side"])
	for bomb_index in grid_side * grid_side:
		if (
			not GameManager.get_active_bomb_indices().has(bomb_index)
			and not GameManager._resolution_cooldowns.has(bomb_index)
		):
			return bomb_index
	return -1


func _has_explosion(bomb_index: int, reason: String) -> bool:
	for event in _explosions:
		if int(event["index"]) == bomb_index and str(event["reason"]) == reason:
			return true
	return false
