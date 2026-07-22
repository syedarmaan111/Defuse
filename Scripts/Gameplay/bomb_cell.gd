extends Control
class_name BombCell

## Reusable bomb-grid cell. It renders timer/resolution state and emits player
## intent; score, lives, stages, and authoritative timing remain in GameManager.

signal bomb_pressed(bomb_index: int)

# Sample the supplied 61-image sequence at a mobile-friendly cadence. The red
# shader remains smooth every frame while limiting simultaneous GPU residency.
const SOURCE_FRAME_COUNT := 61
const DISPLAY_FRAME_COUNT := 16
const BOMB_CROP_REGION := Rect2(250.0, 180.0, 560.0, 750.0)

static var _frame_textures: Dictionary = {}

@onready var explosion_flash: Panel = %ExplosionFlash
@onready var bomb_image: TextureRect = %BombImage
@onready var touch_target: Button = %TouchTarget

var bomb_index := -1
var is_active := false
var timer_ratio := 0.0
var _base_visual_scale := 1.0
var _effect_tween: Tween


func _ready() -> void:
	touch_target.pressed.connect(_on_touch_target_pressed)
	resized.connect(_refresh_pivots)
	_apply_state(false, false)
	call_deferred("_refresh_pivots")


func configure(index: int, active: bool) -> void:
	bomb_index = index
	_apply_state(active, false)


func set_active(active: bool, animate: bool = true) -> void:
	_apply_state(active, animate)


func set_grid_side(grid_side: int) -> void:
	## 4x4 cells enlarge their artwork inside the already full-cell touch target.
	_base_visual_scale = 1.16 if grid_side == 4 else 1.0
	if _effect_tween == null:
		bomb_image.scale = Vector2.ONE * _base_visual_scale


func set_timer(remaining_seconds: float, duration_seconds: float) -> void:
	if not is_active or duration_seconds <= 0.0:
		return
	timer_ratio = clampf(remaining_seconds / duration_seconds, 0.0, 1.0)
	var danger_progress := 1.0 - timer_ratio
	var frame_index := clampi(
		floori(danger_progress * float(DISPLAY_FRAME_COUNT - 1)),
		0,
		DISPLAY_FRAME_COUNT - 1
	)
	bomb_image.texture = _get_frame_texture(frame_index)
	var cleanup_material := bomb_image.material as ShaderMaterial
	if cleanup_material != null:
		cleanup_material.set_shader_parameter("danger_progress", danger_progress)


func play_defuse() -> void:
	_cancel_effect()
	touch_target.disabled = true
	_effect_tween = create_tween()
	_effect_tween.tween_method(_render_defuse_effect, 0.0, 1.0, 0.26).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_effect_tween.tween_callback(_finish_effect)


func play_explosion() -> void:
	_cancel_effect()
	touch_target.disabled = true
	explosion_flash.visible = true
	_effect_tween = create_tween()
	_effect_tween.tween_method(_render_explosion_effect, 0.0, 1.0, 0.44).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_effect_tween.tween_callback(_finish_effect)


func _apply_state(active: bool, animate: bool) -> void:
	var became_active := active and not is_active
	is_active = active
	if not is_node_ready():
		return
	if became_active:
		_cancel_effect()
		_reset_effect_visuals()
		# A cell can be selected again while its previous defuse/explosion tween is
		# still running. Cancelling that tween skips _finish_effect(), so restore
		# input here instead of leaving the newly active bomb untappable.
		touch_target.disabled = false
	touch_target.tooltip_text = (
		"Active bomb %d" % (bomb_index + 1)
		if is_active
		else "Inactive bomb %d" % (bomb_index + 1)
	)
	if not is_active and _effect_tween == null:
		_reset_inactive_visuals()
	if animate and became_active:
		scale = Vector2.ONE * 0.94
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)


func _render_defuse_effect(progress: float) -> void:
	var inverse := 1.0 - progress
	bomb_image.scale = Vector2.ONE * lerpf(
		_base_visual_scale, _base_visual_scale * 0.72, progress
	)
	bomb_image.modulate = Color(0.35, 1.0, 0.55, inverse)


func _render_explosion_effect(progress: float) -> void:
	var inverse := 1.0 - progress
	explosion_flash.scale = Vector2.ONE * lerpf(0.45, 1.45, progress)
	explosion_flash.modulate.a = inverse
	bomb_image.rotation = sin(progress * TAU * 4.0) * 0.08 * inverse
	bomb_image.scale = Vector2.ONE * (
		_base_visual_scale * lerpf(1.0, 1.16, sin(progress * PI))
	)
	bomb_image.modulate = Color(1.0, lerpf(0.3, 0.8, progress), 0.18, inverse)


func _finish_effect() -> void:
	_effect_tween = null
	_reset_effect_visuals()
	touch_target.disabled = false
	if is_active:
		set_timer(
			GameManager.get_bomb_time_remaining(bomb_index),
			GameManager.get_bomb_timer_duration(bomb_index)
		)
	else:
		_reset_inactive_visuals()


func _cancel_effect() -> void:
	if _effect_tween != null and _effect_tween.is_valid():
		_effect_tween.kill()
	_effect_tween = null


func _reset_effect_visuals() -> void:
	bomb_image.rotation = 0.0
	bomb_image.scale = Vector2.ONE * _base_visual_scale
	bomb_image.modulate = Color.WHITE
	explosion_flash.visible = false
	explosion_flash.scale = Vector2.ONE
	explosion_flash.modulate = Color.WHITE


func _reset_inactive_visuals() -> void:
	timer_ratio = 0.0
	bomb_image.texture = _get_frame_texture(0)
	bomb_image.modulate = Color(0.84, 0.82, 0.77, 0.9)
	var cleanup_material := bomb_image.material as ShaderMaterial
	if cleanup_material != null:
		cleanup_material.set_shader_parameter("danger_progress", 0.0)


func _refresh_pivots() -> void:
	bomb_image.pivot_offset = bomb_image.size * 0.5
	explosion_flash.pivot_offset = explosion_flash.size * 0.5


func _get_frame_texture(frame_index: int) -> AtlasTexture:
	if _frame_textures.has(frame_index):
		return _frame_textures[frame_index] as AtlasTexture
	var source_frame_index := roundi(
		float(frame_index) * float(SOURCE_FRAME_COUNT - 1) / float(DISPLAY_FRAME_COUNT - 1)
	)
	var file_number := 1 if source_frame_index == 0 else source_frame_index + 3
	var source_texture := load(
		"res://Assets/Bomb/Animation/%04d.png" % file_number
	) as Texture2D
	var cropped_texture := AtlasTexture.new()
	cropped_texture.atlas = source_texture
	cropped_texture.region = BOMB_CROP_REGION
	_frame_textures[frame_index] = cropped_texture
	return cropped_texture


func _on_touch_target_pressed() -> void:
	bomb_pressed.emit(bomb_index)
