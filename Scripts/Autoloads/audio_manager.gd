extends Node

## Central playback service for the supplied bomb audio. One-shot effects may
## overlap, while tracked fuse sounds can be stopped when their bomb resolves.

signal sound_played(sound_name: String, playback_id: String)
signal sound_stopped(playback_id: String)

const SOUND_PATHS := {
	"bomb_armed": "res://Assets/Bomb/Audio/Bomb.wav",
	"bomb_defused": "res://Assets/Bomb/Audio/bomb pop.wav",
	"bomb_exploded": "res://Assets/Bomb/Audio/explode.wav"
}

var _tracked_players: Dictionary = {}


func has_sound(sound_name: String) -> bool:
	return SOUND_PATHS.has(sound_name)


func get_sound_path(sound_name: String) -> String:
	return str(SOUND_PATHS.get(sound_name, ""))


func play_sound(sound_name: String) -> bool:
	## Creates a disposable player so rapid effects never cut each other off.
	var stream := _load_sound(sound_name)
	if stream == null:
		return false
	if DisplayServer.get_name() == "headless":
		sound_played.emit(sound_name, "")
		return true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	sound_played.emit(sound_name, "")
	return true


func start_tracked_sound(sound_name: String, playback_id: String) -> bool:
	## Fuse audio is tied to a bomb ID and stops immediately on resolution.
	if playback_id.is_empty():
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
