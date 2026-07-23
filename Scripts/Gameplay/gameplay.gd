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
@onready var super_defuse_glow: Panel = %SuperDefuseGlow
@onready var slow_motion_tint: ColorRect = %SlowMotionTint
@onready var scan_shade: ColorRect = %ScanShade
@onready var slow_motion_status: PanelContainer = %SlowMotionStatus
@onready var slow_motion_label: Label = %SlowMotionLabel
@onready var chain_defuse_status: PanelContainer = %ChainDefuseStatus
@onready var chain_defuse_label: Label = %ChainDefuseLabel
@onready var revive_grace_status: PanelContainer = %ReviveGraceStatus
@onready var revive_grace_label: Label = %ReviveGraceLabel

var _current_grid_side := 2
var _bomb_cells: Array[BombCell] = []
var _active_bomb_indices: Array[int] = []
var _scan_is_active := false
var _scan_target := -1
var _slow_motion_is_active := false
var _chain_defuse_is_active := false
var _revive_grace_is_active := false
var _scan_tween: Tween
var _slow_tint_tween: Tween
var _super_defuse_glow_tween: Tween
var _status_tweens: Dictionary = {}


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
	GameManager.bomb_protected.connect(_on_bomb_protected)
	GameManager.reward_spawned.connect(_on_reward_spawned)
	GameManager.reward_removed.connect(_on_reward_removed)
	GameManager.revive_grace_changed.connect(_on_revive_grace_changed)
	PowerUpManager.scan_target_changed.connect(_on_scan_target_changed)
	PowerUpManager.timed_effect_changed.connect(_on_timed_effect_changed)
	PowerUpManager.power_up_activated.connect(_on_power_up_activated)
	EconomyManager.currency_changed.connect(_on_currency_changed)
	_apply_run_snapshot(GameManager.get_run_snapshot())
	_sync_slow_motion_visuals()
	_sync_super_defuse_visuals()
	_sync_revive_grace_visuals()
	_refresh_gems()
	set_process(true)


func _process(_delta: float) -> void:
	if _slow_motion_is_active:
		var multiplier := PowerUpManager.get_timer_speed_multiplier()
		var remaining := PowerUpManager.get_timed_effect_remaining("slow_motion")
		var phase := "RETURNING" if multiplier > 0.36 else "SLOW MOTION"
		slow_motion_label.text = "%s  •  %.1fs  •  TIMERS ×%.2f" % [
			phase, remaining, multiplier
		]
	if _chain_defuse_is_active:
		chain_defuse_label.text = "SUPER DEFUSE  •  %.1fs" % PowerUpManager.get_timed_effect_remaining(
			"chain_defuse"
		)
	if _revive_grace_is_active:
		revive_grace_label.text = "REVIVE GRACE  •  %.1fs  •  TIMERS ×%.2f" % [
			GameManager.get_revive_grace_remaining(),
			GameManager.get_revive_grace_timer_multiplier(),
		]


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
		cell.clear_reward()
		cell.set_grid_side(_current_grid_side)
		cell.set_active(_active_bomb_indices.has(cell.bomb_index))
		cell.set_scan_mode(_scan_is_active)
		cell.set_scanned(cell.bomb_index == _scan_target)
		cell.set_slow_motion(_slow_motion_is_active)
		if cell.is_active:
			cell.set_timer(
				GameManager.get_bomb_time_remaining(cell.bomb_index),
				GameManager.get_bomb_timer_duration(cell.bomb_index)
			)
	var reward := GameManager.get_reward_snapshot()
	if not reward.is_empty():
		_on_reward_spawned(
			int(reward.get("bomb_index", -1)),
			str(reward.get("reward_type", "")),
			str(reward.get("reward_id", "")),
			str(reward.get("display_name", "")),
			int(reward.get("amount", 1)),
			float(reward.get("duration_seconds", 0.0))
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


func _on_bomb_protected(bomb_index: int, _power_up_id: String) -> void:
	var cell := _get_bomb_cell(bomb_index)
	if cell != null:
		cell.play_protection()


func _on_reward_spawned(
	bomb_index: int,
	reward_type: String,
	reward_id: String,
	display_name: String,
	reward_amount: int,
	_duration_seconds: float
) -> void:
	var cell := _get_bomb_cell(bomb_index)
	if cell != null:
		cell.set_reward(reward_type, reward_id, display_name, reward_amount)


func _on_reward_removed(bomb_index: int, _reason: String) -> void:
	var cell := _get_bomb_cell(bomb_index)
	if cell != null:
		cell.clear_reward()


func _on_revive_grace_changed(
	is_active: bool, _timer_multiplier: float, _remaining_seconds: float
) -> void:
	_revive_grace_is_active = is_active
	_set_status_visible(revive_grace_status, is_active)


func _on_scan_target_changed(bomb_index: int) -> void:
	_scan_target = bomb_index
	for cell in _bomb_cells:
		cell.set_scanned(cell.bomb_index == bomb_index)


func _on_timed_effect_changed(
	power_up_id: String, is_active: bool, _remaining_seconds: float
) -> void:
	match power_up_id:
		"scan":
			_set_scan_active(is_active)
		"slow_motion":
			_set_slow_motion_active(is_active)
		"chain_defuse":
			_set_super_defuse_active(is_active)


func _on_power_up_activated(power_up_id: String, context: Dictionary) -> void:
	if power_up_id != "extra_life":
		return
	var restored_life_index := int(context.get("restored_to", 0)) - 1
	var life_icon := get_node_or_null("%" + ("Life%d" % (restored_life_index + 1))) as LifeHeart
	if life_icon != null:
		life_icon.play_restore()


func _set_scan_active(is_active: bool) -> void:
	_scan_is_active = is_active
	if _scan_tween != null and _scan_tween.is_valid():
		_scan_tween.kill()
	if is_active:
		scan_shade.visible = true
		_scan_tween = create_tween()
		_scan_tween.tween_property(scan_shade, "color:a", 0.62, 0.85).set_trans(
			Tween.TRANS_SINE
		).set_ease(Tween.EASE_IN_OUT)
	else:
		_scan_tween = create_tween()
		_scan_tween.tween_property(scan_shade, "color:a", 0.0, 1.1).set_trans(
			Tween.TRANS_SINE
		).set_ease(Tween.EASE_IN_OUT)
		_scan_tween.tween_callback(func() -> void: scan_shade.visible = false)
	for cell in _bomb_cells:
		cell.set_scan_mode(is_active)


func _set_slow_motion_active(is_active: bool) -> void:
	_slow_motion_is_active = is_active
	if _slow_tint_tween != null and _slow_tint_tween.is_valid():
		_slow_tint_tween.kill()
	if is_active:
		slow_motion_tint.visible = true
		_slow_tint_tween = create_tween()
		_slow_tint_tween.tween_property(slow_motion_tint, "color:a", 0.12, 0.35)
	else:
		_slow_tint_tween = create_tween()
		_slow_tint_tween.tween_property(slow_motion_tint, "color:a", 0.0, 0.5)
		_slow_tint_tween.tween_callback(func() -> void: slow_motion_tint.visible = false)
	_set_status_visible(slow_motion_status, is_active)
	for cell in _bomb_cells:
		cell.set_slow_motion(is_active)


func _set_super_defuse_active(is_active: bool) -> void:
	_chain_defuse_is_active = is_active
	if _super_defuse_glow_tween != null and _super_defuse_glow_tween.is_valid():
		_super_defuse_glow_tween.kill()
	if is_active:
		_refresh_super_defuse_glow_layout()
		super_defuse_glow.visible = true
		super_defuse_glow.modulate.a = 0.0
		_super_defuse_glow_tween = create_tween().set_loops()
		_super_defuse_glow_tween.tween_property(
			super_defuse_glow, "modulate:a", 0.58, 0.24
		)
		_super_defuse_glow_tween.tween_property(
			super_defuse_glow, "modulate:a", 0.32, 0.62
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_super_defuse_glow_tween.tween_property(
			super_defuse_glow, "modulate:a", 0.58, 0.62
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_super_defuse_glow_tween = create_tween()
		_super_defuse_glow_tween.tween_property(
			super_defuse_glow, "modulate:a", 0.0, 0.2
		)
		_super_defuse_glow_tween.tween_callback(
			func() -> void: super_defuse_glow.visible = false
		)
	_set_status_visible(chain_defuse_status, is_active)


func _set_status_visible(status: Control, is_visible: bool) -> void:
	var running_tween := _status_tweens.get(status) as Tween
	if running_tween != null and running_tween.is_valid():
		running_tween.kill()
	if is_visible:
		status.visible = true
		status.modulate.a = 0.0
		status.scale = Vector2(0.92, 0.92)
		var show_tween := create_tween().set_parallel(true)
		_status_tweens[status] = show_tween
		show_tween.tween_property(status, "modulate:a", 1.0, 0.22)
		show_tween.tween_property(status, "scale", Vector2.ONE, 0.22).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)
	else:
		var hide_tween := create_tween()
		_status_tweens[status] = hide_tween
		hide_tween.tween_property(status, "modulate:a", 0.0, 0.2)
		hide_tween.tween_callback(
			func() -> void:
				status.visible = false
				_status_tweens.erase(status)
		)


func _sync_slow_motion_visuals() -> void:
	## A gameplay view can be recreated after an activation signal was emitted.
	## Restore slow motion so its overlay and countdown never depend on catching
	## that one signal at exactly the right frame.
	_set_slow_motion_active(
		PowerUpManager.get_timed_effect_remaining("slow_motion") > 0.0
	)


func _sync_super_defuse_visuals() -> void:
	_set_super_defuse_active(PowerUpManager.is_super_defuse_active())


func _sync_revive_grace_visuals() -> void:
	_revive_grace_is_active = GameManager.get_revive_grace_remaining() > 0.0
	_set_status_visible(revive_grace_status, _revive_grace_is_active)


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
	call_deferred("_refresh_super_defuse_glow_layout")

	# The dense 4x4 stage uses more of the screen width. The outer 20px margin
	# still keeps content clear of the edge while making each touch target larger.
	var horizontal_margin := 20 if _current_grid_side == 4 else 48
	safe_margins.add_theme_constant_override("margin_left", horizontal_margin)
	safe_margins.add_theme_constant_override("margin_right", horizontal_margin)


func _refresh_super_defuse_glow_layout() -> void:
	if not is_instance_valid(bomb_grid) or not is_instance_valid(super_defuse_glow):
		return
	var padding := 14.0
	var grid_position := bomb_grid.global_position - global_position
	super_defuse_glow.position = grid_position - Vector2.ONE * padding
	super_defuse_glow.size = bomb_grid.size + Vector2.ONE * padding * 2.0


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
