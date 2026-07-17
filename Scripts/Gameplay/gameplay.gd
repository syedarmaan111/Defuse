extends Control

## Gameplay renders a responsive placeholder board for the future bomb system.
## The board is deliberately visual-only until the gameplay milestones begin.

const BOMB_TEXTURE := preload("res://Assets/Bomb/bomb_reference.png")
const BOMB_ALPHA_CLEANUP_SHADER := preload("res://Shaders/bomb_alpha_cleanup.gdshader")
const BOMB_CROP_REGION := Rect2(250.0, 180.0, 560.0, 750.0)

@export_range(2, 4, 1) var preview_grid_side: int = 2

@onready var pause_button: Button = %PauseButton
@onready var board_area: CenterContainer = %BoardArea
@onready var bomb_grid: GridContainer = %BombGrid

var _current_grid_side: int = 2


func _ready() -> void:
	## Builds only visual placeholders; bomb state and timers remain later work.
	pause_button.pressed.connect(_on_pause_pressed)
	resized.connect(_queue_grid_layout)
	board_area.resized.connect(_queue_grid_layout)
	set_grid_size(preview_grid_side)


func set_grid_size(grid_side: int) -> void:
	## Rebuilds the visual grid and keeps one consistent board footprint.
	## More bombs therefore become smaller instead of pushing off-screen.
	_current_grid_side = clampi(grid_side, 2, 4)
	bomb_grid.columns = _current_grid_side

	for child in bomb_grid.get_children():
		child.free()

	var cropped_bomb_texture: AtlasTexture = AtlasTexture.new()
	cropped_bomb_texture.atlas = BOMB_TEXTURE
	cropped_bomb_texture.region = BOMB_CROP_REGION
	var cleanup_material: ShaderMaterial = ShaderMaterial.new()
	cleanup_material.shader = BOMB_ALPHA_CLEANUP_SHADER

	for bomb_index in _current_grid_side * _current_grid_side:
		var bomb_texture := TextureRect.new()
		bomb_texture.name = "Bomb%d" % (bomb_index + 1)
		bomb_texture.texture = cropped_bomb_texture
		bomb_texture.material = cleanup_material
		bomb_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bomb_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bomb_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		bomb_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bomb_grid.add_child(bomb_texture)

	_queue_grid_layout()


func _queue_grid_layout() -> void:
	## Container sizes settle at the end of the frame, so measure afterward.
	call_deferred("_refresh_grid_layout")


func _refresh_grid_layout() -> void:
	if not is_instance_valid(board_area) or board_area.size.x <= 0.0 or board_area.size.y <= 0.0:
		return

	var available_side := minf(board_area.size.x, board_area.size.y) * 0.98
	var grid_side_pixels := minf(available_side, 1000.0)
	var separation := clampi(roundi(grid_side_pixels * 0.024), 10, 24)
	var cell_size := floorf((grid_side_pixels - separation * (_current_grid_side - 1)) / _current_grid_side)

	bomb_grid.add_theme_constant_override("h_separation", separation)
	bomb_grid.add_theme_constant_override("v_separation", separation)
	for bomb_texture in bomb_grid.get_children():
		bomb_texture.custom_minimum_size = Vector2.ONE * cell_size


func _on_pause_pressed() -> void:
	## Requests the Pause overlay from GameManager.
	GameManager.pause_game()
