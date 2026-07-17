class_name AnimatedButton
extends Button

## Gives all shared buttons the same quiet press response without coupling them
## to a specific screen or navigation action.

@export var pressed_scale: float = 0.97
@export var hover_scale: float = 1.012

var _motion_tween: Tween
var _is_hovered := false


func _ready() -> void:
	resized.connect(_refresh_pivot)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_pivot()


func _refresh_pivot() -> void:
	## Keeps scale feedback centered so buttons never jump inside containers.
	pivot_offset = size * 0.5


func _animate_to(target_scale: float, duration: float) -> void:
	if _motion_tween and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "scale", Vector2.ONE * target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_button_down() -> void:
	if disabled:
		return
	_animate_to(pressed_scale, 0.07)


func _on_button_up() -> void:
	_animate_to(hover_scale if _is_hovered else 1.0, 0.12)


func _on_mouse_entered() -> void:
	_is_hovered = true
	if not button_pressed and not disabled:
		_animate_to(hover_scale, 0.12)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_animate_to(1.0, 0.12)
