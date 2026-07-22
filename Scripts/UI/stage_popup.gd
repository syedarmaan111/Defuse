extends Control
class_name StagePopup

## Brief, non-interactive stage announcement. It replaces persistent debug text
## without obscuring gameplay controls longer than the transition moment.

@onready var panel: PanelContainer = %Panel
@onready var stage_label: Label = %StageLabel

var _animation: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	panel.resized.connect(_refresh_pivot)


func show_stage(stage_number: int) -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	stage_label.text = "STAGE %d" % max(stage_number, 1)
	visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.84
	call_deferred("_refresh_pivot")
	_animation = create_tween()
	_animation.tween_property(panel, "modulate:a", 1.0, 0.14)
	_animation.parallel().tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_animation.tween_interval(0.58)
	_animation.tween_property(panel, "modulate:a", 0.0, 0.2)
	_animation.tween_callback(hide)


func _refresh_pivot() -> void:
	panel.pivot_offset = panel.size * 0.5
