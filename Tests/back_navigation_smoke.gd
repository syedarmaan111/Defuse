extends Node

const MAIN_SCENE := preload("res://Scenes/Main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame

	GameManager.set_current_screen(GameManager.ScreenName.HOME)
	main._handle_mobile_back()
	var exit_dialog: Control = main.get_node("NotificationRoot/ExitConfirmationDialog")
	assert(exit_dialog.visible)
	assert(exit_dialog.get_node("%Question").text == "Do you want to leave the application?")
	exit_dialog.get_node("%NoButton").pressed.emit()
	assert(not exit_dialog.visible)
	assert(GameManager.get_current_screen_name() == "home")

	GameManager.start_game()
	GameManager._finish_countdown()
	var active_index: int = GameManager.get_active_bomb_indices()[0]
	var timer_before_background := GameManager.get_bomb_time_remaining(active_index)
	main._notification(NOTIFICATION_APPLICATION_PAUSED)
	assert(GameManager.get_current_screen_name() == "pause")
	assert(GameManager.get_run_state_name() == "paused")
	GameManager._process(1.0)
	assert(is_equal_approx(
		GameManager.get_bomb_time_remaining(active_index), timer_before_background
	))

	GameManager.resume_game()
	GameManager._finish_countdown()
	main._handle_mobile_back()
	assert(GameManager.get_current_screen_name() == "pause")
	assert(main.get_node("OverlayRoot/PauseMenu").visible)
	assert(not exit_dialog.visible)

	main._handle_mobile_back()
	assert(exit_dialog.visible)
	main._handle_mobile_back()
	assert(not exit_dialog.visible)
	assert(GameManager.get_current_screen_name() == "pause")

	print("Back navigation smoke test passed.")
	get_tree().quit()
