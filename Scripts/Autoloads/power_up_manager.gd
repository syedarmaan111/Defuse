extends Node

## PowerUpManager owns permanent unlocks and consumable inventory quantities.

signal power_up_unlocked(power_up_id: String)
signal power_up_quantity_changed(power_up_id: String, quantity: int)
signal inventory_updated()
signal power_up_activated(power_up_id: String, context: Dictionary)
signal timed_effect_changed(power_up_id: String, is_active: bool, remaining_seconds: float)
signal scan_target_changed(bomb_index: int)
signal unlock_choices_changed(pending_count: int)
signal power_up_enabled_changed(power_up_id: String, is_enabled: bool)

const CATALOG: ContentCatalog = preload("res://Resources/Content/ContentCatalog.tres")
const SLOW_MOTION_MIN_DURATION := 8.0
const SLOW_MOTION_RECOVERY_DURATION := 2.0
const SCAN_MIN_DURATION := 5.0
const CHAIN_DEFUSE_DURATION := 6.0

var _known_unlocked_ids: Array[String] = []
var _known_quantities: Dictionary = {}
var _slow_motion_remaining := 0.0
var _slow_motion_recovery_remaining := 0.0
var _scan_remaining := 0.0
var _scan_target := -1
var _combo_boost_remaining := 0.0
var _chain_defuse_remaining := 0.0
var _defusal_chain_count := 0
var _defusal_chain_window := 0.0
var _known_pending_unlock_choices := 0
var _disabled_power_up_ids: Array[String] = []


func _ready() -> void:
	_capture_snapshot(SaveManager.get_snapshot(), false)
	SaveManager.save_loaded.connect(_on_save_snapshot)
	SaveManager.save_changed.connect(_on_save_snapshot)
	set_process(true)


func _process(delta: float) -> void:
	if not has_node("/root/GameManager") or GameManager.get_run_state_name() != "running":
		return
	_defusal_chain_window = maxf(_defusal_chain_window - delta, 0.0)
	if _defusal_chain_window <= 0.0:
		_defusal_chain_count = 0
	_advance_slow_motion(delta)
	_combo_boost_remaining = _advance_timed_effect(
		"combo_boost", _combo_boost_remaining, delta
	)
	_chain_defuse_remaining = _advance_timed_effect(
		"chain_defuse", _chain_defuse_remaining, delta
	)
	var previous_scan_remaining := _scan_remaining
	_scan_remaining = maxf(_scan_remaining - delta, 0.0)
	if previous_scan_remaining > 0.0 and _scan_remaining <= 0.0:
		_scan_target = -1
		scan_target_changed.emit(-1)
		timed_effect_changed.emit("scan", false, 0.0)


func get_definition(power_up_id: String) -> PowerUpDefinition:
	return CATALOG.get_power_up(power_up_id)


func is_unlocked(power_up_id: String) -> bool:
	return CATALOG.get_power_up(power_up_id) != null and SaveManager.get_unlocked_power_up_ids().has(power_up_id)


func get_unlocked_ids() -> Array[String]:
	var result: Array[String] = []
	for power_up_id in SaveManager.get_unlocked_power_up_ids():
		if CATALOG.get_power_up(power_up_id) != null:
			result.append(power_up_id)
	return result


func get_enabled_unlocked_ids() -> Array[String]:
	var result: Array[String] = []
	for power_up_id in get_unlocked_ids():
		if is_power_up_enabled(power_up_id):
			result.append(power_up_id)
	return result


func is_power_up_enabled(power_up_id: String) -> bool:
	return CATALOG.get_power_up(power_up_id) != null and not _disabled_power_up_ids.has(
		power_up_id
	)


func set_power_up_enabled(power_up_id: String, is_enabled: bool) -> bool:
	if CATALOG.get_power_up(power_up_id) == null:
		return false
	var was_enabled := is_power_up_enabled(power_up_id)
	if was_enabled == is_enabled:
		return true
	if is_enabled:
		_disabled_power_up_ids.erase(power_up_id)
	else:
		_disabled_power_up_ids.append(power_up_id)
		_stop_active_effect(power_up_id)
	power_up_enabled_changed.emit(power_up_id, is_enabled)
	return true


func get_quantity(power_up_id: String) -> int:
	if CATALOG.get_power_up(power_up_id) == null:
		return 0
	return SaveManager.get_power_up_quantity(power_up_id)


func unlock(power_up_id: String, starting_quantity: int = 0) -> bool:
	var definition := CATALOG.get_power_up(power_up_id)
	if definition == null or not definition.is_available or starting_quantity < 0:
		return false
	return SaveManager.grant_power_up(power_up_id, starting_quantity)


func add_quantity(power_up_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not is_unlocked(power_up_id):
		return false
	return SaveManager.set_power_up_quantity(power_up_id, get_quantity(power_up_id) + amount)


func consume(power_up_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not is_unlocked(power_up_id) or not is_power_up_enabled(power_up_id):
		return false
	var current_quantity := get_quantity(power_up_id)
	if current_quantity < amount:
		return false
	return SaveManager.set_power_up_quantity(power_up_id, current_quantity - amount)


func reset_run_effects() -> void:
	var active_effects := {
		"slow_motion": _slow_motion_remaining > 0.0 or _slow_motion_recovery_remaining > 0.0,
		"scan": _scan_remaining > 0.0,
		"combo_boost": _combo_boost_remaining > 0.0,
		"chain_defuse": _chain_defuse_remaining > 0.0,
	}
	_slow_motion_remaining = 0.0
	_slow_motion_recovery_remaining = 0.0
	_scan_remaining = 0.0
	_scan_target = -1
	_combo_boost_remaining = 0.0
	_chain_defuse_remaining = 0.0
	_defusal_chain_count = 0
	_defusal_chain_window = 0.0
	scan_target_changed.emit(-1)
	for power_up_id in active_effects:
		if bool(active_effects[power_up_id]):
			timed_effect_changed.emit(power_up_id, false, 0.0)


func get_timer_speed_multiplier() -> float:
	var definition := get_definition("slow_motion")
	var slowed_multiplier := clampf(
		definition.effect_strength if definition != null else 0.35, 0.1, 1.0
	)
	if _slow_motion_remaining > 0.0:
		return slowed_multiplier
	if _slow_motion_recovery_remaining > 0.0:
		var recovery_progress := 1.0 - (
			_slow_motion_recovery_remaining / SLOW_MOTION_RECOVERY_DURATION
		)
		return lerpf(slowed_multiplier, 1.0, smoothstep(0.0, 1.0, recovery_progress))
	return 1.0


func get_timed_effect_remaining(power_up_id: String) -> float:
	match power_up_id:
		"slow_motion":
			return _slow_motion_remaining + _slow_motion_recovery_remaining
		"scan":
			return _scan_remaining
		"combo_boost":
			return _combo_boost_remaining
		"chain_defuse":
			return _chain_defuse_remaining
	return 0.0


func get_score_multiplier() -> int:
	if _combo_boost_remaining <= 0.0:
		return 1
	var definition := get_definition("combo_boost")
	return maxi(roundi(definition.effect_strength if definition != null else 2.0), 1)


func register_successful_defusal() -> void:
	if _defusal_chain_window > 0.0:
		_defusal_chain_count += 1
	else:
		_defusal_chain_count = 1
	_defusal_chain_window = 2.0
	if _defusal_chain_count >= 4 and _combo_boost_remaining <= 0.0:
		_activate_timed_effect("combo_boost")


func try_activate_chain_defuse(active_bomb_count: int) -> bool:
	if active_bomb_count <= 0:
		return false
	if _chain_defuse_remaining > 0.0:
		return true
	if not consume("chain_defuse"):
		return false
	_chain_defuse_remaining = CHAIN_DEFUSE_DURATION
	_emit_activation(
		"chain_defuse",
		{
			"active_bomb_count": active_bomb_count,
			"duration_seconds": CHAIN_DEFUSE_DURATION,
		}
	)
	timed_effect_changed.emit("chain_defuse", true, CHAIN_DEFUSE_DURATION)
	return true


func try_block_explosion(bomb_index: int, reason: String) -> bool:
	if not consume("shield"):
		return false
	_emit_activation("shield", {"bomb_index": bomb_index, "reason": reason})
	return true


func try_restore_life(current_lives: int, maximum_lives: int) -> bool:
	if current_lives >= maximum_lives or not consume("extra_life"):
		return false
	_emit_activation("extra_life", {"restored_to": current_lives + 1})
	return true


func evaluate_timer_pressure(
	active_indices: Array[int], remaining_times: Dictionary, timer_durations: Dictionary
) -> void:
	if active_indices.is_empty():
		return
	var most_urgent_index := -1
	var most_urgent_ratio := 1.1
	var critical_count := 0
	for bomb_index in active_indices:
		var duration := float(timer_durations.get(bomb_index, 0.0))
		if duration <= 0.0:
			continue
		var ratio := float(remaining_times.get(bomb_index, duration)) / duration
		if ratio < most_urgent_ratio:
			most_urgent_ratio = ratio
			most_urgent_index = bomb_index
		if ratio <= 0.32:
			critical_count += 1

	if active_indices.size() >= 2 and most_urgent_ratio <= 0.5:
		if _scan_remaining <= 0.0 and _activate_timed_effect("scan"):
			_scan_target = most_urgent_index
			scan_target_changed.emit(_scan_target)
		elif _scan_remaining > 0.0 and _scan_target != most_urgent_index:
			_scan_target = most_urgent_index
			scan_target_changed.emit(_scan_target)
	if critical_count >= 2 and _slow_motion_remaining <= 0.0:
		_activate_timed_effect("slow_motion")


func _activate_timed_effect(power_up_id: String) -> bool:
	if not consume(power_up_id):
		return false
	var definition := get_definition(power_up_id)
	var duration := definition.duration_seconds if definition != null else 0.0
	match power_up_id:
		"slow_motion":
			_slow_motion_remaining = maxf(duration, SLOW_MOTION_MIN_DURATION)
			_slow_motion_recovery_remaining = 0.0
		"scan":
			_scan_remaining = maxf(duration, SCAN_MIN_DURATION)
		"combo_boost":
			_combo_boost_remaining = maxf(duration, 8.0)
	var actual_duration := get_timed_effect_remaining(power_up_id)
	_emit_activation(power_up_id, {"duration_seconds": actual_duration})
	timed_effect_changed.emit(power_up_id, true, actual_duration)
	return true


func _advance_slow_motion(delta: float) -> void:
	if _slow_motion_remaining > 0.0:
		_slow_motion_remaining = maxf(_slow_motion_remaining - delta, 0.0)
		if _slow_motion_remaining <= 0.0:
			_slow_motion_recovery_remaining = SLOW_MOTION_RECOVERY_DURATION
		return
	if _slow_motion_recovery_remaining <= 0.0:
		return
	_slow_motion_recovery_remaining = maxf(_slow_motion_recovery_remaining - delta, 0.0)
	if _slow_motion_recovery_remaining <= 0.0:
		timed_effect_changed.emit("slow_motion", false, 0.0)


func _advance_timed_effect(power_up_id: String, remaining: float, delta: float) -> float:
	if remaining <= 0.0:
		return 0.0
	var next_remaining := maxf(remaining - delta, 0.0)
	if next_remaining <= 0.0:
		timed_effect_changed.emit(power_up_id, false, 0.0)
	return next_remaining


func _emit_activation(power_up_id: String, context: Dictionary) -> void:
	power_up_activated.emit(power_up_id, context)


func _stop_active_effect(power_up_id: String) -> void:
	match power_up_id:
		"slow_motion":
			if _slow_motion_remaining > 0.0 or _slow_motion_recovery_remaining > 0.0:
				_slow_motion_remaining = 0.0
				_slow_motion_recovery_remaining = 0.0
				timed_effect_changed.emit(power_up_id, false, 0.0)
		"scan":
			if _scan_remaining > 0.0 or _scan_target >= 0:
				_scan_remaining = 0.0
				_scan_target = -1
				scan_target_changed.emit(-1)
				timed_effect_changed.emit(power_up_id, false, 0.0)
		"combo_boost":
			if _combo_boost_remaining > 0.0:
				_combo_boost_remaining = 0.0
				timed_effect_changed.emit(power_up_id, false, 0.0)
		"chain_defuse":
			if _chain_defuse_remaining > 0.0:
				_chain_defuse_remaining = 0.0
				timed_effect_changed.emit(power_up_id, false, 0.0)


func get_checkpoint_candidates() -> Array[PowerUpDefinition]:
	var result: Array[PowerUpDefinition] = []
	for definition in CATALOG.power_ups:
		if (
			definition != null
			and definition.is_available
			and not is_unlocked(definition.content_id)
			and definition.has_acquisition_type(
				AcquisitionOption.AcquisitionType.LIFETIME_SCORE_CHECKPOINT
			)
		):
			result.append(definition)
	return result


func get_pending_unlock_choice_count() -> int:
	return SaveManager.get_pending_power_up_unlock_choices()


func get_checkpoint_interval() -> int:
	var interval := 0
	for definition in CATALOG.power_ups:
		if definition == null:
			continue
		for option in definition.acquisition_options:
			if (
				option != null
				and option.acquisition_type
					== AcquisitionOption.AcquisitionType.LIFETIME_SCORE_CHECKPOINT
			):
				interval = (
					option.lifetime_score_required
					if interval == 0
					else mini(interval, option.lifetime_score_required)
				)
	return interval


func get_next_checkpoint_threshold() -> int:
	var interval := get_checkpoint_interval()
	if interval <= 0:
		return 0
	var completed_checkpoints := floori(
		float(SaveManager.get_lifetime_defusals()) / float(interval)
	)
	return (completed_checkpoints + 1) * interval


func queue_lifetime_checkpoint_choices() -> int:
	var interval := get_checkpoint_interval()
	if interval <= 0:
		return 0
	var candidates := get_checkpoint_candidates()
	var available_slots := candidates.size() - get_pending_unlock_choice_count()
	if available_slots <= 0:
		return 0
	var claimed := SaveManager.get_claimed_power_up_checkpoints()
	var reached_total := SaveManager.get_lifetime_defusals()
	var new_checkpoints: Array[int] = []
	var checkpoint := interval
	while checkpoint <= reached_total and new_checkpoints.size() < available_slots:
		if not claimed.has(checkpoint):
			new_checkpoints.append(checkpoint)
		checkpoint += interval
	return SaveManager.queue_power_up_unlock_choices(new_checkpoints)


func claim_checkpoint_power_up(power_up_id: String) -> bool:
	if get_pending_unlock_choice_count() <= 0:
		return false
	var is_candidate := false
	for definition in get_checkpoint_candidates():
		if definition.content_id == power_up_id:
			is_candidate = true
			break
	if not is_candidate:
		return false
	return SaveManager.claim_power_up_unlock_choice(power_up_id)


func _on_save_snapshot(snapshot: Dictionary) -> void:
	_capture_snapshot(snapshot, true)


func _capture_snapshot(snapshot: Dictionary, emit_changes: bool) -> void:
	var data := SaveData.from_dictionary(snapshot)
	var next_unlocked := data.unlocked_powerup_ids
	var next_quantities := data.owned_power_up_quantities
	var next_pending_choices := data.pending_powerup_unlock_choices
	var did_change := next_unlocked != _known_unlocked_ids or next_quantities != _known_quantities
	if emit_changes and did_change:
		for power_up_id in next_unlocked:
			if not _known_unlocked_ids.has(power_up_id) and CATALOG.get_power_up(power_up_id) != null:
				power_up_unlocked.emit(power_up_id)
		var quantity_ids := _known_quantities.keys()
		for power_up_id in next_quantities:
			if not quantity_ids.has(power_up_id):
				quantity_ids.append(power_up_id)
		for power_up_id in quantity_ids:
			var old_quantity := int(_known_quantities.get(power_up_id, 0))
			var next_quantity := int(next_quantities.get(power_up_id, 0))
			if old_quantity != next_quantity and CATALOG.get_power_up(str(power_up_id)) != null:
				power_up_quantity_changed.emit(str(power_up_id), next_quantity)
		inventory_updated.emit()
	if emit_changes and next_pending_choices != _known_pending_unlock_choices:
		unlock_choices_changed.emit(next_pending_choices)
	_known_unlocked_ids = next_unlocked
	_known_quantities = next_quantities.duplicate(true)
	_known_pending_unlock_choices = next_pending_choices
