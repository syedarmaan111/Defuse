extends Node

## Headless smoke coverage for Milestone 3 launch and live-run gating.


func _ready() -> void:
	# Android ships with the online gate enabled. Desktop/headless development
	# uses an explicit bypass that is ignored by Android exports.
	assert(NetworkManager.is_online_gate_enabled())
	assert(NetworkManager.is_development_bypass_active())
	NetworkManager._set_connection_state(false, false)
	assert(NetworkManager.can_start_game())
	GameManager.show_home_if_ready()
	assert(GameManager.get_current_screen_name() == "home")

	# Force production-like state so the desktop development bypass does not
	# conceal failures in the launch gate logic.
	NetworkManager._online_gate_enabled = true
	NetworkManager._development_bypass = false
	CloudSaveManager._development_bypass = false
	CloudSaveManager._authentication_required = true
	CloudSaveManager._is_signed_in = false
	NetworkManager._set_connection_state(false, false)
	GameManager.set_current_screen(GameManager.ScreenName.HOME)

	GameManager.start_game()
	assert(GameManager.get_current_screen_name() == "network_required")

	# A Wi-Fi transport without Android's internet capability remains gated.
	NetworkManager._set_connection_state(true, false)
	assert(not NetworkManager.can_start_game())

	# A platform bridge or permission failure must never bypass the online gate.
	NetworkManager._allow_when_check_unavailable("smoke_test_bridge_failure")
	assert(not NetworkManager.can_start_game())

	# Validated cellular internet is eligible.
	NetworkManager._set_connection_state(false, true)
	assert(NetworkManager.can_start_game())
	CloudSaveManager._authentication_required = false
	GameManager.show_home_if_ready()
	assert(GameManager.get_current_screen_name() == "home")

	# Play Games becomes a gate only after production credentials are configured.
	CloudSaveManager._authentication_required = true
	GameManager.show_home_if_ready()
	assert(GameManager.get_current_screen_name() == "sign_in")

	# Validated Wi-Fi remains eligible as well.
	NetworkManager._set_connection_state(true, true)
	assert(NetworkManager.can_start_game())

	CloudSaveManager._is_signed_in = true
	GameManager.show_home_if_ready()
	assert(GameManager.get_current_screen_name() == "home")

	GameManager.start_game()
	assert(GameManager.get_current_screen_name() == "gameplay")
	NetworkManager.set_gameplay_active(true)

	var connection_lost := [false]
	NetworkManager.gameplay_connection_lost.connect(
		func() -> void: connection_lost[0] = true,
		CONNECT_ONE_SHOT
	)
	NetworkManager._set_connection_state(false, false)
	assert(connection_lost[0])
	assert(GameManager.get_current_screen_name() == "gameplay")

	print("Milestone 3 smoke test passed.")
	get_tree().quit()
