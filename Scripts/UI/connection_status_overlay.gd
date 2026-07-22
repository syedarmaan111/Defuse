extends Control

## ConnectionStatusOverlay reports live-run disconnects without interrupting play.

@onready var message_label: Label = %MessageLabel

var _dismiss_tween: Tween


func show_connection_lost() -> void:
	_stop_dismiss_tween()
	message_label.text = "CONNECTION LOST  •  THIS RUN CAN FINISH"
	visible = true
	modulate.a = 1.0


func show_connection_restored() -> void:
	_stop_dismiss_tween()
	message_label.text = "CONNECTION RESTORED"
	visible = true
	modulate.a = 1.0
	_dismiss_tween = create_tween()
	_dismiss_tween.tween_interval(2.0)
	_dismiss_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_dismiss_tween.tween_callback(func() -> void: visible = false)


func _stop_dismiss_tween() -> void:
	if _dismiss_tween != null and _dismiss_tween.is_valid():
		_dismiss_tween.kill()
