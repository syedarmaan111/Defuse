extends Node

## Owns DEFUSE run state and publishes a small signal-driven gameplay API.
## Bomb timing, explosions, rewards, and power-up effects build on this state in
## later milestones without putting gameplay rules in UI scenes.

signal screen_changed(screen_name: String)
signal game_over_requested(final_score: int, best_score: int)
signal run_started(snapshot: Dictionary)
signal run_state_changed(state_name: String)
signal score_changed(score: int)
signal lives_changed(lives: int, maximum_lives: int)
signal stage_changed(stage_number: int, stage_config: Dictionary)
signal bomb_layout_changed(grid_side: int, active_bomb_indices: Array[int])
signal bomb_armed(bomb_index: int, duration_seconds: float)
signal bomb_timer_changed(bomb_index: int, remaining_seconds: float, duration_seconds: float)
signal bomb_defused(bomb_index: int)
signal bomb_exploded(bomb_index: int, reason: String)

enum ScreenName {
	NETWORK_REQUIRED,
	SIGN_IN,
	HOME,
	GAMEPLAY,
	PAUSE,
	GAME_OVER
}

enum RunState {
	IDLE,
	RUNNING,
	PAUSED,
	GAME_OVER
}

const MAXIMUM_LIVES := 3
const RESOLUTION_GUARD_SECONDS := 0.45
const STAGE_DEFINITIONS := [
	{"stage": 1, "grid_side": 2, "active_bombs": 1, "timer_seconds": 2.6, "starts_at": 0},
	{"stage": 2, "grid_side": 2, "active_bombs": 2, "timer_seconds": 2.25, "starts_at": 10},
	{"stage": 3, "grid_side": 3, "active_bombs": 2, "timer_seconds": 1.95, "starts_at": 25},
	{"stage": 4, "grid_side": 3, "active_bombs": 3, "timer_seconds": 1.7, "starts_at": 45},
	{"stage": 5, "grid_side": 4, "active_bombs": 3, "timer_seconds": 1.5, "starts_at": 70},
]

var current_screen: ScreenName = ScreenName.HOME
var previous_screen: ScreenName = ScreenName.HOME
var current_run_state: RunState = RunState.IDLE
var current_score: int = 0
var current_lives: int = MAXIMUM_LIVES

var _stage_index := 0
var _pending_stage_index := -1
var _active_bomb_indices: Array[int] = []
var _bomb_time_remaining: Dictionary = {}
var _bomb_timer_durations: Dictionary = {}
var _resolution_cooldowns: Dictionary = {}
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	set_process(true)


func _process(delta: float) -> void:
	if current_run_state != RunState.RUNNING:
		return
	_update_resolution_cooldowns(delta)
	var expired_bombs: Array[int] = []
	for bomb_index in _active_bomb_indices.duplicate():
		if not _bomb_time_remaining.has(bomb_index):
			_arm_bomb(bomb_index)
		var duration := float(_bomb_timer_durations.get(bomb_index, 0.0))
		var remaining := maxf(float(_bomb_time_remaining.get(bomb_index, 0.0)) - delta, 0.0)
		_bomb_time_remaining[bomb_index] = remaining
		bomb_timer_changed.emit(bomb_index, remaining, duration)
		if remaining <= 0.0:
			expired_bombs.append(bomb_index)
	for bomb_index in expired_bombs:
		if current_run_state != RunState.RUNNING:
			break
		if _active_bomb_indices.has(bomb_index):
			_explode_active_bomb(bomb_index)


func set_current_screen(next_screen: ScreenName) -> void:
	## Records the requested screen and tells Main which UI should be visible.
	previous_screen = current_screen
	current_screen = next_screen
	screen_changed.emit(get_current_screen_name())


func get_current_screen_name() -> String:
	return ScreenName.keys()[current_screen].to_lower()


func get_run_state_name() -> String:
	return RunState.keys()[current_run_state].to_lower()


func get_current_stage_config() -> Dictionary:
	return STAGE_DEFINITIONS[_stage_index].duplicate(true)


func get_active_bomb_indices() -> Array[int]:
	return _active_bomb_indices.duplicate()


func get_bomb_time_remaining(bomb_index: int) -> float:
	return float(_bomb_time_remaining.get(bomb_index, 0.0))


func get_bomb_timer_duration(bomb_index: int) -> float:
	return float(_bomb_timer_durations.get(bomb_index, 0.0))


func get_pending_stage_number() -> int:
	return (
		int(STAGE_DEFINITIONS[_pending_stage_index]["stage"])
		if _pending_stage_index >= 0
		else 0
	)


func get_run_snapshot() -> Dictionary:
	## Gives UI and tests one immutable view of the current run.
	return {
		"state": get_run_state_name(),
		"score": current_score,
		"lives": current_lives,
		"maximum_lives": MAXIMUM_LIVES,
		"stage": int(get_current_stage_config()["stage"]),
		"grid_side": int(get_current_stage_config()["grid_side"]),
		"active_bombs": int(get_current_stage_config()["active_bombs"]),
		"active_bomb_indices": get_active_bomb_indices(),
	}


func start_game() -> void:
	## Starts a fresh run only after the existing launch gates are satisfied.
	if not NetworkManager.can_start_game():
		set_current_screen(ScreenName.NETWORK_REQUIRED)
		return
	if not CloudSaveManager.is_gate_satisfied() or not CloudSaveManager.is_restore_ready():
		set_current_screen(ScreenName.SIGN_IN)
		return

	current_score = 0
	current_lives = MAXIMUM_LIVES
	_stage_index = 0
	_pending_stage_index = -1
	_clear_bomb_runtime()
	_set_run_state(RunState.RUNNING)
	AudioManager.set_gameplay_audio_paused(false)
	set_current_screen(ScreenName.GAMEPLAY)
	score_changed.emit(current_score)
	lives_changed.emit(current_lives, MAXIMUM_LIVES)
	stage_changed.emit(1, get_current_stage_config())
	_build_initial_layout()
	run_started.emit(get_run_snapshot())


func pause_game() -> void:
	## Freezes gameplay input. Timer pausing will subscribe to this state in M9.
	if current_screen != ScreenName.GAMEPLAY:
		return
	_set_run_state(RunState.PAUSED)
	AudioManager.set_gameplay_audio_paused(true)
	set_current_screen(ScreenName.PAUSE)


func resume_game() -> void:
	if current_screen != ScreenName.PAUSE:
		return
	_set_run_state(RunState.RUNNING)
	AudioManager.set_gameplay_audio_paused(false)
	set_current_screen(ScreenName.GAMEPLAY)


func handle_bomb_tapped(bomb_index: int) -> bool:
	## Active taps defuse; inactive taps cause one guarded localized explosion.
	if current_run_state != RunState.RUNNING:
		return false
	var current_grid_side := int(get_current_stage_config()["grid_side"])
	var cell_count := current_grid_side ** 2
	if bomb_index < 0 or bomb_index >= cell_count:
		return false
	if _resolution_cooldowns.has(bomb_index):
		return false
	if not _active_bomb_indices.has(bomb_index):
		_explode_inactive_bomb(bomb_index)
		return true
	_defuse_active_bomb(bomb_index)
	return true


func _defuse_active_bomb(bomb_index: int) -> void:
	## Resolves only the tapped active bomb. Every other active bomb remains in
	## place. At a stage threshold, replacements pause until the wave is empty.
	_active_bomb_indices.erase(bomb_index)
	_unarm_bomb(bomb_index)
	_resolution_cooldowns[bomb_index] = RESOLUTION_GUARD_SECONDS
	bomb_defused.emit(bomb_index)
	AudioManager.play_sound("bomb_defused")
	current_score += 1
	score_changed.emit(current_score)
	_queue_eligible_stage_change()
	_after_active_bomb_resolved(bomb_index)


func _explode_active_bomb(bomb_index: int) -> void:
	_active_bomb_indices.erase(bomb_index)
	_unarm_bomb(bomb_index)
	_resolution_cooldowns[bomb_index] = RESOLUTION_GUARD_SECONDS
	bomb_exploded.emit(bomb_index, "timer_expired")
	AudioManager.play_sound("bomb_exploded")
	lose_life()
	if current_run_state == RunState.RUNNING:
		_after_active_bomb_resolved(bomb_index)


func _explode_inactive_bomb(bomb_index: int) -> void:
	_resolution_cooldowns[bomb_index] = RESOLUTION_GUARD_SECONDS
	bomb_exploded.emit(bomb_index, "inactive_tap")
	AudioManager.play_sound("bomb_exploded")
	lose_life()


func _after_active_bomb_resolved(bomb_index: int) -> void:
	var current_grid_side := int(get_current_stage_config()["grid_side"])
	if _pending_stage_index >= 0:
		if _active_bomb_indices.is_empty():
			_apply_pending_stage_change()
		else:
			bomb_layout_changed.emit(current_grid_side, get_active_bomb_indices())
		return

	var excluded_indices: Array[int] = [bomb_index]
	_fill_active_layout(excluded_indices)


func lose_life() -> bool:
	## This state transition is ready for Milestone 9 bomb explosions to call.
	if current_run_state != RunState.RUNNING or current_lives <= 0:
		return false
	current_lives -= 1
	lives_changed.emit(current_lives, MAXIMUM_LIVES)
	if current_lives == 0:
		finish_run()
	return true


func finish_run() -> void:
	## Finalizes score once and opens Game Over. It is safe to call repeatedly.
	if current_run_state not in [RunState.RUNNING, RunState.PAUSED]:
		return
	_set_run_state(RunState.GAME_OVER)
	AudioManager.set_gameplay_audio_paused(false)
	_clear_bomb_runtime()
	_active_bomb_indices.clear()
	bomb_layout_changed.emit(
		int(get_current_stage_config()["grid_side"]), get_active_bomb_indices()
	)
	if current_score > SaveManager.get_best_score():
		SaveManager.set_best_score(current_score)
	set_current_screen(ScreenName.GAME_OVER)
	game_over_requested.emit(current_score, SaveManager.get_best_score())


func return_to_home() -> void:
	## Abandons any live run and re-applies the launch gate before showing Home.
	AudioManager.set_gameplay_audio_paused(false)
	_clear_bomb_runtime()
	_active_bomb_indices.clear()
	bomb_layout_changed.emit(
		int(get_current_stage_config()["grid_side"]), get_active_bomb_indices()
	)
	current_score = 0
	current_lives = MAXIMUM_LIVES
	_stage_index = 0
	_pending_stage_index = -1
	_set_run_state(RunState.IDLE)
	show_home_if_ready()


func show_home_if_ready() -> void:
	if not NetworkManager.can_start_game():
		set_current_screen(ScreenName.NETWORK_REQUIRED)
	elif not CloudSaveManager.is_gate_satisfied() or not CloudSaveManager.is_restore_ready():
		set_current_screen(ScreenName.SIGN_IN)
	else:
		UIManager.show_home()
		set_current_screen(ScreenName.HOME)


func show_game_over(final_score: int = 0) -> void:
	## Compatibility entry point for existing UI/tests and future game systems.
	current_score = max(final_score, 0)
	if current_run_state in [RunState.RUNNING, RunState.PAUSED]:
		finish_run()
		return
	_set_run_state(RunState.GAME_OVER)
	if current_score > SaveManager.get_best_score():
		SaveManager.set_best_score(current_score)
	set_current_screen(ScreenName.GAME_OVER)
	game_over_requested.emit(current_score, SaveManager.get_best_score())


func _set_run_state(next_state: RunState) -> void:
	if current_run_state == next_state:
		return
	current_run_state = next_state
	run_state_changed.emit(get_run_state_name())


func _queue_eligible_stage_change() -> void:
	var next_stage_index := _stage_index
	for index in STAGE_DEFINITIONS.size():
		if current_score >= int(STAGE_DEFINITIONS[index]["starts_at"]):
			next_stage_index = index
	if next_stage_index > _stage_index:
		_pending_stage_index = next_stage_index


func _apply_pending_stage_change() -> void:
	## Called only after every active bomb from the previous wave is resolved.
	_stage_index = _pending_stage_index
	_pending_stage_index = -1
	stage_changed.emit(int(get_current_stage_config()["stage"]), get_current_stage_config())
	_build_initial_layout()


func _build_initial_layout() -> void:
	## A new run starts with a random valid layout for the first stage.
	_clear_bomb_runtime()
	_active_bomb_indices.clear()
	_fill_active_layout()


func _fill_active_layout(excluded_indices: Array[int] = []) -> void:
	## Adds only the bombs needed to reach the stage target. Existing active bombs
	## are never rerolled, which keeps their individual ticking state intact.
	var config := get_current_stage_config()
	var cell_count := int(config["grid_side"]) ** 2
	var required_active_count := int(config["active_bombs"])
	for index in range(_active_bomb_indices.size() - 1, -1, -1):
		if _active_bomb_indices[index] < 0 or _active_bomb_indices[index] >= cell_count:
			_active_bomb_indices.remove_at(index)

	var candidates: Array[int] = []
	var newly_armed_indices: Array[int] = []
	for cell_index in cell_count:
		if not _active_bomb_indices.has(cell_index) and not excluded_indices.has(cell_index):
			candidates.append(cell_index)
	for candidate_index in range(candidates.size() - 1, 0, -1):
		var swap_index := _random.randi_range(0, candidate_index)
		var held_value := candidates[candidate_index]
		candidates[candidate_index] = candidates[swap_index]
		candidates[swap_index] = held_value

	while _active_bomb_indices.size() < required_active_count and not candidates.is_empty():
		var new_bomb_index: int = candidates.pop_back()
		_active_bomb_indices.append(new_bomb_index)
		newly_armed_indices.append(new_bomb_index)
	# This fallback matters only if a future tiny grid leaves no alternative to
	# immediately reusing the resolved cell.
	for excluded_index in excluded_indices:
		if _active_bomb_indices.size() >= required_active_count:
			break
		if excluded_index >= 0 and excluded_index < cell_count:
			_active_bomb_indices.append(excluded_index)
			newly_armed_indices.append(excluded_index)
	_active_bomb_indices.sort()
	for bomb_index in newly_armed_indices:
		_arm_bomb(bomb_index)
	bomb_layout_changed.emit(int(config["grid_side"]), get_active_bomb_indices())


func _arm_bomb(bomb_index: int) -> void:
	var duration := float(get_current_stage_config()["timer_seconds"])
	_resolution_cooldowns.erase(bomb_index)
	_bomb_timer_durations[bomb_index] = duration
	_bomb_time_remaining[bomb_index] = duration
	AudioManager.start_tracked_sound("bomb_armed", _get_bomb_audio_id(bomb_index))
	bomb_armed.emit(bomb_index, duration)
	bomb_timer_changed.emit(bomb_index, duration, duration)


func _unarm_bomb(bomb_index: int) -> void:
	_bomb_time_remaining.erase(bomb_index)
	_bomb_timer_durations.erase(bomb_index)
	AudioManager.stop_tracked_sound(_get_bomb_audio_id(bomb_index))


func _clear_bomb_runtime() -> void:
	for bomb_index in _bomb_timer_durations.keys():
		AudioManager.stop_tracked_sound(_get_bomb_audio_id(int(bomb_index)))
	_bomb_time_remaining.clear()
	_bomb_timer_durations.clear()
	_resolution_cooldowns.clear()


func _update_resolution_cooldowns(delta: float) -> void:
	for bomb_index in _resolution_cooldowns.keys():
		var remaining := float(_resolution_cooldowns[bomb_index]) - delta
		if remaining <= 0.0:
			_resolution_cooldowns.erase(bomb_index)
		else:
			_resolution_cooldowns[bomb_index] = remaining


func _get_bomb_audio_id(bomb_index: int) -> String:
	return "bomb_%d" % bomb_index
