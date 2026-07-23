extends Control

## SettingsScreen renders persisted preferences and forwards user intent to
## SettingsManager. It never writes save data or audio players directly.

@onready var back_button: Button = %BackButton
@onready var sound_toggle: CheckButton = %SoundToggle
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var preview_button: Button = %PreviewButton

var _is_refreshing := false


func _ready() -> void:
	back_button.pressed.connect(UIManager.show_profile)
	sound_toggle.toggled.connect(_on_sound_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	preview_button.pressed.connect(_on_preview_pressed)
	SettingsManager.settings_changed.connect(_on_settings_changed)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_controls()


func get_presented_state() -> Dictionary:
	## Stable headless snapshot used by Milestone 13 regression coverage.
	return {
		"sound_enabled": sound_toggle.button_pressed,
		"sound_volume": volume_slider.value / 100.0,
		"volume_text": volume_value.text,
		"preview_available": not preview_button.disabled,
	}


func _on_sound_toggled(is_enabled: bool) -> void:
	if _is_refreshing:
		return
	SettingsManager.set_sound_enabled(is_enabled)


func _on_volume_changed(value: float) -> void:
	if _is_refreshing:
		return
	SettingsManager.set_sound_volume(value / 100.0)


func _on_preview_pressed() -> void:
	AudioManager.play_sound("bomb_defused")


func _on_settings_changed(_settings: Dictionary) -> void:
	_refresh_controls()


func _on_visibility_changed() -> void:
	if visible and is_node_ready():
		_refresh_controls()


func _refresh_controls() -> void:
	_is_refreshing = true
	var is_enabled := SettingsManager.is_sound_enabled()
	var volume_percent := roundi(SettingsManager.get_sound_volume() * 100.0)
	sound_toggle.button_pressed = is_enabled
	sound_toggle.text = "ON" if is_enabled else "OFF"
	volume_slider.value = volume_percent
	volume_slider.editable = is_enabled
	volume_value.text = "%d%%" % volume_percent
	preview_button.disabled = not is_enabled or volume_percent <= 0
	_is_refreshing = false
