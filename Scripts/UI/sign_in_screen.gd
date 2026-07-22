extends Control

## SignInScreen presents the required Play Games authentication action.

@onready var sign_in_button: Button = %SignInButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	sign_in_button.pressed.connect(_on_sign_in_pressed)
	CloudSaveManager.cloud_sign_in_succeeded.connect(_on_sign_in_succeeded)
	CloudSaveManager.cloud_sign_in_failed.connect(_on_sign_in_failed)
	CloudSaveManager.cloud_restore_started.connect(show_restoring_progress)
	CloudSaveManager.cloud_sync_failed.connect(_on_cloud_sync_failed)
	status_label.text = "Checking your Play Games profile…"


func show_authentication_required() -> void:
	status_label.text = "Sign in is required to restore and protect progress"
	sign_in_button.text = "SIGN IN"
	sign_in_button.disabled = false


func show_restoring_progress() -> void:
	status_label.text = "Restoring your protected progress…"
	sign_in_button.text = "RESTORING…"
	sign_in_button.disabled = true


func show_error(message: String) -> void:
	status_label.text = message
	sign_in_button.disabled = false


func _on_sign_in_pressed() -> void:
	if CloudSaveManager.is_signed_in():
		show_restoring_progress()
		CloudSaveManager.restore_progress()
		return
	status_label.text = "Opening Play Games…"
	sign_in_button.disabled = true
	CloudSaveManager.sign_in()


func _on_sign_in_succeeded() -> void:
	status_label.text = "Signed in. Preparing cloud progress…"
	sign_in_button.disabled = true


func _on_sign_in_failed(error_code: String) -> void:
	match error_code:
		"authentication_required":
			show_authentication_required()
		"validated_internet_required":
			show_error("An internet connection is required before sign-in")
		"plugin_unavailable":
			show_error("Play Games is unavailable in this build")
		_:
			show_error("Sign-in failed. Please try again")


func _on_cloud_sync_failed(error_code: String) -> void:
	if error_code.begins_with("restore_") or error_code == "cloud_save_invalid":
		show_error("Cloud progress could not be restored. Please try again")
		sign_in_button.text = "RETRY RESTORE"
