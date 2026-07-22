extends Node

## CloudSaveManager owns Play Games authentication in Milestone 3.
## Snapshot restore, sync, and conflict resolution are added in Milestone 4.

signal cloud_sign_in_succeeded()
signal cloud_sign_in_failed(error_code: String)
signal cloud_restore_completed()
signal cloud_sync_completed()
signal cloud_sync_failed(error_code: String)
signal cloud_conflict_detected(local_summary: Dictionary, cloud_summary: Dictionary)

var _android_plugin: Object
var _is_signed_in := false
var _development_bypass := false
var _authentication_pending := false
var _authentication_required := false


func _ready() -> void:
	_authentication_required = bool(
		ProjectSettings.get_setting("defuse/play_games/require_sign_in", false)
	)
	_development_bypass = (
		OS.get_name() != "Android"
		and bool(ProjectSettings.get_setting("defuse/development/bypass_online_gate", true))
	)
	if _development_bypass:
		_is_signed_in = true
		call_deferred("_emit_development_sign_in")


func is_signed_in() -> bool:
	return _is_signed_in


func is_gate_satisfied() -> bool:
	return _development_bypass or not _authentication_required or _is_signed_in


func is_authentication_required() -> bool:
	return _authentication_required


func is_authentication_pending() -> bool:
	return _authentication_pending


func check_authentication() -> void:
	## Checks the SDK's automatic launch authentication result.
	if is_gate_satisfied() or _authentication_pending:
		return
	if not NetworkManager.can_start_game():
		cloud_sign_in_failed.emit("validated_internet_required")
		return
	if not _ensure_android_plugin():
		return
	_authentication_pending = true
	_android_plugin.isAuthenticated()


func sign_in() -> void:
	## Starts the Play Games profile prompt after automatic authentication failed.
	if is_gate_satisfied() or _authentication_pending:
		return
	if not NetworkManager.can_start_game():
		cloud_sign_in_failed.emit("validated_internet_required")
		return
	if not _ensure_android_plugin():
		return
	_authentication_pending = true
	_android_plugin.signIn()


func _ensure_android_plugin() -> bool:
	if _android_plugin != null:
		return true
	if not Engine.has_singleton("GodotPlayGameServices"):
		cloud_sign_in_failed.emit("plugin_unavailable")
		return false

	_android_plugin = Engine.get_singleton("GodotPlayGameServices")
	_android_plugin.initialize()
	_android_plugin.userAuthenticated.connect(_on_user_authenticated)
	return true


func _on_user_authenticated(authenticated: bool) -> void:
	_authentication_pending = false
	_is_signed_in = authenticated
	if authenticated:
		cloud_sign_in_succeeded.emit()
	else:
		cloud_sign_in_failed.emit("authentication_required")


func _emit_development_sign_in() -> void:
	cloud_sign_in_succeeded.emit()
