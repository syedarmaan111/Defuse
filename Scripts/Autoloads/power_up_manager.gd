extends Node

## PowerUpManager owns permanent unlocks and consumable inventory quantities.

signal power_up_unlocked(power_up_id: String)
signal power_up_quantity_changed(power_up_id: String, quantity: int)
signal inventory_updated()

const CATALOG: ContentCatalog = preload("res://Resources/Content/ContentCatalog.tres")

var _known_unlocked_ids: Array[String] = []
var _known_quantities: Dictionary = {}


func _ready() -> void:
	_capture_snapshot(SaveManager.get_snapshot(), false)
	SaveManager.save_loaded.connect(_on_save_snapshot)
	SaveManager.save_changed.connect(_on_save_snapshot)


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
	if amount <= 0 or not is_unlocked(power_up_id):
		return false
	var current_quantity := get_quantity(power_up_id)
	if current_quantity < amount:
		return false
	return SaveManager.set_power_up_quantity(power_up_id, current_quantity - amount)


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


func _on_save_snapshot(snapshot: Dictionary) -> void:
	_capture_snapshot(snapshot, true)


func _capture_snapshot(snapshot: Dictionary, emit_changes: bool) -> void:
	var data := SaveData.from_dictionary(snapshot)
	var next_unlocked := data.unlocked_powerup_ids
	var next_quantities := data.owned_power_up_quantities
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
	_known_unlocked_ids = next_unlocked
	_known_quantities = next_quantities.duplicate(true)
