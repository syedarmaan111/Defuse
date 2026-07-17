extends Control

## PauseMenu shows a real responsive dialog over blurred gameplay.
## Resume returns to gameplay, while Quit returns to Home.

@onready var resume_button: Button = %ResumeButton
@onready var quit_button: Button = %QuitButton
@onready var popup: Control = %Popup


func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	visibility_changed.connect(_animate_popup)


func _animate_popup() -> void:
	## Replays the shared modal entrance whenever this overlay becomes visible.
	if not visible:
		return
	popup.scale = Vector2.ONE * 0.94
	popup.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.16)


func _on_resume_pressed() -> void:
	GameManager.resume_game()


func _on_quit_pressed() -> void:
	GameManager.return_to_home()
