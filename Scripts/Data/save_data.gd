extends RefCounted
class_name SaveData

## SaveData is the validated, versioned progression record shared by local and
## cloud persistence. Stable IDs keep future catalog additions migration-safe.

const CURRENT_VERSION := 2
const DEFAULT_SKIN_ID := "default_bomb"

var save_version: int = CURRENT_VERSION
var save_revision: int = 0
var modified_at_unix: int = 0
var best_score: int = 0
var lifetime_defusal_score: int = 0
var currencies: Dictionary = {"gems": 0}
var owned_skin_ids: Array[String] = [DEFAULT_SKIN_ID]
var equipped_skin_id: String = DEFAULT_SKIN_ID
var purchased_content_ids: Array[String] = []
var unlocked_powerup_ids: Array[String] = []
var owned_power_up_quantities: Dictionary = {}
var claimed_powerup_checkpoints: Array[int] = []
var pending_powerup_unlock_choices: int = 0
var settings: Dictionary = {}
var completed_run_count: int = 0
var pending_interstitial: bool = false
var cloud_sync_pending: bool = false


static func from_dictionary(source: Dictionary) -> SaveData:
	## Migrates legacy keys, validates every value, and returns safe defaults for
	## missing or malformed fields. Call this for both local and cloud input.
	var migrated := _migrate_legacy_dictionary(source)
	var data := SaveData.new()

	data.save_revision = _non_negative_int(migrated.get("save_revision", 0))
	data.modified_at_unix = _non_negative_int(migrated.get("modified_at_unix", 0))
	data.best_score = _non_negative_int(migrated.get("best_score", 0))
	data.lifetime_defusal_score = _non_negative_int(
		migrated.get("lifetime_defusal_score", 0)
	)

	var source_currencies = migrated.get("currencies", {})
	if typeof(source_currencies) == TYPE_DICTIONARY:
		data.currencies["gems"] = _non_negative_int(source_currencies.get("gems", 0))

	data.owned_skin_ids = _string_array(migrated.get("owned_skin_ids", []))
	if not data.owned_skin_ids.has(DEFAULT_SKIN_ID):
		data.owned_skin_ids.push_front(DEFAULT_SKIN_ID)

	var equipped_candidate := _safe_id(
		migrated.get("equipped_skin_id", DEFAULT_SKIN_ID), DEFAULT_SKIN_ID
	)
	data.equipped_skin_id = (
		equipped_candidate if data.owned_skin_ids.has(equipped_candidate) else DEFAULT_SKIN_ID
	)

	data.purchased_content_ids = _string_array(
		migrated.get("purchased_content_ids", [])
	)
	data.unlocked_powerup_ids = _string_array(
		migrated.get("unlocked_powerup_ids", [])
	)
	data.owned_power_up_quantities = _quantity_dictionary(
		migrated.get("owned_power_up_quantities", {})
	)
	data.claimed_powerup_checkpoints = _non_negative_int_array(
		migrated.get("claimed_powerup_checkpoints", [])
	)
	data.pending_powerup_unlock_choices = _non_negative_int(
		migrated.get("pending_powerup_unlock_choices", 0)
	)

	var source_settings = migrated.get("settings", {})
	if typeof(source_settings) == TYPE_DICTIONARY:
		data.settings = source_settings.duplicate(true)

	data.completed_run_count = _non_negative_int(migrated.get("completed_run_count", 0))
	data.pending_interstitial = _safe_bool(migrated.get("pending_interstitial", false))
	data.cloud_sync_pending = _safe_bool(migrated.get("cloud_sync_pending", false))
	return data


static func is_supported_source(source: Dictionary) -> bool:
	## Version 0 is the legacy unversioned format. Future formats must be migrated
	## by a newer build rather than being partially interpreted by this one.
	var version = source.get("save_version", 0)
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return int(version) >= 0 and int(version) <= CURRENT_VERSION


func to_dictionary(include_local_state: bool = true) -> Dictionary:
	## Produces JSON-safe data. Cloud snapshots omit the device-local queue flag.
	var result := {
		"save_version": CURRENT_VERSION,
		"save_revision": save_revision,
		"modified_at_unix": modified_at_unix,
		"best_score": best_score,
		"lifetime_defusal_score": lifetime_defusal_score,
		"currencies": currencies.duplicate(true),
		"owned_skin_ids": owned_skin_ids.duplicate(),
		"equipped_skin_id": equipped_skin_id,
		"purchased_content_ids": purchased_content_ids.duplicate(),
		"unlocked_powerup_ids": unlocked_powerup_ids.duplicate(),
		"owned_power_up_quantities": owned_power_up_quantities.duplicate(true),
		"claimed_powerup_checkpoints": claimed_powerup_checkpoints.duplicate(),
		"pending_powerup_unlock_choices": pending_powerup_unlock_choices,
		"settings": settings.duplicate(true),
		"completed_run_count": completed_run_count,
		"pending_interstitial": pending_interstitial,
	}
	if include_local_state:
		result["cloud_sync_pending"] = cloud_sync_pending
	return result


static func _migrate_legacy_dictionary(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	var source_version := _non_negative_int(migrated.get("save_version", 0))
	if source_version < 2:
		if not migrated.has("currencies"):
			migrated["currencies"] = {"gems": _non_negative_int(migrated.get("total_gems", 0))}

		var legacy_skin := _safe_id(
			migrated.get("selected_skin", DEFAULT_SKIN_ID), DEFAULT_SKIN_ID
		)
		if not migrated.has("equipped_skin_id"):
			migrated["equipped_skin_id"] = legacy_skin
		if not migrated.has("owned_skin_ids"):
			migrated["owned_skin_ids"] = [DEFAULT_SKIN_ID]
			if legacy_skin != DEFAULT_SKIN_ID:
				migrated["owned_skin_ids"].append(legacy_skin)

	migrated["save_version"] = CURRENT_VERSION
	return migrated


static func _non_negative_int(value: Variant, fallback: int = 0) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	return max(int(value), 0)


static func _safe_id(value: Variant, fallback: String) -> String:
	if typeof(value) != TYPE_STRING or value.strip_edges().is_empty():
		return fallback
	return value


static func _safe_bool(value: Variant, fallback: bool = false) -> bool:
	return value if typeof(value) == TYPE_BOOL else fallback


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) == TYPE_STRING and not entry.strip_edges().is_empty() and not result.has(entry):
			result.append(entry)
	return result


static func _non_negative_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) in [TYPE_INT, TYPE_FLOAT]:
			var safe_entry: int = max(int(entry), 0)
			if not result.has(safe_entry):
				result.append(safe_entry)
	return result


static func _quantity_dictionary(value: Variant) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value:
		if typeof(key) != TYPE_STRING or key.strip_edges().is_empty():
			continue
		var quantity := _non_negative_int(value[key])
		if quantity > 0:
			result[key] = quantity
	return result
