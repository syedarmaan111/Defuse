class_name UILayout
extends RefCounted

## UILayout converts the supplied 1024x1536 mockup coordinates into the
## current device viewport. It exists so UI scenes can keep the exact mockup
## proportions while still fitting different Android phone and tablet sizes.
## Scripts call these helpers whenever a screen is shown or resized.

const DESIGN_SIZE := Vector2(1024.0, 1536.0)


static func get_design_frame(root: Control) -> Rect2:
	## Returns the centered rectangle where the full mockup should be drawn.
	## This is used on resize so artwork and button hit areas scale together.
	var viewport_size := root.size
	var scale_factor: float = min(
		viewport_size.x / DESIGN_SIZE.x,
		viewport_size.y / DESIGN_SIZE.y
	)
	var frame_size := DESIGN_SIZE * scale_factor
	var frame_position := (viewport_size - frame_size) * 0.5
	return Rect2(frame_position, frame_size)


static func place_in_design(root: Control, child: Control, design_rect: Rect2) -> void:
	## Places a child using mockup-space coordinates. This keeps overlays,
	## popup crops, and invisible touch targets aligned with the supplied art.
	var frame := get_design_frame(root)
	var scale_factor := frame.size.x / DESIGN_SIZE.x
	child.set_anchors_preset(Control.PRESET_TOP_LEFT)
	child.position = frame.position + design_rect.position * scale_factor
	child.size = design_rect.size * scale_factor


static func fit_to_design_frame(root: Control, child: Control) -> void:
	## Sizes the supplied full-screen mockup texture without distortion.
	## It is called for Home and Gameplay bases whenever the viewport changes.
	var frame := get_design_frame(root)
	child.set_anchors_preset(Control.PRESET_TOP_LEFT)
	child.position = frame.position
	child.size = frame.size
