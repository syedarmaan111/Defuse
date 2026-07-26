extends Control

## NetworkRequiredScreen explains the internet requirement and emits Retry.

@onready var retry_button: Button = %RetryButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	NetworkManager.wifi_connection_changed.connect(_refresh_status)
	NetworkManager.internet_availability_changed.connect(_refresh_status)
	NetworkManager.connection_check_finished.connect(_on_connection_check_finished)
	_refresh_status(false)


func _on_retry_pressed() -> void:
	status_label.text = "Checking connection…"
	retry_button.disabled = true
	NetworkManager.refresh_connection_state()


func _on_connection_check_finished(_is_available: bool) -> void:
	retry_button.disabled = false
	_refresh_status(false)


func _refresh_status(_state_changed: bool) -> void:
	if NetworkManager.can_start_game():
		status_label.text = "Internet connection detected"
	elif NetworkManager.is_wifi_connected():
		status_label.text = "Wi-Fi is connected, but internet access is unavailable"
	else:
		status_label.text = "Connect to Wi-Fi or cellular data to continue"
