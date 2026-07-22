extends Control

## Blocks the app UI until the player confirms or cancels a mobile-back exit.

signal leave_confirmed

@onready var popup: Control = %Popup
@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton


func _ready() -> void:
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(cancel)
	visible = false


func show_confirmation() -> void:
	visible = true
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2.ONE * 0.94
	popup.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.16)


func cancel() -> void:
	visible = false


func _on_yes_pressed() -> void:
	leave_confirmed.emit()

