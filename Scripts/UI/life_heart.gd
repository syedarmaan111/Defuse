extends Control
class_name LifeHeart

## Draws a life icon with Godot canvas primitives so Android rendering never
## depends on an emoji/symbol font being available on the device.

@export var filled := true:
	set(value):
		filled = value
		queue_redraw()

@export var fill_color := Color(0.76, 0.22, 0.2, 1.0)
@export var empty_color := Color(0.72, 0.68, 0.63, 0.32)
@export var outline_color := Color(0.31, 0.13, 0.12, 0.92)

var _restore_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(54.0, 48.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	resized.connect(_refresh_pivot)
	queue_redraw()
	call_deferred("_refresh_pivot")


func play_restore() -> void:
	filled = true
	if _restore_tween != null and _restore_tween.is_valid():
		_restore_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 0.2
	modulate = Color(0.45, 1.0, 0.58, 0.25)
	_restore_tween = create_tween().set_parallel(true)
	_restore_tween.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_restore_tween.tween_property(self, "modulate", Color.WHITE, 0.34)


func _refresh_pivot() -> void:
	pivot_offset = size * 0.5


func _draw() -> void:
	var heart_points := _build_heart_points(Vector2.ZERO)
	var shadow_points := _build_heart_points(Vector2(0.0, 3.0))
	draw_colored_polygon(shadow_points, Color(0.08, 0.06, 0.05, 0.2))
	draw_colored_polygon(heart_points, fill_color if filled else empty_color)
	var closed_outline := heart_points.duplicate()
	closed_outline.append(heart_points[0])
	draw_polyline(closed_outline, outline_color, 2.5, true)


func _build_heart_points(offset: Vector2) -> PackedVector2Array:
	## The sampled parametric curve creates a filled heart at any control size.
	var points := PackedVector2Array()
	var scale_factor := minf(size.x / 36.0, size.y / 34.0) * 0.88
	var center := Vector2(size.x * 0.5, size.y * 0.49) + offset
	for point_index in 64:
		var angle := TAU * float(point_index) / 63.0
		var x := 16.0 * pow(sin(angle), 3.0)
		var y := (
			13.0 * cos(angle)
			- 5.0 * cos(2.0 * angle)
			- 2.0 * cos(3.0 * angle)
			- cos(4.0 * angle)
		)
		points.append(center + Vector2(x, -y) * scale_factor)
	return points
