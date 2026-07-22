extends Control

## Renders the manager-owned run state as a responsive HUD and bomb grid.
## Bomb cells emit tap intent only; GameManager decides whether a tap scores.

const BOMB_CELL_SCENE := preload("res://Scenes/Gameplay/BombCell.tscn")

@onready var pause_button: Button = %PauseButton
@onready var score_label: Label = %ScoreLabel
@onready var gem_count_label: Label = %GemCountLabel
@onready var safe_margins: MarginContainer = $SafeMargins
@onready var board_area: CenterContainer = %BoardArea
@onready var bomb_grid: GridContainer = %BombGrid

var _current_grid_side := 2
var _bomb_cells: Array[BombCell] = []
var _active_bomb_indices: Array[int] = []


func _ready() -> void:
	pause_button.pressed.connect(GameManager.pause_game)
	resized.connect(_queue_grid_layout)
	board_area.resized.connect(_queue_grid_layout)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.bomb_layout_changed.connect(_on_bomb_layout_changed)
	GameManager.bomb_timer_changed.connect(_on_bomb_timer_changed)
	GameManager.bomb_defused.connect(_on_bomb_defused)
	GameManager.bomb_exploded.connect(_on_bomb_exploded)
	EconomyManager.currency_changed.connect(_on_currency_changed)
	_apply_run_snapshot(GameManager.get_run_snapshot())
	_refresh_gems()


func _apply_run_snapshot(snapshot: Dictionary) -> void:
	_on_score_changed(int(snapshot.get("score", 0)))
	_on_lives_changed(
		int(snapshot.get("lives", GameManager.MAXIMUM_LIVES)),
		int(snapshot.get("maximum_lives", GameManager.MAXIMUM_LIVES))
	)
	_on_bomb_layout_changed(
		int(snapshot.get("grid_side", 2)),
		_to_int_array(snapshot.get("active_bomb_indices", []))
	)


func _on_score_changed(score: int) -> void:
	score_label.text = "SCORE  %d" % max(score, 0)


func _on_lives_changed(lives: int, maximum_lives: int) -> void:
	for life_index in maximum_lives:
		var life_icon := get_node_or_null("%" + ("Life%d" % (life_index + 1))) as LifeHeart
		if life_icon != null:
			life_icon.filled = life_index < lives


func _on_bomb_layout_changed(grid_side: int, active_bomb_indices: Array[int]) -> void:
	_current_grid_side = clampi(grid_side, 2, 4)
	_active_bomb_indices = active_bomb_indices.duplicate()
	var required_cell_count := _current_grid_side * _current_grid_side
	if _bomb_cells.size() != required_cell_count:
		_rebuild_grid(required_cell_count)
	for cell in _bomb_cells:
		cell.set_grid_side(_current_grid_side)
		cell.set_active(_active_bomb_indices.has(cell.bomb_index))
		if cell.is_active:
			cell.set_timer(
				GameManager.get_bomb_time_remaining(cell.bomb_index),
				GameManager.get_bomb_timer_duration(cell.bomb_index)
			)
	_queue_grid_layout()


func _on_bomb_timer_changed(
	bomb_index: int, remaining_seconds: float, duration_seconds: float
) -> void:
	var cell := _get_bomb_cell(bomb_index)
	if cell != null:
		cell.set_timer(remaining_seconds, duration_seconds)


func _on_bomb_defused(bomb_index: int) -> void:
	var cell := _get_bomb_cell(bomb_index)
	if cell != null:
		cell.play_defuse()


func _on_bomb_exploded(bomb_index: int, _reason: String) -> void:
	var cell := _get_bomb_cell(bomb_index)
	if cell != null:
		cell.play_explosion()


func _rebuild_grid(cell_count: int) -> void:
	for cell in _bomb_cells:
		bomb_grid.remove_child(cell)
		cell.queue_free()
	_bomb_cells.clear()
	bomb_grid.columns = _current_grid_side

	for bomb_index in cell_count:
		var cell := BOMB_CELL_SCENE.instantiate() as BombCell
		bomb_grid.add_child(cell)
		cell.configure(bomb_index, _active_bomb_indices.has(bomb_index))
		cell.bomb_pressed.connect(_on_bomb_pressed)
		_bomb_cells.append(cell)


func _on_bomb_pressed(bomb_index: int) -> void:
	GameManager.handle_bomb_tapped(bomb_index)


func _get_bomb_cell(bomb_index: int) -> BombCell:
	if bomb_index < 0 or bomb_index >= _bomb_cells.size():
		return null
	return _bomb_cells[bomb_index]


func _on_currency_changed(currency_id: String, _new_balance: int) -> void:
	if currency_id == EconomyManager.GEM_CURRENCY_ID:
		_refresh_gems()


func _refresh_gems() -> void:
	gem_count_label.text = str(EconomyManager.get_gem_balance())


func _queue_grid_layout() -> void:
	call_deferred("_refresh_grid_layout")


func _refresh_grid_layout() -> void:
	if not is_instance_valid(board_area) or board_area.size.x <= 0.0 or board_area.size.y <= 0.0:
		return
	var available_side := minf(board_area.size.x, board_area.size.y) * 0.98
	var grid_side_pixels := minf(available_side, 1000.0)
	var separation := (
		6
		if _current_grid_side == 4
		else clampi(roundi(grid_side_pixels * 0.024), 8, 24)
	)
	var cell_size := floorf(
		(grid_side_pixels - separation * (_current_grid_side - 1)) / _current_grid_side
	)
	bomb_grid.add_theme_constant_override("h_separation", separation)
	bomb_grid.add_theme_constant_override("v_separation", separation)
	for cell in _bomb_cells:
		cell.custom_minimum_size = Vector2.ONE * maxf(cell_size, 72.0)

	# The dense 4x4 stage uses more of the screen width. The outer 20px margin
	# still keeps content clear of the edge while making each touch target larger.
	var horizontal_margin := 20 if _current_grid_side == 4 else 48
	safe_margins.add_theme_constant_override("margin_left", horizontal_margin)
	safe_margins.add_theme_constant_override("margin_right", horizontal_margin)


func get_presented_score() -> int:
	return int(score_label.text.trim_prefix("SCORE  "))


func get_bomb_count() -> int:
	return _bomb_cells.size()


func get_presented_active_bomb_indices() -> Array[int]:
	var result: Array[int] = []
	for cell in _bomb_cells:
		if cell.is_active:
			result.append(cell.bomb_index)
	return result


func _to_int_array(source: Variant) -> Array[int]:
	var result: Array[int] = []
	if typeof(source) != TYPE_ARRAY:
		return result
	for value in source:
		if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			result.append(int(value))
	return result
