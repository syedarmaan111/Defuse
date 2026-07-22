extends Node

## Headless smoke coverage for Milestone 4 migration and reconciliation rules.


func _ready() -> void:
	_test_legacy_migration_and_validation()
	_test_envelope_integrity()
	_test_revision_queue_and_reconciliation()
	print("Milestone 4 smoke test passed.")
	get_tree().quit()


func _test_legacy_migration_and_validation() -> void:
	var migrated := SaveData.from_dictionary({
		"best_score": -8,
		"total_gems": 17,
		"selected_skin": "plasma_bomb",
	})
	assert(migrated.save_version == SaveData.CURRENT_VERSION)
	assert(migrated.best_score == 0)
	assert(int(migrated.currencies["gems"]) == 17)
	assert(migrated.owned_skin_ids.has("default_bomb"))
	assert(migrated.owned_skin_ids.has("plasma_bomb"))
	assert(migrated.equipped_skin_id == "plasma_bomb")

	var invalid_equipped := SaveData.from_dictionary({
		"save_version": SaveData.CURRENT_VERSION,
		"owned_skin_ids": ["default_bomb"],
		"equipped_skin_id": "missing_skin",
	})
	assert(invalid_equipped.equipped_skin_id == "default_bomb")


func _test_envelope_integrity() -> void:
	var snapshot := SaveData.new().to_dictionary()
	var encoded := SaveManager.encode_save_envelope(snapshot)
	var decoded := SaveManager.decode_save_envelope(encoded)
	assert(not decoded.is_empty())
	assert(int(decoded["save_version"]) == SaveData.CURRENT_VERSION)
	assert(SaveManager.decode_save_envelope(
		JSON.stringify({"payload": JSON.stringify(snapshot), "checksum": "tampered"})
	).is_empty())


func _test_revision_queue_and_reconciliation() -> void:
	var reinstall_cloud := SaveData.new().to_dictionary()
	reinstall_cloud["currencies"] = {"gems": 7}
	SaveManager._has_persisted_save = false
	CloudSaveManager._restore_completed = false
	CloudSaveManager.reconcile_loaded_dictionary(reinstall_cloud)
	assert(SaveManager.get_total_gems() == 7)
	assert(CloudSaveManager.is_restore_ready())

	var baseline := SaveData.new().to_dictionary()
	baseline["save_revision"] = 4
	baseline["modified_at_unix"] = 100
	baseline["best_score"] = 9
	assert(SaveManager.apply_cloud_snapshot(baseline))

	SaveManager.set_total_gems(11)
	var local := SaveManager.get_snapshot(false)
	assert(int(local["save_revision"]) == 5)
	assert(SaveManager.is_cloud_sync_pending())

	var older_cloud := baseline.duplicate(true)
	assert(CloudSaveManager.determine_reconciliation(local, older_cloud) == "local")

	var newer_cloud := local.duplicate(true)
	newer_cloud["save_revision"] = 6
	newer_cloud["modified_at_unix"] = int(local["modified_at_unix"]) + 1
	newer_cloud["currencies"] = {"gems": 23}
	assert(CloudSaveManager.determine_reconciliation(local, newer_cloud) == "cloud")

	CloudSaveManager._restore_completed = false
	CloudSaveManager.reconcile_loaded_dictionary(newer_cloud)
	assert(SaveManager.get_total_gems() == 23)
	assert(CloudSaveManager.is_restore_ready())

	var conflict_cloud := newer_cloud.duplicate(true)
	conflict_cloud["currencies"] = {"gems": 31}
	conflict_cloud["modified_at_unix"] = int(newer_cloud["modified_at_unix"]) + 5
	assert(CloudSaveManager.determine_reconciliation(newer_cloud, conflict_cloud) == "conflict")

	var conflict_emitted := [false]
	CloudSaveManager.cloud_conflict_detected.connect(
		func(_local_summary: Dictionary, _cloud_summary: Dictionary) -> void:
			conflict_emitted[0] = true,
		CONNECT_ONE_SHOT
	)
	CloudSaveManager._restore_completed = false
	CloudSaveManager.reconcile_loaded_dictionary(conflict_cloud)
	assert(conflict_emitted[0])
	assert(not CloudSaveManager.is_restore_ready())
	CloudSaveManager.resolve_conflict(CloudSaveManager.SOURCE_CLOUD)
	assert(SaveManager.get_total_gems() == 31)
	assert(CloudSaveManager.is_restore_ready())

	SaveManager.set_total_gems(32)
	var queued_revision := int(SaveManager.get_snapshot()["save_revision"])
	SaveManager.mark_cloud_sync_complete(queued_revision - 1)
	assert(SaveManager.is_cloud_sync_pending())
	SaveManager.mark_cloud_sync_complete(queued_revision)
	assert(not SaveManager.is_cloud_sync_pending())
