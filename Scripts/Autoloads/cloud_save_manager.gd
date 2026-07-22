extends Node

## CloudSaveManager coordinates Play Games authentication and Saved Games.
## It never mutates progression directly; SaveManager validates every snapshot.

signal cloud_sign_in_succeeded()
signal cloud_sign_in_failed(error_code: String)
signal cloud_restore_started()
signal cloud_restore_completed()
signal cloud_sync_completed()
signal cloud_sync_failed(error_code: String)
signal cloud_conflict_detected(local_summary: Dictionary, cloud_summary: Dictionary)
signal cloud_conflict_resolved(source: String)

const SNAPSHOT_NAME := "defuse_progress"
const SOURCE_LOCAL := "local"
const SOURCE_CLOUD := "cloud"

var _android_plugin: Object
var _snapshot_client: PlayGamesSnapshotsClient
var _is_signed_in := false
var _development_bypass := false
var _authentication_pending := false
var _authentication_required := false
var _restore_pending := false
var _restore_completed := false
var _sync_pending := false
var _sync_in_flight := false
var _uploaded_revision := -1
var _conflict_local: Dictionary = {}
var _conflict_cloud: Dictionary = {}


func _ready() -> void:
	_authentication_required = bool(
		ProjectSettings.get_setting("defuse/play_games/require_sign_in", false)
	)
	_development_bypass = (
		OS.get_name() != "Android"
		and bool(ProjectSettings.get_setting("defuse/development/bypass_online_gate", true))
	)
	NetworkManager.internet_availability_changed.connect(_on_internet_availability_changed)

	# Optional sign-in and desktop development use the validated local cache.
	# Production-required sign-in completes restore before Home is unlocked.
	if _development_bypass:
		_is_signed_in = true
		_restore_completed = true
		call_deferred("_emit_development_ready")
	elif not _authentication_required:
		_restore_completed = true


func is_signed_in() -> bool:
	return _is_signed_in


func is_gate_satisfied() -> bool:
	return _development_bypass or not _authentication_required or _is_signed_in


func is_restore_ready() -> bool:
	return _restore_completed and _conflict_local.is_empty()


func is_restore_pending() -> bool:
	return _restore_pending


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


func restore_progress() -> void:
	## Loads the single Saved Games slot before production Home is shown.
	if _restore_completed or _restore_pending or not _conflict_local.is_empty():
		return
	if not _is_signed_in:
		cloud_sync_failed.emit("restore_requires_sign_in")
		return
	if not NetworkManager.can_start_game():
		cloud_sync_failed.emit("restore_requires_internet")
		return
	if _development_bypass:
		_finish_restore()
		return
	if not _ensure_snapshot_client():
		return
	_restore_pending = true
	cloud_restore_started.emit()
	_snapshot_client.load_game(SNAPSHOT_NAME, false)


func queue_sync() -> void:
	## Records pending work in SaveManager so it survives app restarts.
	_sync_pending = true
	if is_restore_ready() and _can_use_cloud():
		call_deferred("sync_now")


func sync_now() -> void:
	## Uploads one immutable revision. Later local edits remain queued separately.
	_sync_pending = _sync_pending or SaveManager.is_cloud_sync_pending()
	if not _sync_pending or _sync_in_flight or not is_restore_ready():
		return
	if not _can_use_cloud():
		return
	if not _ensure_snapshot_client():
		return

	var snapshot := SaveManager.get_snapshot(false)
	_uploaded_revision = int(snapshot.get("save_revision", 0))
	_sync_in_flight = true
	_snapshot_client.save_game(
		SNAPSHOT_NAME,
		"DEFUSE progression revision %d" % _uploaded_revision,
		SaveManager.get_cloud_bytes(),
		0,
		int(snapshot.get("lifetime_defusal_score", 0))
	)


func resolve_conflict(source: String) -> bool:
	## Applies exactly the branch the player selected, then resumes launch/sync.
	if _conflict_local.is_empty() or _conflict_cloud.is_empty():
		return false
	var did_apply := false
	if source == SOURCE_CLOUD:
		did_apply = SaveManager.apply_cloud_snapshot(_conflict_cloud)
	elif source == SOURCE_LOCAL:
		did_apply = SaveManager.replace_with_local_snapshot(_conflict_local)
	else:
		return false

	if not did_apply:
		cloud_sync_failed.emit("conflict_apply_failed")
		return false
	_conflict_local.clear()
	_conflict_cloud.clear()
	cloud_conflict_resolved.emit(source)
	_finish_restore()
	if source == SOURCE_LOCAL:
		queue_sync()
	return true


func determine_reconciliation(local_save: Dictionary, cloud_save: Dictionary) -> String:
	## Returns local/cloud/equal/conflict using both lineage fields. A revision
	## paired with an older timestamp is contradictory and therefore ambiguous.
	var local_data := SaveData.from_dictionary(local_save).to_dictionary(false)
	var cloud_data := SaveData.from_dictionary(cloud_save).to_dictionary(false)
	if local_data == cloud_data:
		return "equal"

	var local_revision := int(local_data.get("save_revision", 0))
	var cloud_revision := int(cloud_data.get("save_revision", 0))
	var local_modified := int(local_data.get("modified_at_unix", 0))
	var cloud_modified := int(cloud_data.get("modified_at_unix", 0))

	if local_revision > cloud_revision and local_modified >= cloud_modified:
		return SOURCE_LOCAL
	if cloud_revision > local_revision and cloud_modified >= local_modified:
		return SOURCE_CLOUD
	return "conflict"


func reconcile_loaded_dictionary(cloud_dictionary: Dictionary) -> void:
	## Public for deterministic smoke coverage; normal calls come from snapshots.
	if cloud_dictionary.is_empty():
		_finish_restore()
		queue_sync()
		return
	if not SaveManager.has_persisted_save():
		SaveManager.apply_cloud_snapshot(cloud_dictionary)
		_finish_restore()
		return

	var local_dictionary := SaveManager.get_snapshot(false)
	match determine_reconciliation(local_dictionary, cloud_dictionary):
		"equal":
			SaveManager.apply_cloud_snapshot(cloud_dictionary)
			_finish_restore()
		SOURCE_CLOUD:
			SaveManager.apply_cloud_snapshot(cloud_dictionary)
			_finish_restore()
		SOURCE_LOCAL:
			_finish_restore()
			queue_sync()
		_:
			_present_conflict(local_dictionary, cloud_dictionary)


func _ensure_android_plugin() -> bool:
	if _android_plugin != null:
		return true
	if not Engine.has_singleton("GodotPlayGameServices"):
		cloud_sign_in_failed.emit("plugin_unavailable")
		return false

	GodotPlayGameServices.initialize()
	_android_plugin = GodotPlayGameServices.android_plugin
	if _android_plugin == null:
		cloud_sign_in_failed.emit("plugin_unavailable")
		return false
	_android_plugin.userAuthenticated.connect(_on_user_authenticated)
	return true


func _ensure_snapshot_client() -> bool:
	if _snapshot_client != null:
		return true
	if not _ensure_android_plugin():
		cloud_sync_failed.emit("snapshot_plugin_unavailable")
		return false
	_snapshot_client = PlayGamesSnapshotsClient.new()
	add_child(_snapshot_client)
	_snapshot_client.game_loaded.connect(_on_game_loaded)
	_snapshot_client.game_saved.connect(_on_game_saved)
	_snapshot_client.conflict_emitted.connect(_on_snapshot_conflict)
	return true


func _on_user_authenticated(authenticated: bool) -> void:
	_authentication_pending = false
	_is_signed_in = authenticated
	if authenticated:
		_restore_completed = false
		cloud_sign_in_succeeded.emit()
		restore_progress()
	else:
		cloud_sign_in_failed.emit("authentication_required")


func _on_game_loaded(snapshot: PlayGamesSnapshot) -> void:
	_restore_pending = false
	if snapshot == null:
		reconcile_loaded_dictionary({})
		return
	var cloud_dictionary := SaveManager.decode_cloud_bytes(snapshot.content)
	if cloud_dictionary.is_empty():
		cloud_sync_failed.emit("cloud_save_invalid")
		return
	reconcile_loaded_dictionary(cloud_dictionary)


func _on_game_saved(is_saved: bool, _save_name: String, _description: String) -> void:
	_sync_in_flight = false
	if not is_saved:
		_sync_pending = true
		cloud_sync_failed.emit("snapshot_save_failed")
		return

	SaveManager.mark_cloud_sync_complete(_uploaded_revision)
	_sync_pending = SaveManager.is_cloud_sync_pending()
	cloud_sync_completed.emit()
	if _sync_pending:
		call_deferred("sync_now")


func _on_snapshot_conflict(conflict: PlayGamesSnapshotConflict) -> void:
	## The plugin may surface an SDK-level conflict despite its automatic policy.
	_restore_pending = false
	_sync_in_flight = false
	var cloud_dictionary: Dictionary = {}
	if conflict != null and conflict.server_snapshot != null:
		cloud_dictionary = SaveManager.decode_cloud_bytes(conflict.server_snapshot.content)
	if cloud_dictionary.is_empty() and conflict != null and conflict.conflicting_snapshot != null:
		cloud_dictionary = SaveManager.decode_cloud_bytes(conflict.conflicting_snapshot.content)
	if cloud_dictionary.is_empty():
		cloud_sync_failed.emit("cloud_conflict_invalid")
		return
	_present_conflict(SaveManager.get_snapshot(false), cloud_dictionary)


func _present_conflict(local_dictionary: Dictionary, cloud_dictionary: Dictionary) -> void:
	_conflict_local = local_dictionary.duplicate(true)
	_conflict_cloud = cloud_dictionary.duplicate(true)
	cloud_conflict_detected.emit(
		_make_summary(_conflict_local),
		_make_summary(_conflict_cloud)
	)


func _make_summary(snapshot: Dictionary) -> Dictionary:
	var data := SaveData.from_dictionary(snapshot)
	return {
		"save_revision": data.save_revision,
		"modified_at_unix": data.modified_at_unix,
		"best_score": data.best_score,
		"lifetime_defusal_score": data.lifetime_defusal_score,
		"gems": int(data.currencies.get("gems", 0)),
	}


func _finish_restore() -> void:
	_restore_pending = false
	_restore_completed = true
	cloud_restore_completed.emit()


func _can_use_cloud() -> bool:
	return (
		_is_signed_in
		and not _development_bypass
		and NetworkManager.can_start_game()
	)


func _on_internet_availability_changed(is_available: bool) -> void:
	if is_available and (_sync_pending or SaveManager.is_cloud_sync_pending()):
		call_deferred("sync_now")


func _emit_development_ready() -> void:
	cloud_sign_in_succeeded.emit()
	cloud_restore_completed.emit()
