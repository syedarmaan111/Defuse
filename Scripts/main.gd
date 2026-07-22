extends Node

## Main controls which top-level UI scene is visible.
## It exists because Home, Gameplay, Pause, and Game Over are separate screens
## that need one coordinator. Game rules stay out of this script.
## Godot calls this script when the main scene starts.

@onready var home_screen: Control = $ScreenRoot/HomeScreen
@onready var shop_screen: Control = $ScreenRoot/ShopScreen
@onready var profile_screen: Control = $ScreenRoot/ProfileScreen
@onready var gameplay_screen: Control = $ScreenRoot/Gameplay
@onready var network_required_screen: Control = $ScreenRoot/NetworkRequiredScreen
@onready var sign_in_screen: Control = $ScreenRoot/SignInScreen
@onready var pause_menu: Control = $OverlayRoot/PauseMenu
@onready var game_over_screen: Control = $OverlayRoot/GameOverScreen
@onready var connection_status_overlay: Control = $NotificationRoot/ConnectionStatusOverlay
@onready var save_conflict_dialog: Control = $NotificationRoot/SaveConflictDialog
@onready var exit_confirmation_dialog: Control = $NotificationRoot/ExitConfirmationDialog


func _ready() -> void:
	## Connects manager signals once the scene tree exists.
	## The first refresh applies internet and Play Games launch gates before Home.
	GameManager.screen_changed.connect(_on_screen_changed)
	UIManager.menu_screen_changed.connect(_on_menu_screen_changed)
	GameManager.game_over_requested.connect(_on_game_over_requested)
	NetworkManager.wifi_connection_changed.connect(_on_connection_state_changed)
	NetworkManager.internet_availability_changed.connect(_on_connection_state_changed)
	NetworkManager.gameplay_connection_lost.connect(connection_status_overlay.show_connection_lost)
	NetworkManager.gameplay_connection_restored.connect(connection_status_overlay.show_connection_restored)
	CloudSaveManager.cloud_sign_in_succeeded.connect(_on_cloud_sign_in_succeeded)
	CloudSaveManager.cloud_sign_in_failed.connect(_on_cloud_sign_in_failed)
	CloudSaveManager.cloud_restore_completed.connect(_on_cloud_restore_completed)
	CloudSaveManager.cloud_conflict_detected.connect(save_conflict_dialog.show_conflict)
	exit_confirmation_dialog.leave_confirmed.connect(_exit_application)
	_refresh_launch_gate()


func _notification(what: int) -> void:
	## Android sends this notification for the system navigation Back button.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_mobile_back()


func _handle_mobile_back() -> void:
	if not is_node_ready():
		return
	if exit_confirmation_dialog.visible:
		exit_confirmation_dialog.cancel()
		return
	if GameManager.get_current_screen_name() == "gameplay":
		GameManager.pause_game()
		return
	exit_confirmation_dialog.show_confirmation()


func _exit_application() -> void:
	get_tree().quit()


func _on_screen_changed(screen_name: String) -> void:
	## Shows one base screen and optional overlay based on GameManager state.
	## Pause and Game Over keep gameplay visible behind their popups.
	_refresh_menu_screens(screen_name == "home")
	gameplay_screen.visible = screen_name in ["gameplay", "pause", "game_over"]
	network_required_screen.visible = screen_name == "network_required"
	sign_in_screen.visible = screen_name == "sign_in"
	pause_menu.visible = screen_name == "pause"
	game_over_screen.visible = screen_name == "game_over"
	NetworkManager.set_gameplay_active(screen_name in ["gameplay", "pause"])
	if screen_name in ["home", "network_required", "sign_in"]:
		connection_status_overlay.visible = false
	if screen_name == "sign_in" and not CloudSaveManager.is_authentication_pending():
		if CloudSaveManager.is_signed_in() and not CloudSaveManager.is_restore_ready():
			CloudSaveManager.restore_progress()
		else:
			CloudSaveManager.check_authentication()


func _on_menu_screen_changed(_screen_name: String) -> void:
	## Menu navigation is visible only while the launch/gameplay state is Home.
	_refresh_menu_screens(GameManager.get_current_screen_name() == "home")


func _refresh_menu_screens(menu_is_visible: bool) -> void:
	var selected := UIManager.get_current_menu_screen_name()
	home_screen.visible = menu_is_visible and selected == "home"
	shop_screen.visible = menu_is_visible and selected == "shop"
	profile_screen.visible = menu_is_visible and selected == "profile"


func _on_game_over_requested(final_score: int, best_score: int) -> void:
	## Passes score text into the Game Over screen.
	## During this UI milestone these values are placeholders supplied by callers.
	game_over_screen.set_scores(final_score, best_score)


func _refresh_launch_gate() -> void:
	## Re-evaluates launch state without interrupting a run already in progress.
	var current_screen := GameManager.get_current_screen_name()
	if current_screen in ["gameplay", "pause", "game_over"]:
		_on_screen_changed(current_screen)
		return
	if (
		current_screen == "home"
		and NetworkManager.can_start_game()
		and CloudSaveManager.is_gate_satisfied()
		and CloudSaveManager.is_restore_ready()
	):
		# Connection refreshes should not kick a player out of Shop or Profile.
		_on_screen_changed(current_screen)
		return
	GameManager.show_home_if_ready()


func _on_connection_state_changed(_is_available: bool) -> void:
	_refresh_launch_gate()


func _on_cloud_sign_in_succeeded() -> void:
	if NetworkManager.can_start_game() and CloudSaveManager.is_restore_ready():
		GameManager.show_home_if_ready()


func _on_cloud_restore_completed() -> void:
	if NetworkManager.can_start_game():
		GameManager.show_home_if_ready()


func _on_cloud_sign_in_failed(error_code: String) -> void:
	if GameManager.get_current_screen_name() != "sign_in":
		return
	if error_code == "authentication_required":
		sign_in_screen.show_authentication_required()
