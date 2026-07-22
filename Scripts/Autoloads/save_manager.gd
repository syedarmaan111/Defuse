extends Node

## SaveManager owns the validated local cache and exposes progression through a
## stable API. Local mutations increment the revision and persist a cloud queue.

signal save_loaded(snapshot: Dictionary)
signal save_changed(snapshot: Dictionary)
signal save_error(error_code: String)

const SAVE_PATH := "user://save_data.dat"
const LEGACY_SAVE_PATH := "user://save_data.json"
const SAVE_PASSWORD := "defuse-local-cache-v2"

var _data := SaveData.new()
var _has_persisted_save := false


func _ready() -> void:
	load_save()


func load_save() -> void:
	## Prefers the encrypted versioned cache, then migrates the Milestone 1 JSON.
	var loaded_dictionary: Dictionary = {}
	var did_load := false

	if FileAccess.file_exists(SAVE_PATH):
		var encrypted_file := FileAccess.open_encrypted_with_pass(
			SAVE_PATH, FileAccess.READ, SAVE_PASSWORD
		)
		if encrypted_file != null:
			loaded_dictionary = decode_save_envelope(encrypted_file.get_as_text())
			did_load = not loaded_dictionary.is_empty()

	# The legacy file is migration input only. Once a versioned cache exists, a
	# corrupt current save must never silently roll progress back to stale JSON.
	if not FileAccess.file_exists(SAVE_PATH) and FileAccess.file_exists(LEGACY_SAVE_PATH):
		var legacy_file := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
		if legacy_file != null:
			var legacy_value = JSON.parse_string(legacy_file.get_as_text())
			if (
				typeof(legacy_value) == TYPE_DICTIONARY
				and SaveData.is_supported_source(legacy_value)
			):
				loaded_dictionary = legacy_value
				did_load = true

	_data = SaveData.from_dictionary(loaded_dictionary if did_load else {})
	_has_persisted_save = did_load
	if did_load:
		# Rewriting once upgrades legacy/plain data to the current encrypted format.
		_write_local_cache()
	elif FileAccess.file_exists(SAVE_PATH):
		save_error.emit("local_save_invalid")

	save_loaded.emit(get_snapshot())


func save_now() -> bool:
	## Persists the current record without creating a new logical revision.
	return _write_local_cache()


func get_snapshot(include_local_state: bool = true) -> Dictionary:
	return _data.to_dictionary(include_local_state)


func get_cloud_bytes() -> PackedByteArray:
	return encode_save_envelope(_data.to_dictionary(false)).to_utf8_buffer()


func has_persisted_save() -> bool:
	## Fresh-install detection lets a valid cloud snapshot restore immediately.
	return _has_persisted_save


func apply_cloud_snapshot(source: Dictionary) -> bool:
	## Replaces local state with a validated cloud record without incrementing it.
	if source.is_empty() or not SaveData.is_supported_source(source):
		return false
	_data = SaveData.from_dictionary(source)
	_data.cloud_sync_pending = false
	if not _write_local_cache():
		return false
	save_changed.emit(get_snapshot())
	return true


func replace_with_local_snapshot(source: Dictionary) -> bool:
	## Applies a user-selected local branch and keeps it queued for cloud upload.
	if source.is_empty() or not SaveData.is_supported_source(source):
		return false
	_data = SaveData.from_dictionary(source)
	_data.cloud_sync_pending = true
	if not _write_local_cache():
		return false
	save_changed.emit(get_snapshot())
	return true


func is_cloud_sync_pending() -> bool:
	return _data.cloud_sync_pending


func mark_cloud_sync_complete(uploaded_revision: int) -> void:
	## Clears only the revision that was uploaded; a newer edit stays queued.
	if _data.save_revision != uploaded_revision:
		return
	_data.cloud_sync_pending = false
	_write_local_cache()


func get_best_score() -> int:
	return _data.best_score


func set_best_score(value: int) -> void:
	var safe_value: int = max(value, 0)
	if _data.best_score == safe_value:
		return
	_data.best_score = safe_value
	_commit_local_change()


func get_lifetime_defusals() -> int:
	return _data.lifetime_defusal_score


func add_lifetime_defusals(amount: int = 1) -> bool:
	if amount <= 0:
		return false
	_data.lifetime_defusal_score += amount
	_commit_local_change()
	return true


func get_total_gems() -> int:
	return int(_data.currencies.get("gems", 0))


func set_total_gems(value: int) -> bool:
	## Compatibility wrapper for older UI code; EconomyManager is the owner.
	return set_currency_balance("gems", value)


func get_currency_balance(currency_id: String) -> int:
	if currency_id != "gems":
		return 0
	return int(_data.currencies.get(currency_id, 0))


func set_currency_balance(currency_id: String, value: int) -> bool:
	## Commits one validated currency mutation and therefore one cloud revision.
	if currency_id != "gems":
		return false
	var safe_value: int = max(value, 0)
	if get_currency_balance(currency_id) == safe_value:
		return false
	_data.currencies[currency_id] = safe_value
	_commit_local_change()
	return true


func get_selected_skin() -> String:
	return _data.equipped_skin_id


func get_owned_skin_ids() -> Array[String]:
	return _data.owned_skin_ids.duplicate()


func grant_skin(skin_id: String) -> bool:
	var safe_id := skin_id.strip_edges()
	if safe_id.is_empty() or _data.owned_skin_ids.has(safe_id):
		return false
	_data.owned_skin_ids.append(safe_id)
	_commit_local_change()
	return true


func purchase_skin_with_gems(skin_id: String, gem_cost: int) -> bool:
	## Debits Gems and grants ownership in one revision so a crash cannot leave a
	## player charged without the skin. ShopManager validates catalog metadata.
	var safe_id := skin_id.strip_edges()
	if (
		safe_id.is_empty()
		or gem_cost <= 0
		or _data.owned_skin_ids.has(safe_id)
		or get_currency_balance("gems") < gem_cost
	):
		return false
	_data.currencies["gems"] = get_currency_balance("gems") - gem_cost
	_data.owned_skin_ids.append(safe_id)
	_commit_local_change()
	return true


func set_selected_skin(skin_id: String) -> bool:
	## Equipping never grants ownership; SkinManager validates catalog membership.
	var safe_id := skin_id.strip_edges()
	if safe_id.is_empty() or _data.equipped_skin_id == safe_id:
		return false
	if not _data.owned_skin_ids.has(safe_id):
		return false
	_data.equipped_skin_id = safe_id
	_commit_local_change()
	return true


func get_unlocked_power_up_ids() -> Array[String]:
	return _data.unlocked_powerup_ids.duplicate()


func get_claimed_power_up_checkpoints() -> Array[int]:
	return _data.claimed_powerup_checkpoints.duplicate()


func get_pending_power_up_unlock_choices() -> int:
	return _data.pending_powerup_unlock_choices


func get_power_up_quantity(power_up_id: String) -> int:
	return int(_data.owned_power_up_quantities.get(power_up_id, 0))


func grant_power_up(power_up_id: String, quantity: int = 0) -> bool:
	## Unlock and an optional starting quantity are saved atomically.
	var safe_id := power_up_id.strip_edges()
	if safe_id.is_empty() or quantity < 0:
		return false
	var changed := false
	if not _data.unlocked_powerup_ids.has(safe_id):
		_data.unlocked_powerup_ids.append(safe_id)
		changed = true
	if quantity > 0:
		_data.owned_power_up_quantities[safe_id] = get_power_up_quantity(safe_id) + quantity
		changed = true
	if not changed:
		return false
	_commit_local_change()
	return true


func grant_power_ups(power_up_ids: Array[String]) -> bool:
	## Grants a checkpoint batch in one save revision and one cloud-sync update.
	var changed := false
	for power_up_id in power_up_ids:
		var safe_id := power_up_id.strip_edges()
		if safe_id.is_empty() or _data.unlocked_powerup_ids.has(safe_id):
			continue
		_data.unlocked_powerup_ids.append(safe_id)
		changed = true
	if not changed:
		return false
	_commit_local_change()
	return true


func queue_power_up_unlock_choices(checkpoints: Array[int]) -> int:
	## Marks newly reached lifetime checkpoints and persists their choices once.
	var added_count := 0
	for checkpoint in checkpoints:
		if checkpoint <= 0 or _data.claimed_powerup_checkpoints.has(checkpoint):
			continue
		_data.claimed_powerup_checkpoints.append(checkpoint)
		added_count += 1
	if added_count == 0:
		return 0
	_data.claimed_powerup_checkpoints.sort()
	_data.pending_powerup_unlock_choices += added_count
	_commit_local_change()
	return added_count


func claim_power_up_unlock_choice(power_up_id: String) -> bool:
	## Unlocks one choice and consumes one queued checkpoint in one revision.
	var safe_id := power_up_id.strip_edges()
	if (
		safe_id.is_empty()
		or _data.pending_powerup_unlock_choices <= 0
		or _data.unlocked_powerup_ids.has(safe_id)
	):
		return false
	_data.unlocked_powerup_ids.append(safe_id)
	_data.pending_powerup_unlock_choices -= 1
	_commit_local_change()
	return true


func set_power_up_quantity(power_up_id: String, quantity: int) -> bool:
	var safe_id := power_up_id.strip_edges()
	if safe_id.is_empty() or quantity < 0 or not _data.unlocked_powerup_ids.has(safe_id):
		return false
	if get_power_up_quantity(safe_id) == quantity:
		return false
	if quantity == 0:
		_data.owned_power_up_quantities.erase(safe_id)
	else:
		_data.owned_power_up_quantities[safe_id] = quantity
	_commit_local_change()
	return true


func get_purchased_content_ids() -> Array[String]:
	return _data.purchased_content_ids.duplicate()


func record_purchased_content(content_id: String) -> bool:
	var safe_id := content_id.strip_edges()
	if safe_id.is_empty() or _data.purchased_content_ids.has(safe_id):
		return false
	_data.purchased_content_ids.append(safe_id)
	_commit_local_change()
	return true


func encode_save_envelope(snapshot: Dictionary) -> String:
	## The checksum detects corruption before untrusted disk/cloud JSON is applied.
	var payload_json := JSON.stringify(snapshot)
	return JSON.stringify({
		"payload": payload_json,
		"checksum": payload_json.sha256_text(),
	})


func decode_save_envelope(envelope_text: String) -> Dictionary:
	var envelope = JSON.parse_string(envelope_text)
	if typeof(envelope) != TYPE_DICTIONARY:
		return {}
	var payload_json = envelope.get("payload", "")
	var checksum = envelope.get("checksum", "")
	if typeof(payload_json) != TYPE_STRING or typeof(checksum) != TYPE_STRING:
		return {}
	if payload_json.sha256_text() != checksum:
		return {}
	var payload = JSON.parse_string(payload_json)
	if typeof(payload) != TYPE_DICTIONARY or not SaveData.is_supported_source(payload):
		return {}
	return payload


func decode_cloud_bytes(content: PackedByteArray) -> Dictionary:
	return decode_save_envelope(content.get_string_from_utf8())


func _commit_local_change() -> void:
	_data.save_revision += 1
	_data.modified_at_unix = int(Time.get_unix_time_from_system())
	_data.cloud_sync_pending = true
	if not _write_local_cache():
		return
	save_changed.emit(get_snapshot())
	if has_node("/root/CloudSaveManager"):
		CloudSaveManager.queue_sync()


func _write_local_cache() -> bool:
	var save_file := FileAccess.open_encrypted_with_pass(
		SAVE_PATH, FileAccess.WRITE, SAVE_PASSWORD
	)
	if save_file == null:
		save_error.emit("local_save_write_failed")
		return false
	save_file.store_string(encode_save_envelope(_data.to_dictionary(true)))
	_has_persisted_save = true
	return true
