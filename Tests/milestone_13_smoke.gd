extends Node

## Headless coverage for persisted audio settings, banner reservations, atomic
## fourth-run interstitial cadence, offline deferral, and failure-safe play.

const MAIN_SCENE := preload("res://Scenes/Main.tscn")

var _interstitial_requests := 0
var _interstitial_failures := 0
var _interstitial_impressions := 0


func _ready() -> void:
	assert(SaveManager.apply_cloud_snapshot(SaveData.new().to_dictionary(false)))
	AdManager.interstitial_requested.connect(
		func() -> void: _interstitial_requests += 1
	)
	AdManager.interstitial_failed.connect(
		func(_error_code: String) -> void: _interstitial_failures += 1
	)
	AdManager.ad_impression_recorded.connect(
		func(format_name: String) -> void:
			if format_name == "interstitial":
				_interstitial_impressions += 1
	)

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await _test_settings_and_audio(main)
	_test_banner_reservations(main)

	# Keep the cadence test independent from settings-related save revisions.
	assert(SaveManager.apply_cloud_snapshot(SaveData.new().to_dictionary(false)))
	await _test_interstitial_cadence_and_offline_deferral()
	await _test_interstitial_failure_never_traps_play()
	print("Milestone 13 smoke test passed.")
	get_tree().quit()


func _test_settings_and_audio(main: Node) -> void:
	UIManager.show_settings()
	await get_tree().process_frame
	var settings_screen: Control = main.get_node("ScreenRoot/SettingsScreen")
	assert(settings_screen.visible)

	var sound_toggle: CheckButton = settings_screen.get_node("%SoundToggle")
	sound_toggle.set_pressed_no_signal(false)
	sound_toggle.toggled.emit(false)
	var volume_slider: HSlider = settings_screen.get_node("%VolumeSlider")
	volume_slider.set_value_no_signal(40.0)
	volume_slider.value_changed.emit(40.0)

	var snapshot := SaveManager.get_snapshot()
	assert(snapshot["settings"]["sound_enabled"] == false)
	assert(is_equal_approx(float(snapshot["settings"]["sound_volume"]), 0.4))
	assert(not AudioManager.play_sound("bomb_defused"))
	var rendered: Dictionary = settings_screen.get_presented_state()
	assert(not rendered["sound_enabled"])
	assert(rendered["volume_text"] == "40%")
	assert(not rendered["preview_available"])

	# Applying the same record models a local/cloud restore and must immediately
	# rehydrate both the manager and the signal-driven controls.
	assert(SaveManager.apply_cloud_snapshot(snapshot))
	await get_tree().process_frame
	assert(not SettingsManager.is_sound_enabled())
	assert(is_equal_approx(SettingsManager.get_sound_volume(), 0.4))

	assert(SettingsManager.set_sound_enabled(true))
	assert(AudioManager.play_sound("bomb_defused"))
	rendered = settings_screen.get_presented_state()
	assert(rendered["sound_enabled"])
	assert(rendered["preview_available"])
	settings_screen.get_node("%BackButton").pressed.emit()
	assert(UIManager.get_current_menu_screen_name() == "profile")


func _test_banner_reservations(main: Node) -> void:
	var home_banner: Control = main.get_node(
		"ScreenRoot/HomeScreen/SafeMargins/Content/BannerAdSlot"
	)
	var gameplay_banner: Control = main.get_node(
		"ScreenRoot/Gameplay/SafeMargins/Content/BannerAdSlot"
	)
	assert(home_banner.custom_minimum_size.y >= 100.0)
	assert(gameplay_banner.custom_minimum_size.y >= 100.0)
	assert(home_banner.get_parent() is Container)
	assert(gameplay_banner.get_parent() is Container)


func _test_interstitial_cadence_and_offline_deferral() -> void:
	AdManager._simulation_enabled = true
	NetworkManager._online_gate_enabled = true
	NetworkManager._development_bypass = false
	NetworkManager._set_connection_state(true, true)

	for run_number in range(1, 4):
		GameManager.start_game()
		assert(GameManager.get_run_state_name() == "running")
		GameManager.finish_run()
		assert(SaveManager.get_completed_run_count() == run_number)
		assert(not SaveManager.has_pending_interstitial())

	GameManager.start_game()
	assert(GameManager.get_run_state_name() == "running")
	NetworkManager._set_connection_state(false, false)
	GameManager.finish_run()
	assert(SaveManager.get_completed_run_count() == 4)
	assert(SaveManager.has_pending_interstitial())
	assert(_interstitial_requests == 0)
	assert(_interstitial_impressions == 0)

	NetworkManager._set_connection_state(true, true)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(_interstitial_requests == 1)
	assert(_interstitial_impressions == 1)
	assert(not SaveManager.has_pending_interstitial())


func _test_interstitial_failure_never_traps_play() -> void:
	for expected_count in range(5, 8):
		GameManager.start_game()
		GameManager.finish_run()
		assert(SaveManager.get_completed_run_count() == expected_count)

	# No native singleton is installed yet. A release-style request therefore
	# produces one no-fill failure, consumes the pending flag, and permits play.
	AdManager._simulation_enabled = false
	GameManager.start_game()
	GameManager.finish_run()
	assert(SaveManager.get_completed_run_count() == 8)
	await get_tree().process_frame
	assert(_interstitial_requests == 2)
	assert(_interstitial_failures == 1)
	assert(_interstitial_impressions == 1)
	assert(not SaveManager.has_pending_interstitial())

	GameManager.start_game()
	assert(GameManager.get_run_state_name() == "running")
