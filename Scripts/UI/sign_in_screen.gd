extends Control

## SignInScreen presents the required Play Games authentication action.

@onready var sign_in_button: Button = %SignInButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	sign_in_button.pressed.connect(_on_sign_in_pressed)
	CloudSaveManager.cloud_sign_in_succeeded.connect(_on_sign_in_succeeded)
	CloudSaveManager.cloud_sign_in_failed.connect(_on_sign_in_failed)
	status_label.text = "Checking your Play Games profile…"


func show_authentication_required() -> void:
	status_label.text = "Sign in is required to restore and protect progress"
	sign_in_button.disabled = false


func show_error(message: String) -> void:
	status_label.text = message
	sign_in_button.disabled = false


func _on_sign_in_pressed() -> void:
	status_label.text = "Opening Play Games…"
	sign_in_button.disabled = true
	CloudSaveManager.sign_in()


func _on_sign_in_succeeded() -> void:
	status_label.text = "Signed in"
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
