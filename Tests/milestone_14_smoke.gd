extends Node

## Headless coverage for typed mode data, save-v3 migration, the temporary
## all-modes unlock, selector navigation, independent records, and compatibility.

const MAIN_SCENE := preload("res://Scenes/Main.tscn")

var _rejections: Array[Dictionary] = []


func _ready() -> void:
	GameManager.mode_start_rejected.connect(
		func(mode_id: String, reason: String) -> void:
			_rejections.append({"mode_id": mode_id, "reason": reason})
	)
	_test_mode_catalog()
	_test_save_v3_migration()
	_test_temporary_unlock_override()
	assert(SaveManager.apply_cloud_snapshot(SaveData.new().to_dictionary(false)))

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await _test_selector_and_unlocked_start(main)
	await _test_mode_aware_run_contracts(main)
	await _test_independent_records_and_profile(main)
	await _test_endless_compatibility(main)
	print("Milestone 14 smoke test passed.")
	get_tree().quit()


func _test_mode_catalog() -> void:
	assert(GameManager.MODE_CATALOG.validate_catalog().is_empty())
	assert(
		GameManager.MODE_CATALOG.get_mode_ids()
		== ["endless", "zen", "memory", "time_attack", "precision", "hardcore"]
	)
	for definition in GameManager.get_mode_definitions():
		assert(definition is GameModeDefinition)
		assert(definition.is_valid())
		for stage in definition.stages:
			assert(stage is GameStageDefinition)


func _test_save_v3_migration() -> void:
	var migrated := SaveData.from_dictionary({
		"save_version": 2,
		"best_score": 37,
		"lifetime_defusal_score": 612,
	})
	assert(migrated.save_version == SaveData.CURRENT_VERSION)
	assert(migrated.best_score == 37)
	assert(migrated.best_scores_by_mode.size() == 6)
	assert(migrated.best_scores_by_mode["endless"] == 37)
	assert(migrated.best_scores_by_mode["zen"] == 0)
	assert(migrated.to_dictionary(false)["best_score"] == 37)

	var validated := SaveData.from_dictionary({
		"save_version": 3,
		"best_score": 4,
		"best_scores_by_mode": {
			"endless": 8,
			"zen": 12,
			"memory": -3,
			"time_attack": 7.9,
			"precision": "bad",
			"unknown_mode": 999,
		},
	})
	assert(validated.best_scores_by_mode["endless"] == 8)
	assert(validated.best_scores_by_mode["zen"] == 12)
	assert(validated.best_scores_by_mode["memory"] == 0)
	assert(validated.best_scores_by_mode["time_attack"] == 7)
	assert(validated.best_scores_by_mode["precision"] == 0)
	assert(not validated.best_scores_by_mode.has("unknown_mode"))


func _test_temporary_unlock_override() -> void:
	_apply_lifetime(0)
	for definition in GameManager.get_mode_definitions():
		assert(GameManager.is_mode_unlocked(definition.mode_id))
	assert(not GameManager.is_mode_unlocked("not_a_mode"))


func _test_selector_and_unlocked_start(main: Node) -> void:
	_apply_lifetime(0)
	GameManager.show_home_if_ready()
	main.get_node("ScreenRoot/HomeScreen").get_node("%PlayButton").pressed.emit()
	assert(GameManager.get_current_screen_name() == "mode_select")
	var selector: Control = main.get_node("ScreenRoot/ModeSelectScreen")
	assert(selector.visible)
	var presented: Dictionary = selector.get_presented_state()
	assert(presented["modes"].size() == 6)
	for mode_id in presented["modes"]:
		assert(presented["modes"][mode_id]["unlocked"])
		assert(presented["modes"][mode_id]["unlock"] == "AVAILABLE NOW")
	var endless_card: ModeCard = selector.get_node("%Cards").get_node("Mode_endless")
	var background_art: TextureRect = endless_card.get_node("%BackgroundArt")
	var unlock_progress: ProgressBar = endless_card.get_node("%UnlockProgress")
	assert(background_art.modulate.a >= 0.34)
	assert(
		background_art.get_global_rect().end.y
		<= unlock_progress.get_global_rect().position.y
	)

	var rejection_count := _rejections.size()
	GameManager.start_game("zen")
	assert(_rejections.size() == rejection_count)
	assert(GameManager.get_current_mode_id() == "zen")
	assert(GameManager.get_run_state_name() == "running")
	GameManager.return_to_mode_select()
	assert(GameManager.get_current_screen_name() == "mode_select")
	assert(GameManager.get_run_state_name() == "idle")

	selector.get_node("%BackButton").pressed.emit()
	assert(GameManager.get_current_screen_name() == "home")
	assert(main.get_node("ScreenRoot/HomeScreen").visible)


func _test_mode_aware_run_contracts(main: Node) -> void:
	_apply_lifetime(500)
	GameManager.show_mode_select_if_ready()
	var selector: Control = main.get_node("ScreenRoot/ModeSelectScreen")
	var zen_card: ModeCard = selector.get_node("%Cards").get_node("Mode_zen")
	zen_card.get_node("%PlayButton").pressed.emit()
	assert(GameManager.get_current_screen_name() == "gameplay")
	assert(GameManager.get_current_mode_id() == "zen")
	assert(GameManager.get_current_mode_definition().display_name == "Zen")
	assert(GameManager.get_maximum_lives() == 3)
	assert(GameManager.get_run_snapshot()["mode_id"] == "zen")
	GameManager.pause_game()
	main.get_node("OverlayRoot/PauseMenu").get_node("%QuitButton").pressed.emit()
	assert(GameManager.get_current_screen_name() == "mode_select")

	_apply_lifetime(1000)
	GameManager.start_game("hardcore")
	assert(GameManager.get_current_mode_id() == "hardcore")
	assert(GameManager.get_maximum_lives() == 1)
	assert(GameManager.current_lives == 1)
	assert(not GameManager.are_power_ups_enabled_for_run())
	assert(GameManager.get_run_snapshot()["maximum_lives"] == 1)
	GameManager.return_to_mode_select()

	GameManager.start_game("time_attack")
	assert(GameManager.get_current_mode_id() == "time_attack")
	assert(GameManager.get_maximum_lives() == 0)
	assert(GameManager.current_lives == 0)
	assert(GameManager.get_run_time_remaining() == 60.0)
	assert(not GameManager.get_run_snapshot()["has_life_system"])
	assert(not GameManager.can_offer_rewarded_revive())
	GameManager.return_to_mode_select()


func _test_independent_records_and_profile(main: Node) -> void:
	assert(SaveManager.apply_cloud_snapshot(SaveData.new().to_dictionary(false)))
	var expected := {
		"endless": 11,
		"zen": 22,
		"memory": 3,
		"time_attack": 44,
		"precision": 55,
		"hardcore": 66,
	}
	for mode_id in expected:
		assert(SaveManager.set_mode_best_score(mode_id, expected[mode_id]))
	assert(not SaveManager.set_mode_best_score("unknown_mode", 500))
	assert(SaveManager.get_best_score() == 11)
	assert(SaveManager.get_mode_best_scores() == expected)

	var cloud_round_trip := SaveManager.get_snapshot(false)
	assert(SaveManager.apply_cloud_snapshot(cloud_round_trip))
	assert(SaveManager.get_mode_best_scores() == expected)

	GameManager.return_to_home()
	assert(
		main.get_node("ScreenRoot/HomeScreen").get_node("%BestScoreValue").text
		== "11"
	)
	UIManager.show_profile()
	await get_tree().process_frame
	var profile: Control = main.get_node("ScreenRoot/ProfileScreen")
	var presented: Dictionary = profile.get_presented_state()
	for mode_id in expected:
		assert(presented["mode_records"][mode_id] == str(expected[mode_id]))


func _test_endless_compatibility(main: Node) -> void:
	_apply_lifetime(0)
	GameManager.start_game()
	assert(GameManager.get_current_mode_id() == "endless")
	assert(GameManager.get_maximum_lives() == GameManager.MAXIMUM_LIVES)
	assert(GameManager.are_power_ups_enabled_for_run())
	assert(GameManager.get_current_stage_config() == GameManager.STAGE_DEFINITIONS[0])
	assert(GameManager.get_run_snapshot()["mode_name"] == "Classic")

	GameManager.current_score = 19
	GameManager.finish_run()
	assert(SaveManager.get_best_score() == 19)
	assert(SaveManager.get_mode_best_score("endless") == 19)
	var game_over: Control = main.get_node("OverlayRoot/GameOverScreen")
	assert(game_over.get_node("%ModeLabel").text == "CLASSIC")
	game_over.get_node("%PlayAgainButton").pressed.emit()
	assert(GameManager.get_current_mode_id() == "endless")
	assert(GameManager.get_run_state_name() == "running")
	GameManager.return_to_mode_select()
	assert(GameManager.get_current_screen_name() == "mode_select")


func _apply_lifetime(value: int) -> void:
	var snapshot := SaveData.new().to_dictionary(false)
	snapshot["lifetime_defusal_score"] = value
	assert(SaveManager.apply_cloud_snapshot(snapshot))
