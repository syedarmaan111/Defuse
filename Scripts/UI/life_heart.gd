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


func _ready() -> void:
	custom_minimum_size = Vector2(54.0, 48.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


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
