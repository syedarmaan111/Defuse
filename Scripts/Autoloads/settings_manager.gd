extends Node

## Owns the small validated settings surface. UI emits intent here; SaveManager
## persists changes and queues the same cloud synchronization as progression.

signal setting_changed(setting_id: String, value: Variant)
signal settings_changed(settings: Dictionary)

const SOUND_ENABLED := "sound_enabled"
const SOUND_VOLUME := "sound_volume"
const DEFAULTS := {
	SOUND_ENABLED: true,
	SOUND_VOLUME: 0.85,
}

var _settings: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	SaveManager.save_loaded.connect(_on_save_snapshot)
	SaveManager.save_changed.connect(_on_save_snapshot)
	_apply_snapshot(SaveManager.get_snapshot())


func is_sound_enabled() -> bool:
	return bool(_settings[SOUND_ENABLED])


func get_sound_volume() -> float:
	return float(_settings[SOUND_VOLUME])


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func set_sound_enabled(is_enabled: bool) -> bool:
	return _set_validated_setting(SOUND_ENABLED, is_enabled)


func set_sound_volume(volume: float) -> bool:
	return _set_validated_setting(SOUND_VOLUME, clampf(volume, 0.0, 1.0))


func _set_validated_setting(setting_id: String, value: Variant) -> bool:
	if _settings.get(setting_id) == value:
		return false
	# SaveManager emits the committed snapshot synchronously; _apply_snapshot
	# then updates this cache and emits exactly one set of settings signals.
	return SaveManager.set_setting(setting_id, value)


func _on_save_snapshot(snapshot: Dictionary) -> void:
	_apply_snapshot(snapshot)


func _apply_snapshot(snapshot: Dictionary) -> void:
	var source = snapshot.get("settings", {})
	if typeof(source) != TYPE_DICTIONARY:
		source = {}
	var next_settings := DEFAULTS.duplicate(true)
	if typeof(source.get(SOUND_ENABLED)) == TYPE_BOOL:
		next_settings[SOUND_ENABLED] = source[SOUND_ENABLED]
	var source_volume = source.get(SOUND_VOLUME)
	if typeof(source_volume) in [TYPE_INT, TYPE_FLOAT]:
		next_settings[SOUND_VOLUME] = clampf(float(source_volume), 0.0, 1.0)

	for setting_id in DEFAULTS:
		if _settings.get(setting_id) != next_settings[setting_id]:
			_settings[setting_id] = next_settings[setting_id]
			setting_changed.emit(setting_id, _settings[setting_id])
	settings_changed.emit(get_settings())
