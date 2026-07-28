extends Node

## Owns DEFUSE run state and publishes a small signal-driven gameplay API.
## Bomb timing, explosions, rewards, and power-up effects build on this state in
## later milestones without putting gameplay rules in UI scenes.

signal screen_changed(screen_name: String)
signal game_over_requested(final_score: int, best_score: int)
signal mode_selected(mode_id: String, definition: GameModeDefinition)
signal mode_start_rejected(mode_id: String, reason: String)
signal mode_phase_changed(phase_name: String, remaining_seconds: float)
signal run_timer_changed(remaining_seconds: float, total_seconds: float)
signal memory_cell_state_changed(bomb_index: int, state_name: String)
signal memory_pattern_completed(pattern_score: int, gem_amount: int)
signal run_started(snapshot: Dictionary)
signal run_finished(reason: String, final_score: int)
signal run_state_changed(state_name: String)
signal score_changed(score: int)
signal lives_changed(lives: int, maximum_lives: int)
signal stage_changed(stage_number: int, stage_config: Dictionary)
signal bomb_layout_changed(grid_side: int, active_bomb_indices: Array[int])
signal bomb_armed(bomb_index: int, duration_seconds: float)
signal bomb_timer_changed(bomb_index: int, remaining_seconds: float, duration_seconds: float)
signal bomb_defused(bomb_index: int)
signal bomb_exploded(bomb_index: int, reason: String)
signal bomb_protected(bomb_index: int, power_up_id: String)
signal reward_spawned(
	bomb_index: int,
	reward_type: String,
	reward_id: String,
	display_name: String,
	reward_amount: int,
	duration_seconds: float
)
signal reward_removed(bomb_index: int, reason: String)
signal reward_claimed(bomb_index: int, reward_type: String, reward_id: String)
signal countdown_started(reason: String)
signal countdown_tick(value: int, reason: String)
signal countdown_finished(reason: String)
signal rewarded_revive_requested()
signal rewarded_revive_granted()
signal rewarded_revive_failed(error_code: String)
signal revive_availability_changed(is_available: bool)
signal revive_grace_changed(
	is_active: bool, timer_multiplier: float, remaining_seconds: float
)

enum ScreenName {
	NETWORK_REQUIRED,
	SIGN_IN,
	HOME,
	MODE_SELECT,
	GAMEPLAY,
	PAUSE,
	GAME_OVER
}

enum RunState {
	IDLE,
	COUNTDOWN,
	RUNNING,
	PAUSED,
	GAME_OVER
}

const MAXIMUM_LIVES := 3
const DEFAULT_MODE_ID := "endless"
const ALL_MODES_TEMPORARILY_UNLOCKED := true
const MODE_CATALOG: GameModeCatalog = preload(
	"res://Resources/Content/GameModes/GameModeCatalog.tres"
)
const COUNTDOWN_START_VALUE := 3
const COUNTDOWN_STEP_SECONDS := 0.8
const REVIVE_GRACE_DURATION_SECONDS := 5.0
const REVIVE_GRACE_START_MULTIPLIER := 0.75
const RESOLUTION_GUARD_SECONDS := 0.45
const REWARD_SPAWN_MIN_SECONDS := 7.0
const REWARD_SPAWN_MAX_SECONDS := 11.0
const REWARD_LIFETIME_SECONDS := 6.0
const REWARD_ACTIVE_TARGET_MIN_REMAINING_SECONDS := 0.75
const POWER_UP_REWARD_CHANCE := 0.75
const GEM_REWARD_ONE_CHANCE := 0.65
const GEM_REWARD_TWO_CHANCE := 0.25
const PRECISION_REST_SECONDS := 1.5
const MEMORY_PREVIEW_SECONDS := 2.5
const MEMORY_MINIMUM_PREVIEW_SECONDS := 1.8
const MEMORY_PREVIEW_REDUCTION_PER_LEVEL := 0.04
const MEMORY_COMPLETION_REVEAL_SECONDS := 0.75
const MEMORY_INACTIVE_PAUSE_SECONDS := 0.75
const MEMORY_INTERMISSION_SECONDS := (
	MEMORY_COMPLETION_REVEAL_SECONDS + MEMORY_INACTIVE_PAUSE_SECONDS
)
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
var current_defusals: int = 0
var current_lives: int = MAXIMUM_LIVES
var current_mode_id: String = DEFAULT_MODE_ID

var _stage_index := 0
var _pending_stage_index := -1
var _active_bomb_indices: Array[int] = []
var _bomb_time_remaining: Dictionary = {}
var _bomb_timer_durations: Dictionary = {}
var _resolution_cooldowns: Dictionary = {}
var _reward_data: Dictionary = {}
var _reward_spawn_remaining := 0.0
var _random := RandomNumberGenerator.new()
var _countdown_value := 0
var _countdown_step_remaining := 0.0
var _countdown_reason := ""
var _revive_used := false
var _rewarded_revive_request_in_flight := false
var _revive_grace_remaining := 0.0
var _run_completion_recorded := false
var _pending_start_mode_id := DEFAULT_MODE_ID
var _mode_phase_name := "RUNNING"
var _run_time_remaining := 0.0
var _run_end_reason := ""
var _mode_phase_remaining := 0.0
var _phase_before_pause := "RUNNING"
var _memory_pattern: Array[int] = []
var _memory_previous_pattern: Array[int] = []
var _memory_revealed: Array[int] = []
var _memory_completion_visible := false


func _ready() -> void:
	_random.randomize()
	AdManager.new_run_ready.connect(_start_game_after_ad)
	AdManager.rewarded_completed.connect(_on_rewarded_ad_completed)
	AdManager.rewarded_failed.connect(_on_rewarded_ad_failed)
	set_process(true)


func _process(delta: float) -> void:
	if current_run_state == RunState.COUNTDOWN:
		_advance_countdown(delta)
		return
	if current_run_state != RunState.RUNNING:
		return
	if current_mode_id == "memory":
		_process_memory_mode(delta)
		return
	if current_mode_id == "precision" and _mode_phase_name == "REST":
		_advance_precision_rest(delta)
		return
	if _advance_run_timer(delta):
		return
	_update_resolution_cooldowns(delta)
	var timer_delta := (
		delta
		* (
			PowerUpManager.get_timer_speed_multiplier()
			if are_power_ups_enabled_for_run()
			else 1.0
		)
		* get_revive_grace_timer_multiplier()
	)
	var expired_bombs: Array[int] = []
	for bomb_index in _active_bomb_indices.duplicate():
		if not _bomb_time_remaining.has(bomb_index):
			_arm_bomb(bomb_index)
		var duration := float(_bomb_timer_durations.get(bomb_index, 0.0))
		var remaining := maxf(
			float(_bomb_time_remaining.get(bomb_index, 0.0)) - timer_delta, 0.0
		)
		_bomb_time_remaining[bomb_index] = remaining
		bomb_timer_changed.emit(bomb_index, remaining, duration)
		if remaining <= 0.0:
			expired_bombs.append(bomb_index)
	if are_power_ups_enabled_for_run():
		PowerUpManager.evaluate_timer_pressure(
			get_active_bomb_indices(), _bomb_time_remaining, _bomb_timer_durations
		)
	for bomb_index in expired_bombs:
		if current_run_state != RunState.RUNNING:
			break
		if _active_bomb_indices.has(bomb_index):
			_explode_active_bomb(bomb_index)
	# Resolve timers, stage changes, and Game Over before spawning a reward. This
	# prevents a badge from being shown and removed again in the same frame.
	if current_run_state == RunState.RUNNING:
		_process_reward(delta)
	_advance_revive_grace(delta)


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
	var stages := _get_stage_definitions()
	if stages.is_empty():
		return STAGE_DEFINITIONS[0].duplicate(true)
	return stages[clampi(_stage_index, 0, stages.size() - 1)].to_dictionary()


func get_active_bomb_indices() -> Array[int]:
	return _active_bomb_indices.duplicate()


func get_bomb_time_remaining(bomb_index: int) -> float:
	return float(_bomb_time_remaining.get(bomb_index, 0.0))


func get_bomb_timer_duration(bomb_index: int) -> float:
	return float(_bomb_timer_durations.get(bomb_index, 0.0))


func get_pending_stage_number() -> int:
	var stages := _get_stage_definitions()
	return (
		stages[_pending_stage_index].stage_number
		if _pending_stage_index >= 0 and _pending_stage_index < stages.size()
		else 0
	)


func get_run_snapshot() -> Dictionary:
	## Gives UI and tests one immutable view of the current run.
	return {
		"state": get_run_state_name(),
		"mode_id": current_mode_id,
		"mode_name": get_current_mode_definition().display_name,
		"score_label": get_current_mode_definition().score_label,
		"mode_phase": get_mode_phase_name(),
		"run_time_remaining": get_run_time_remaining(),
		"run_end_reason": get_run_end_reason(),
		"score": current_score,
		"successful_defusals": current_defusals,
		"lives": current_lives,
		"maximum_lives": get_maximum_lives(),
		"has_life_system": get_current_mode_definition().has_life_system,
		"power_ups_enabled": are_power_ups_enabled_for_run(),
		"stage": int(get_current_stage_config()["stage"]),
		"grid_side": int(get_current_stage_config()["grid_side"]),
		"active_bombs": int(get_current_stage_config()["active_bombs"]),
		"active_bomb_indices": get_active_bomb_indices(),
		"countdown_value": _countdown_value,
		"countdown_reason": _countdown_reason,
		"revive_used": _revive_used,
		"revive_grace_remaining": _revive_grace_remaining,
		"revive_grace_multiplier": get_revive_grace_timer_multiplier(),
		"memory_pattern": _memory_pattern.duplicate(),
		"memory_revealed": _memory_revealed.duplicate(),
		"memory_completion_visible": _memory_completion_visible,
	}


func get_reward_snapshot() -> Dictionary:
	return _reward_data.duplicate(true)


func get_mode_definitions() -> Array[GameModeDefinition]:
	return MODE_CATALOG.modes.duplicate()


func get_current_mode_id() -> String:
	return current_mode_id


func get_current_mode_definition() -> GameModeDefinition:
	var definition := MODE_CATALOG.get_mode(current_mode_id)
	return definition if definition != null else MODE_CATALOG.get_mode(DEFAULT_MODE_ID)


func get_mode_phase_name() -> String:
	return _mode_phase_name


func get_run_time_remaining() -> float:
	return _run_time_remaining


func get_run_end_reason() -> String:
	return _run_end_reason


func get_maximum_lives() -> int:
	return get_current_mode_definition().maximum_lives


func are_power_ups_enabled_for_run() -> bool:
	return get_current_mode_definition().power_ups_enabled


func is_mode_unlocked(mode_id: String) -> bool:
	var definition := MODE_CATALOG.get_mode(mode_id)
	return (
		definition != null
		and (
			ALL_MODES_TEMPORARILY_UNLOCKED
			or SaveManager.get_lifetime_defusals()
			>= definition.unlock_lifetime_defusals
		)
	)


func start_game(mode_id: String = DEFAULT_MODE_ID) -> void:
	## Starts a fresh run only after the existing launch gates are satisfied.
	var definition := MODE_CATALOG.get_mode(mode_id)
	if definition == null:
		mode_start_rejected.emit(mode_id, "unknown_mode")
		return
	if not is_mode_unlocked(mode_id):
		mode_start_rejected.emit(mode_id, "locked")
		return
	if not NetworkManager.can_start_game():
		set_current_screen(ScreenName.NETWORK_REQUIRED)
		return
	if not CloudSaveManager.is_gate_satisfied() or not CloudSaveManager.is_restore_ready():
		set_current_screen(ScreenName.SIGN_IN)
		return
	_pending_start_mode_id = mode_id
	if AdManager.intercept_new_run_request():
		return
	_start_game_after_ad()


func restart_current_mode() -> void:
	start_game(current_mode_id)


func _start_game_after_ad() -> void:
	## Rechecks every online gate because an asynchronous ad may have completed
	## after the connection or sign-in state changed.
	if not NetworkManager.can_start_game():
		set_current_screen(ScreenName.NETWORK_REQUIRED)
		return
	if not CloudSaveManager.is_gate_satisfied() or not CloudSaveManager.is_restore_ready():
		set_current_screen(ScreenName.SIGN_IN)
		return

	var selected_definition := MODE_CATALOG.get_mode(_pending_start_mode_id)
	if selected_definition == null or not is_mode_unlocked(_pending_start_mode_id):
		mode_start_rejected.emit(_pending_start_mode_id, "locked")
		return
	current_mode_id = _pending_start_mode_id
	_mode_phase_name = selected_definition.initial_phase_name
	_run_time_remaining = selected_definition.run_duration_seconds
	_run_end_reason = ""
	current_score = 0
	current_defusals = 0
	current_lives = get_maximum_lives()
	_stage_index = 0
	_pending_stage_index = -1
	_revive_used = false
	_rewarded_revive_request_in_flight = false
	_run_completion_recorded = false
	_reset_special_mode_runtime()
	_stop_countdown()
	_stop_revive_grace()
	_clear_bomb_runtime()
	_reset_reward_runtime()
	PowerUpManager.reset_run_effects()
	mode_selected.emit(current_mode_id, selected_definition)
	mode_phase_changed.emit(_mode_phase_name, _run_time_remaining)
	run_timer_changed.emit(_run_time_remaining, selected_definition.run_duration_seconds)
	set_current_screen(ScreenName.GAMEPLAY)
	score_changed.emit(current_score)
	lives_changed.emit(current_lives, get_maximum_lives())
	stage_changed.emit(1, get_current_stage_config())
	_start_mode_layout()
	_set_run_state(RunState.RUNNING)
	AudioManager.set_gameplay_audio_paused(false)
	run_started.emit(get_run_snapshot())


func pause_game() -> void:
	## Freezes all gameplay clocks and input until Resume starts its countdown.
	if current_screen != ScreenName.GAMEPLAY or current_run_state != RunState.RUNNING:
		return
	_phase_before_pause = _mode_phase_name
	_set_run_state(RunState.PAUSED)
	_set_mode_phase("PAUSED")
	AudioManager.set_gameplay_audio_paused(true)
	set_current_screen(ScreenName.PAUSE)


func resume_game() -> void:
	if current_screen != ScreenName.PAUSE or current_run_state != RunState.PAUSED:
		return
	set_current_screen(ScreenName.GAMEPLAY)
	_begin_countdown("resume")


func is_countdown_active() -> bool:
	return current_run_state == RunState.COUNTDOWN


func get_countdown_value() -> int:
	return _countdown_value


func get_countdown_reason() -> String:
	return _countdown_reason


func can_offer_rewarded_revive() -> bool:
	## Availability requires a ready provider (or explicit debug simulation).
	return (
		get_current_mode_definition().rewarded_revive_enabled
		and get_current_mode_definition().has_life_system
		and current_run_state == RunState.GAME_OVER
		and current_lives <= 0
		and not _revive_used
		and not _rewarded_revive_request_in_flight
		and NetworkManager.can_start_game()
		and AdManager.can_show_rewarded()
	)


func is_rewarded_revive_simulation_enabled() -> bool:
	## Compatibility query retained for Milestone 12 tests and debug tooling.
	return AdManager.is_simulation_enabled()


func request_rewarded_revive() -> bool:
	## A revive is granted only from AdManager's earned-reward callback.
	if not can_offer_rewarded_revive():
		return false
	_rewarded_revive_request_in_flight = true
	revive_availability_changed.emit(false)
	rewarded_revive_requested.emit()
	if not AdManager.request_rewarded("revive"):
		reject_rewarded_revive("request_failed")
		return false
	return true


func reject_rewarded_revive(error_code: String = "reward_not_granted") -> void:
	## Future ad-provider failures return here so the player is never trapped in
	## a loading state and can continue with normal Game Over actions.
	if not _rewarded_revive_request_in_flight:
		return
	_rewarded_revive_request_in_flight = false
	rewarded_revive_failed.emit(error_code)
	revive_availability_changed.emit(can_offer_rewarded_revive())


func grant_rewarded_revive() -> bool:
	## Called only after a rewarded-ad completion callback (or the development
	## simulation). It preserves score/stage and rebuilds a completely fresh wave.
	if (
		current_run_state != RunState.GAME_OVER
		or not get_current_mode_definition().rewarded_revive_enabled
		or not get_current_mode_definition().has_life_system
		or current_lives > 0
		or _revive_used
	):
		_rewarded_revive_request_in_flight = false
		return false
	_rewarded_revive_request_in_flight = false
	_revive_used = true
	current_lives = mini(1, get_maximum_lives())
	_sync_stage_to_progress()
	_clear_bomb_runtime()
	_reset_reward_runtime()
	PowerUpManager.reset_run_effects()
	lives_changed.emit(current_lives, get_maximum_lives())
	stage_changed.emit(
		int(get_current_stage_config()["stage"]), get_current_stage_config()
	)
	if current_mode_id == "memory":
		_memory_revealed.clear()
		_active_bomb_indices = _memory_pattern.duplicate()
		bomb_layout_changed.emit(
			int(get_current_stage_config()["grid_side"]), get_active_bomb_indices()
		)
		_emit_memory_states("hidden")
	else:
		_build_initial_layout()
	set_current_screen(ScreenName.GAMEPLAY)
	_begin_countdown("revive")
	rewarded_revive_granted.emit()
	revive_availability_changed.emit(false)
	return true


func get_revive_grace_remaining() -> float:
	return _revive_grace_remaining


func get_revive_grace_timer_multiplier() -> float:
	if _revive_grace_remaining <= 0.0:
		return 1.0
	var progress := 1.0 - (
		_revive_grace_remaining / REVIVE_GRACE_DURATION_SECONDS
	)
	return lerpf(
		REVIVE_GRACE_START_MULTIPLIER,
		1.0,
		clampf(progress, 0.0, 1.0)
	)


func handle_bomb_tapped(bomb_index: int) -> bool:
	return handle_bombs_tapped([bomb_index]) > 0


func handle_bombs_tapped(bomb_indices: Array[int]) -> int:
	## Resolves one frame's finger-down events against a single layout snapshot.
	## This makes true multi-touch deterministic even when several bombs are
	## pressed before the frame ends.
	if current_run_state != RunState.RUNNING:
		return 0
	var unique_indices: Array[int] = []
	for bomb_index in bomb_indices:
		if not unique_indices.has(bomb_index):
			unique_indices.append(bomb_index)
	if current_mode_id == "memory":
		return _handle_memory_taps(unique_indices)
	if current_mode_id == "precision" and _mode_phase_name == "REST":
		return 0
	var current_grid_side := int(get_current_stage_config()["grid_side"])
	var cell_count := current_grid_side ** 2
	var active_at_batch_start := _active_bomb_indices.duplicate()
	var active_taps: Array[int] = []
	var inactive_taps: Array[int] = []
	var resolved_indices: Array[int] = []
	var accepted_count := 0
	for bomb_index in unique_indices:
		if bomb_index < 0 or bomb_index >= cell_count:
			continue
		if _resolution_cooldowns.has(bomb_index):
			continue
		accepted_count += 1
		if int(_reward_data.get("bomb_index", -1)) == bomb_index:
			_claim_reward()
			if not active_at_batch_start.has(bomb_index):
				continue
		if active_at_batch_start.has(bomb_index):
			active_taps.append(bomb_index)
		else:
			inactive_taps.append(bomb_index)
	# Correct simultaneous presses resolve before mistakes can end the run. This
	# removes any dependence on the order Android assigned to the finger events.
	for bomb_index in active_taps:
		# A chain defuse triggered by an earlier finger may already have resolved
		# this bomb; it still counts as an accepted simultaneous tap.
		if _active_bomb_indices.has(bomb_index):
			resolved_indices.append_array(_defuse_active_bomb(bomb_index, true))
	for bomb_index in inactive_taps:
		_explode_inactive_bomb(bomb_index)
	if current_run_state == RunState.RUNNING and not resolved_indices.is_empty():
		_after_active_bombs_resolved(resolved_indices)
	return accepted_count


func _defuse_active_bomb(bomb_index: int, defer_layout_refresh: bool = false) -> Array[int]:
	## Resolves the tapped active bomb. While Super Defuse is active, the same
	## action also resolves every other bomb that was armed at that moment.
	_active_bomb_indices.erase(bomb_index)
	_unarm_bomb(bomb_index)
	_resolution_cooldowns[bomb_index] = RESOLUTION_GUARD_SECONDS
	bomb_defused.emit(bomb_index)
	AudioManager.play_sound("bomb_defused")
	if are_power_ups_enabled_for_run():
		PowerUpManager.register_successful_defusal()
	current_defusals += 1
	current_score += (
		PowerUpManager.get_score_multiplier()
		if are_power_ups_enabled_for_run()
		else 1
	)
	score_changed.emit(current_score)
	var resolved_indices: Array[int] = [bomb_index]
	if (
		are_power_ups_enabled_for_run()
		and PowerUpManager.try_activate_chain_defuse(_active_bomb_indices.size())
	):
		var chained_indices: Array[int] = _active_bomb_indices.duplicate()
		for chained_index in chained_indices:
			_active_bomb_indices.erase(chained_index)
			_unarm_bomb(chained_index)
			_resolution_cooldowns[chained_index] = RESOLUTION_GUARD_SECONDS
			if int(_reward_data.get("bomb_index", -1)) == chained_index:
				_remove_reward("chain_defuse")
			bomb_defused.emit(chained_index)
			AudioManager.play_sound("bomb_defused")
			current_defusals += 1
			current_score += PowerUpManager.get_score_multiplier()
			score_changed.emit(current_score)
			resolved_indices.append(chained_index)
	if get_current_mode_definition().lifetime_credit_enabled:
		SaveManager.add_lifetime_defusals(resolved_indices.size())
	_queue_eligible_stage_change()
	if not defer_layout_refresh:
		_after_active_bombs_resolved(resolved_indices)
	return resolved_indices


func _explode_active_bomb(bomb_index: int) -> void:
	_active_bomb_indices.erase(bomb_index)
	_unarm_bomb(bomb_index)
	_resolution_cooldowns[bomb_index] = RESOLUTION_GUARD_SECONDS
	if int(_reward_data.get("bomb_index", -1)) == bomb_index:
		_remove_reward("bomb_expired")
	if (
		are_power_ups_enabled_for_run()
		and PowerUpManager.try_block_explosion(bomb_index, "timer_expired")
	):
		bomb_protected.emit(bomb_index, "shield")
	else:
		bomb_exploded.emit(bomb_index, "timer_expired")
		AudioManager.play_sound("bomb_exploded")
		lose_life()
	if current_run_state == RunState.RUNNING:
		_after_active_bombs_resolved([bomb_index])


func _explode_inactive_bomb(bomb_index: int) -> void:
	_resolution_cooldowns[bomb_index] = RESOLUTION_GUARD_SECONDS
	if are_power_ups_enabled_for_run() and PowerUpManager.is_super_defuse_active():
		bomb_protected.emit(bomb_index, "chain_defuse")
	elif (
		are_power_ups_enabled_for_run()
		and PowerUpManager.try_block_explosion(bomb_index, "inactive_tap")
	):
		bomb_protected.emit(bomb_index, "shield")
	else:
		bomb_exploded.emit(bomb_index, "inactive_tap")
		AudioManager.play_sound("bomb_exploded")
		lose_life()


func _after_active_bombs_resolved(resolved_indices: Array[int]) -> void:
	var current_grid_side := int(get_current_stage_config()["grid_side"])
	if current_mode_id == "precision":
		if _active_bomb_indices.is_empty():
			_begin_precision_rest()
		else:
			bomb_layout_changed.emit(current_grid_side, get_active_bomb_indices())
		return
	if _pending_stage_index >= 0:
		# Time Attack follows its score curve immediately. Standard modes retain
		# the wave-safe transition used by Endless.
		if current_mode_id == "time_attack":
			_apply_pending_stage_change()
			return
		if _active_bomb_indices.is_empty():
			_apply_pending_stage_change()
		else:
			bomb_layout_changed.emit(current_grid_side, get_active_bomb_indices())
		return

	_fill_active_layout(resolved_indices)


func lose_life() -> bool:
	## This state transition is ready for Milestone 9 bomb explosions to call.
	var maximum_lives := get_maximum_lives()
	if (
		current_run_state != RunState.RUNNING
		or not get_current_mode_definition().has_life_system
		or current_lives <= 0
	):
		return false
	current_lives -= 1
	lives_changed.emit(current_lives, maximum_lives)
	if are_power_ups_enabled_for_run() and PowerUpManager.try_restore_life(
		current_lives, maximum_lives
	):
		current_lives += 1
		lives_changed.emit(current_lives, maximum_lives)
	if current_lives == 0:
		finish_run()
	return true


func finish_run(reason: String = "lives_depleted") -> void:
	## Finalizes score once and opens Game Over. It is safe to call repeatedly.
	if current_run_state not in [RunState.RUNNING, RunState.PAUSED]:
		return
	_run_end_reason = reason.strip_edges().to_lower()
	if _run_end_reason.is_empty():
		_run_end_reason = "completed"
	_set_run_state(RunState.GAME_OVER)
	_set_mode_phase("TIME UP" if _run_end_reason == "time_up" else "GAME OVER")
	_stop_countdown()
	_stop_revive_grace()
	AudioManager.set_gameplay_audio_paused(false)
	_clear_bomb_runtime()
	_clear_reward_runtime("run_finished")
	PowerUpManager.reset_run_effects()
	_active_bomb_indices.clear()
	bomb_layout_changed.emit(
		int(get_current_stage_config()["grid_side"]), get_active_bomb_indices()
	)
	if current_score > SaveManager.get_mode_best_score(current_mode_id):
		SaveManager.set_mode_best_score(current_mode_id, current_score)
	PowerUpManager.queue_lifetime_checkpoint_choices()
	_record_run_completion_once()
	set_current_screen(ScreenName.GAME_OVER)
	game_over_requested.emit(
		current_score, SaveManager.get_mode_best_score(current_mode_id)
	)
	revive_availability_changed.emit(can_offer_rewarded_revive())
	run_finished.emit(_run_end_reason, current_score)


func return_to_home() -> void:
	## Abandons any live run and re-applies the launch gate before showing Home.
	AudioManager.set_gameplay_audio_paused(false)
	_clear_bomb_runtime()
	_clear_reward_runtime("run_abandoned")
	PowerUpManager.reset_run_effects()
	_active_bomb_indices.clear()
	bomb_layout_changed.emit(
		int(get_current_stage_config()["grid_side"]), get_active_bomb_indices()
	)
	current_score = 0
	current_defusals = 0
	current_lives = get_maximum_lives()
	_stage_index = 0
	_pending_stage_index = -1
	_revive_used = false
	_rewarded_revive_request_in_flight = false
	_run_completion_recorded = false
	_run_time_remaining = 0.0
	_run_end_reason = ""
	_stop_countdown()
	_stop_revive_grace()
	PowerUpManager.queue_lifetime_checkpoint_choices()
	_set_run_state(RunState.IDLE)
	_set_mode_phase("IDLE")
	show_home_if_ready()


func return_to_mode_select() -> void:
	## Abandons a live run and returns to the selector without changing the
	## selected mode or recording a completed attempt.
	AudioManager.set_gameplay_audio_paused(false)
	_clear_bomb_runtime()
	_clear_reward_runtime("run_abandoned")
	PowerUpManager.reset_run_effects()
	_active_bomb_indices.clear()
	bomb_layout_changed.emit(
		int(get_current_stage_config()["grid_side"]), get_active_bomb_indices()
	)
	current_score = 0
	current_defusals = 0
	current_lives = get_maximum_lives()
	_stage_index = 0
	_pending_stage_index = -1
	_revive_used = false
	_rewarded_revive_request_in_flight = false
	_run_completion_recorded = false
	_run_time_remaining = 0.0
	_run_end_reason = ""
	_stop_countdown()
	_stop_revive_grace()
	PowerUpManager.queue_lifetime_checkpoint_choices()
	_set_run_state(RunState.IDLE)
	_set_mode_phase("IDLE")
	show_mode_select_if_ready()


func show_mode_select_if_ready() -> void:
	if not NetworkManager.can_start_game():
		set_current_screen(ScreenName.NETWORK_REQUIRED)
	elif not CloudSaveManager.is_gate_satisfied() or not CloudSaveManager.is_restore_ready():
		set_current_screen(ScreenName.SIGN_IN)
	else:
		UIManager.show_home()
		set_current_screen(ScreenName.MODE_SELECT)


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
	_run_end_reason = "completed"
	_set_mode_phase("GAME OVER")
	if current_score > SaveManager.get_mode_best_score(current_mode_id):
		SaveManager.set_mode_best_score(current_mode_id, current_score)
	PowerUpManager.queue_lifetime_checkpoint_choices()
	_record_run_completion_once()
	set_current_screen(ScreenName.GAME_OVER)
	game_over_requested.emit(
		current_score, SaveManager.get_mode_best_score(current_mode_id)
	)
	revive_availability_changed.emit(can_offer_rewarded_revive())
	run_finished.emit(_run_end_reason, current_score)


func _set_run_state(next_state: RunState) -> void:
	if current_run_state == next_state:
		return
	current_run_state = next_state
	run_state_changed.emit(get_run_state_name())


func _record_run_completion_once() -> void:
	## A rewarded continuation belongs to the same run and must not increment the
	## persisted cadence a second time when its restored life is later lost.
	if _run_completion_recorded:
		return
	_run_completion_recorded = true
	AdManager.register_completed_run()


func _on_rewarded_ad_completed(placement_id: String) -> void:
	if placement_id == "revive":
		grant_rewarded_revive()


func _on_rewarded_ad_failed(placement_id: String, error_code: String) -> void:
	if placement_id == "revive":
		reject_rewarded_revive(error_code)


func _begin_countdown(reason: String) -> bool:
	## One manager-owned countdown pauses every gameplay clock by using the run
	## state already respected by bombs, rewards, effects, scoring, and input.
	if current_run_state == RunState.COUNTDOWN:
		return false
	_countdown_reason = reason
	_countdown_value = COUNTDOWN_START_VALUE
	_countdown_step_remaining = COUNTDOWN_STEP_SECONDS
	_set_run_state(RunState.COUNTDOWN)
	_set_mode_phase("COUNTDOWN")
	AudioManager.set_gameplay_audio_paused(true)
	countdown_started.emit(reason)
	countdown_tick.emit(_countdown_value, reason)
	return true


func _advance_countdown(delta: float) -> void:
	if current_run_state != RunState.COUNTDOWN:
		return
	_countdown_step_remaining -= maxf(delta, 0.0)
	while _countdown_step_remaining <= 0.0 and current_run_state == RunState.COUNTDOWN:
		_countdown_value -= 1
		if _countdown_value <= 0:
			_finish_countdown()
			return
		_countdown_step_remaining += COUNTDOWN_STEP_SECONDS
		countdown_tick.emit(_countdown_value, _countdown_reason)


func _finish_countdown() -> void:
	var finished_reason := _countdown_reason
	_countdown_value = 0
	_countdown_step_remaining = 0.0
	_countdown_reason = ""
	if finished_reason == "revive" and current_mode_id != "memory":
		_start_revive_grace()
	_set_run_state(RunState.RUNNING)
	AudioManager.set_gameplay_audio_paused(false)
	countdown_finished.emit(finished_reason)
	if finished_reason == "revive" and current_mode_id == "memory":
		_begin_memory_pattern(true)
	elif finished_reason == "resume":
		_set_mode_phase(_phase_before_pause)
	else:
		_set_mode_phase(get_current_mode_definition().initial_phase_name)


func _stop_countdown() -> void:
	_countdown_value = 0
	_countdown_step_remaining = 0.0
	_countdown_reason = ""


func _start_revive_grace() -> void:
	_revive_grace_remaining = REVIVE_GRACE_DURATION_SECONDS
	revive_grace_changed.emit(
		true,
		get_revive_grace_timer_multiplier(),
		_revive_grace_remaining
	)


func _advance_revive_grace(delta: float) -> void:
	if _revive_grace_remaining <= 0.0:
		return
	_revive_grace_remaining = maxf(_revive_grace_remaining - delta, 0.0)
	revive_grace_changed.emit(
		_revive_grace_remaining > 0.0,
		get_revive_grace_timer_multiplier(),
		_revive_grace_remaining
	)


func _stop_revive_grace() -> void:
	if _revive_grace_remaining > 0.0:
		_revive_grace_remaining = 0.0
		revive_grace_changed.emit(false, 1.0, 0.0)
	else:
		_revive_grace_remaining = 0.0


func _sync_stage_to_progress() -> void:
	var target_stage_index := 0
	var stages := _get_stage_definitions()
	for index in stages.size():
		if _get_mode_progress() >= stages[index].starts_at:
			target_stage_index = index
	_stage_index = target_stage_index
	_pending_stage_index = -1


func _queue_eligible_stage_change() -> void:
	var next_stage_index := _stage_index
	var stages := _get_stage_definitions()
	for index in stages.size():
		if _get_mode_progress() >= stages[index].starts_at:
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
	if not _reward_data.is_empty():
		_remove_reward("grid_changed")
	_clear_bomb_runtime()
	_active_bomb_indices.clear()
	_fill_active_layout()


func _start_mode_layout() -> void:
	if current_mode_id == "memory":
		_begin_memory_pattern(false)
	else:
		_build_initial_layout()


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


func _get_most_urgent_active_bomb() -> int:
	var most_urgent_index := -1
	var least_remaining := INF
	for bomb_index in _active_bomb_indices:
		var remaining := get_bomb_time_remaining(bomb_index)
		if remaining < least_remaining:
			least_remaining = remaining
			most_urgent_index = bomb_index
	return most_urgent_index


func _reset_reward_runtime() -> void:
	_reward_data.clear()
	_schedule_next_reward()


func _clear_reward_runtime(reason: String) -> void:
	if not _reward_data.is_empty():
		reward_removed.emit(int(_reward_data.get("bomb_index", -1)), reason)
	_reward_data.clear()
	_reward_spawn_remaining = 0.0


func _schedule_next_reward() -> void:
	_reward_spawn_remaining = _random.randf_range(
		REWARD_SPAWN_MIN_SECONDS, REWARD_SPAWN_MAX_SECONDS
	)


func _process_reward(delta: float) -> void:
	var definition := get_current_mode_definition()
	if not definition.grid_gem_rewards_enabled and not definition.power_ups_enabled:
		return
	if _reward_data.is_empty():
		_reward_spawn_remaining = maxf(_reward_spawn_remaining - delta, 0.0)
		if _reward_spawn_remaining <= 0.0:
			_spawn_random_reward()
		return
	_reward_data["remaining_seconds"] = maxf(
		float(_reward_data.get("remaining_seconds", 0.0)) - delta, 0.0
	)
	if float(_reward_data["remaining_seconds"]) <= 0.0:
		_remove_reward("expired")


func _spawn_random_reward() -> void:
	# A pending stage rebuild clears rewards. Wait for the new grid rather than
	# flashing a reward on the outgoing grid for a single frame.
	if _pending_stage_index >= 0:
		return
	if _active_bomb_indices.is_empty():
		_schedule_next_reward()
		return
	var grid_side := int(get_current_stage_config()["grid_side"])
	var inactive_indices: Array[int] = []
	var stable_active_indices: Array[int] = []
	for bomb_index in grid_side * grid_side:
		if _active_bomb_indices.has(bomb_index):
			if (
				get_bomb_time_remaining(bomb_index)
				>= REWARD_ACTIVE_TARGET_MIN_REMAINING_SECONDS
			):
				stable_active_indices.append(bomb_index)
		else:
			inactive_indices.append(bomb_index)
	var use_inactive := (
		not inactive_indices.is_empty()
		and (stable_active_indices.is_empty() or _random.randf() < 0.75)
	)
	var target_pool := inactive_indices if use_inactive else stable_active_indices
	if target_pool.is_empty():
		# Current stage definitions always have inactive cells, but fail safely if
		# a future fully-active grid has no target with enough visible time left.
		return
	var target_index: int = target_pool[_random.randi_range(0, target_pool.size() - 1)]

	var reward_type := "gem"
	var reward_id := "gems"
	var reward_amount := _roll_gem_reward_amount()
	var display_name := "+%d Gems" % reward_amount
	var unlocked_power_ups: Array[String] = []
	if are_power_ups_enabled_for_run():
		unlocked_power_ups = PowerUpManager.get_enabled_unlocked_ids()
	if not unlocked_power_ups.is_empty() and _random.randf() < POWER_UP_REWARD_CHANCE:
		reward_type = "power_up"
		reward_id = unlocked_power_ups[_random.randi_range(0, unlocked_power_ups.size() - 1)]
		reward_amount = 1
		var definition := PowerUpManager.get_definition(reward_id)
		display_name = definition.display_name if definition != null else "Power-up"
	_place_reward(
		target_index,
		reward_type,
		reward_id,
		display_name,
		REWARD_LIFETIME_SECONDS,
		reward_amount
	)


func _roll_gem_reward_amount() -> int:
	var roll := _random.randf()
	if roll < GEM_REWARD_ONE_CHANCE:
		return 1
	if roll < GEM_REWARD_ONE_CHANCE + GEM_REWARD_TWO_CHANCE:
		return 2
	return 5


func _place_reward(
	bomb_index: int,
	reward_type: String,
	reward_id: String,
	display_name: String,
	duration_seconds: float = REWARD_LIFETIME_SECONDS,
	reward_amount: int = 1
) -> bool:
	var grid_side := int(get_current_stage_config()["grid_side"])
	var mode_definition := get_current_mode_definition()
	if (
		bomb_index < 0
		or bomb_index >= grid_side * grid_side
		or reward_type not in ["gem", "power_up"]
		or not _reward_data.is_empty()
		or (reward_type == "gem" and not mode_definition.grid_gem_rewards_enabled)
		or (reward_type == "power_up" and not are_power_ups_enabled_for_run())
	):
		return false
	_reward_data = {
		"bomb_index": bomb_index,
		"reward_type": reward_type,
		"reward_id": reward_id,
		"display_name": display_name,
		"amount": maxi(reward_amount, 1),
		"duration_seconds": maxf(duration_seconds, 0.1),
		"remaining_seconds": maxf(duration_seconds, 0.1),
	}
	reward_spawned.emit(
		bomb_index,
		reward_type,
		reward_id,
		display_name,
		maxi(reward_amount, 1),
		maxf(duration_seconds, 0.1)
	)
	return true


func _claim_reward() -> void:
	if _reward_data.is_empty():
		return
	var claimed := _reward_data.duplicate(true)
	var bomb_index := int(claimed["bomb_index"])
	var reward_type := str(claimed["reward_type"])
	var reward_id := str(claimed["reward_id"])
	var reward_amount := maxi(int(claimed.get("amount", 1)), 1)
	_reward_data.clear()
	reward_removed.emit(bomb_index, "claimed")
	if reward_type == "gem":
		EconomyManager.earn_gems(reward_amount)
	else:
		if not are_power_ups_enabled_for_run():
			_schedule_next_reward()
			return
		var lives_before_activation := current_lives
		if PowerUpManager.add_quantity(reward_id, reward_amount):
			var did_activate := PowerUpManager.activate_collected_power_up(
				reward_id,
				{
					"active_bomb_count": _active_bomb_indices.size(),
					"scan_target": _get_most_urgent_active_bomb(),
					"current_lives": current_lives,
					"maximum_lives": get_maximum_lives(),
				}
			)
			if (
				did_activate
				and reward_id == "extra_life"
				and lives_before_activation < get_maximum_lives()
			):
				current_lives += 1
				lives_changed.emit(current_lives, get_maximum_lives())
	reward_claimed.emit(bomb_index, reward_type, reward_id)
	_schedule_next_reward()


func _remove_reward(reason: String) -> void:
	if _reward_data.is_empty():
		return
	var bomb_index := int(_reward_data.get("bomb_index", -1))
	_reward_data.clear()
	reward_removed.emit(bomb_index, reason)
	_schedule_next_reward()


func _begin_precision_rest() -> void:
	_clear_bomb_runtime()
	_clear_reward_runtime("precision_rest")
	_active_bomb_indices.clear()
	bomb_layout_changed.emit(
		int(get_current_stage_config()["grid_side"]), get_active_bomb_indices()
	)
	_mode_phase_remaining = PRECISION_REST_SECONDS
	_set_mode_phase("REST")
	mode_phase_changed.emit(_mode_phase_name, _mode_phase_remaining)


func _advance_precision_rest(delta: float) -> void:
	_mode_phase_remaining = maxf(_mode_phase_remaining - maxf(delta, 0.0), 0.0)
	mode_phase_changed.emit(_mode_phase_name, _mode_phase_remaining)
	if _mode_phase_remaining > 0.0:
		return
	_set_mode_phase("ACTIVE")
	_reset_reward_runtime()
	if _pending_stage_index >= 0:
		_apply_pending_stage_change()
	else:
		_build_initial_layout()


func _process_memory_mode(delta: float) -> void:
	_update_resolution_cooldowns(delta)
	if _mode_phase_name not in ["PREVIEW", "INTERMISSION"]:
		return
	_mode_phase_remaining = maxf(_mode_phase_remaining - maxf(delta, 0.0), 0.0)
	mode_phase_changed.emit(_mode_phase_name, _mode_phase_remaining)
	if (
		_mode_phase_name == "INTERMISSION"
		and _memory_completion_visible
		and _mode_phase_remaining <= MEMORY_INACTIVE_PAUSE_SECONDS
	):
		_memory_completion_visible = false
		_emit_all_memory_states("hidden")
	if _mode_phase_remaining > 0.0:
		return
	if _mode_phase_name == "PREVIEW":
		_begin_memory_recall()
	else:
		_begin_memory_pattern(false)


func _begin_memory_pattern(reuse_current_pattern: bool) -> void:
	_clear_bomb_runtime()
	_clear_reward_runtime("memory_pattern")
	var previous_stage := _stage_index
	_sync_stage_to_progress()
	if previous_stage != _stage_index:
		stage_changed.emit(
			int(get_current_stage_config()["stage"]), get_current_stage_config()
		)
	if not reuse_current_pattern or _memory_pattern.is_empty():
		_generate_memory_pattern()
	_memory_revealed.clear()
	_memory_completion_visible = false
	_active_bomb_indices = _memory_pattern.duplicate()
	bomb_layout_changed.emit(
		int(get_current_stage_config()["grid_side"]), get_active_bomb_indices()
	)
	_mode_phase_remaining = get_memory_preview_duration()
	_set_mode_phase("PREVIEW")
	_emit_memory_states("preview")
	mode_phase_changed.emit(_mode_phase_name, _mode_phase_remaining)


func _begin_memory_recall() -> void:
	_mode_phase_remaining = 0.0
	_memory_completion_visible = false
	_set_mode_phase("RECALL")
	_emit_memory_states("hidden")


func _handle_memory_tap(bomb_index: int) -> bool:
	return _handle_memory_taps([bomb_index]) > 0


func _handle_memory_taps(bomb_indices: Array[int]) -> int:
	var grid_side := int(get_current_stage_config()["grid_side"])
	if _mode_phase_name != "RECALL":
		return 0
	var accepted_count := 0
	for bomb_index in bomb_indices:
		if (
			bomb_index < 0
			or bomb_index >= grid_side * grid_side
			or _resolution_cooldowns.has(bomb_index)
		):
			continue
		accepted_count += 1
		if _memory_revealed.has(bomb_index):
			continue
		if _memory_pattern.has(bomb_index):
			_memory_revealed.append(bomb_index)
			memory_cell_state_changed.emit(bomb_index, "correct")
			AudioManager.play_sound("bomb_defused")
		else:
			_resolution_cooldowns[bomb_index] = RESOLUTION_GUARD_SECONDS
			bomb_exploded.emit(bomb_index, "memory_mistake")
			AudioManager.play_sound("bomb_exploded")
			lose_life()
	if (
		current_run_state == RunState.RUNNING
		and _memory_revealed.size() == _memory_pattern.size()
	):
		_complete_memory_pattern()
	return accepted_count


func get_memory_preview_duration() -> float:
	## Shaves only 40 ms per completed level and keeps a generous lower bound,
	## so advanced patterns become brisker without turning into a reaction test.
	return maxf(
		MEMORY_PREVIEW_SECONDS
		- float(maxi(current_score, 0)) * MEMORY_PREVIEW_REDUCTION_PER_LEVEL,
		MEMORY_MINIMUM_PREVIEW_SECONDS
	)


func _complete_memory_pattern() -> void:
	current_score += 1
	score_changed.emit(current_score)
	var gem_amount := _roll_gem_reward_amount()
	EconomyManager.earn_gems(gem_amount)
	memory_pattern_completed.emit(current_score, gem_amount)
	_queue_eligible_stage_change()
	_mode_phase_remaining = MEMORY_INTERMISSION_SECONDS
	_memory_completion_visible = true
	_set_mode_phase("INTERMISSION")
	# Keep the completed pattern lit long enough for the final tap to render,
	# then _process_memory_mode clears the board before the next preview.
	_emit_memory_states("correct")
	mode_phase_changed.emit(_mode_phase_name, _mode_phase_remaining)


func _generate_memory_pattern() -> void:
	_memory_previous_pattern = _memory_pattern.duplicate()
	var config := get_current_stage_config()
	var cell_count := int(config["grid_side"]) ** 2
	var target_count := mini(int(config["active_bombs"]), cell_count)
	var generated: Array[int] = []
	for attempt in 8:
		var candidates: Array[int] = []
		for cell_index in cell_count:
			candidates.append(cell_index)
		for candidate_index in range(candidates.size() - 1, 0, -1):
			var swap_index := _random.randi_range(0, candidate_index)
			var held_value := candidates[candidate_index]
			candidates[candidate_index] = candidates[swap_index]
			candidates[swap_index] = held_value
		generated = candidates.slice(0, target_count)
		generated.sort()
		if generated != _memory_previous_pattern:
			break
	_memory_pattern = generated


func _emit_memory_states(target_state: String) -> void:
	var cell_count := int(get_current_stage_config()["grid_side"]) ** 2
	for bomb_index in cell_count:
		var state := "hidden"
		if _memory_pattern.has(bomb_index):
			state = "correct" if _memory_revealed.has(bomb_index) else target_state
		memory_cell_state_changed.emit(bomb_index, state)


func _emit_all_memory_states(target_state: String) -> void:
	var cell_count := int(get_current_stage_config()["grid_side"]) ** 2
	for bomb_index in cell_count:
		memory_cell_state_changed.emit(bomb_index, target_state)


func _reset_special_mode_runtime() -> void:
	_mode_phase_remaining = 0.0
	_phase_before_pause = get_current_mode_definition().initial_phase_name
	_memory_pattern.clear()
	_memory_previous_pattern.clear()
	_memory_revealed.clear()
	_memory_completion_visible = false


func _get_mode_progress() -> int:
	return current_score if current_mode_id == "memory" else current_defusals


func _get_stage_definitions() -> Array[GameStageDefinition]:
	var definition := get_current_mode_definition()
	return definition.stages if definition != null else []


func _advance_run_timer(delta: float) -> bool:
	var total_seconds := get_current_mode_definition().run_duration_seconds
	if total_seconds <= 0.0:
		return false
	_run_time_remaining = maxf(_run_time_remaining - maxf(delta, 0.0), 0.0)
	run_timer_changed.emit(_run_time_remaining, total_seconds)
	if _run_time_remaining <= 0.0:
		finish_run("time_up")
		return true
	return false


func _set_mode_phase(phase_name: String) -> void:
	var safe_name := phase_name.strip_edges().to_upper()
	if safe_name.is_empty() or _mode_phase_name == safe_name:
		return
	_mode_phase_name = safe_name
	mode_phase_changed.emit(_mode_phase_name, _run_time_remaining)
