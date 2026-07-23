extends Node

## Central playback service for the supplied bomb audio. One-shot effects may
## overlap, while tracked fuse sounds can be stopped when their bomb resolves.

signal sound_played(sound_name: String, playback_id: String)
signal sound_stopped(playback_id: String)
signal audio_settings_applied(is_enabled: bool, volume: float)

const SOUND_PATHS := {
	"bomb_armed": "res://Assets/Bomb/Audio/Bomb.wav",
	"bomb_defused": "res://Assets/Bomb/Audio/bomb pop.wav",
	"bomb_exploded": "res://Assets/Bomb/Audio/explode.wav"
}

var _tracked_players: Dictionary = {}


func _ready() -> void:
	SettingsManager.setting_changed.connect(_on_setting_changed)
	_apply_settings_to_tracked_players()


func has_sound(sound_name: String) -> bool:
	return SOUND_PATHS.has(sound_name)


func get_sound_path(sound_name: String) -> String:
	return str(SOUND_PATHS.get(sound_name, ""))


func play_sound(sound_name: String) -> bool:
	## Creates a disposable player so rapid effects never cut each other off.
	if not SettingsManager.is_sound_enabled():
		return false
	var stream := _load_sound(sound_name)
	if stream == null:
		return false
	if DisplayServer.get_name() == "headless":
		sound_played.emit(sound_name, "")
		return true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = _get_effect_volume_db()
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	sound_played.emit(sound_name, "")
	return true


func start_tracked_sound(sound_name: String, playback_id: String) -> bool:
	## Fuse audio is tied to a bomb ID and stops immediately on resolution.
	if playback_id.is_empty() or not SettingsManager.is_sound_enabled():
		return false
	var stream := _load_sound(sound_name)
	if stream == null:
		return false
	stop_tracked_sound(playback_id)
	if DisplayServer.get_name() == "headless":
		sound_played.emit(sound_name, playback_id)
		return true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = _get_effect_volume_db()
	add_child(player)
	_tracked_players[playback_id] = player
	player.play()
	sound_played.emit(sound_name, playback_id)
	return true


func stop_tracked_sound(playback_id: String) -> void:
	var player := _tracked_players.get(playback_id) as AudioStreamPlayer
	if player == null:
		return
	_tracked_players.erase(playback_id)
	player.stop()
	player.queue_free()
	sound_stopped.emit(playback_id)


func set_gameplay_audio_paused(is_paused: bool) -> void:
	for player_value in _tracked_players.values():
		var player := player_value as AudioStreamPlayer
		if player != null:
			player.stream_paused = is_paused


func get_tracked_playback_count() -> int:
	return _tracked_players.size()


func _load_sound(sound_name: String) -> AudioStream:
	if not has_sound(sound_name):
		return null
	return load(get_sound_path(sound_name)) as AudioStream


func _on_setting_changed(setting_id: String, _value: Variant) -> void:
	if setting_id not in [
		SettingsManager.SOUND_ENABLED,
		SettingsManager.SOUND_VOLUME,
	]:
		return
	_apply_settings_to_tracked_players()


func _apply_settings_to_tracked_players() -> void:
	var volume_db := _get_effect_volume_db()
	for player_value in _tracked_players.values():
		var player := player_value as AudioStreamPlayer
		if player != null:
			player.volume_db = volume_db
	audio_settings_applied.emit(
		SettingsManager.is_sound_enabled(),
		SettingsManager.get_sound_volume()
	)


func _get_effect_volume_db() -> float:
	if not SettingsManager.is_sound_enabled():
		return -80.0
	var volume := SettingsManager.get_sound_volume()
	return linear_to_db(volume) if volume > 0.0 else -80.0
