extends Node

## Headless coverage for the temporary 20-defusal checkpoint, persisted queues, the
## catalog-driven choice overlay, and atomic cloud-queued claims.

const POWER_UP_UNLOCK_OVERLAY := preload("res://Scenes/UI/PowerUpUnlockOverlay.tscn")
const POWER_UP_COUNT := 6


func _ready() -> void:
	_test_checkpoint_metadata()
	await _test_game_over_queue_and_atomic_claim()
	_test_backlog_is_capped_by_catalog()
	print("Milestone 11 smoke test passed.")
	get_tree().quit()


func _test_checkpoint_metadata() -> void:
	_reset_progression(19)
	assert(PowerUpManager.get_checkpoint_interval() == 20)
	assert(PowerUpManager.get_next_checkpoint_threshold() == 20)
	for definition in PowerUpManager.get_checkpoint_candidates():
		var option: AcquisitionOption = definition.acquisition_options[0]
		assert(option.lifetime_score_required == 20)


func _test_game_over_queue_and_atomic_claim() -> void:
	# A run ending below the checkpoint must not create an unlock.
	GameManager.show_game_over()
	assert(PowerUpManager.get_pending_unlock_choice_count() == 0)
	assert(SaveManager.get_claimed_power_up_checkpoints().is_empty())

	# Reaching exactly 20 is persisted first, then Game Over queues one
	# checkpoint in its own atomic save revision before the overlay is shown.
	assert(SaveManager.add_lifetime_defusals(1))
	var revision_before_queue := _save_revision()
	GameManager.show_game_over()
	assert(PowerUpManager.get_pending_unlock_choice_count() == 1)
	assert(SaveManager.get_claimed_power_up_checkpoints() == [20])
	assert(_save_revision() == revision_before_queue + 1)
	assert(SaveManager.is_cloud_sync_pending())
	assert(PowerUpManager.get_next_checkpoint_threshold() == 40)

	# Re-evaluating the same lifetime total is idempotent.
	var queued_revision := _save_revision()
	assert(PowerUpManager.queue_lifetime_checkpoint_choices() == 0)
	assert(_save_revision() == queued_revision)

	var overlay: PowerUpUnlockOverlay = POWER_UP_UNLOCK_OVERLAY.instantiate()
	add_child(overlay)
	await get_tree().process_frame
	assert(overlay.show_if_pending())
	assert(overlay.visible)
	assert(overlay.items.get_child_count() == POWER_UP_COUNT)
	assert(
		"20"
		in overlay.get_node("SafeMargins/Center/Popup/Content/Footer").text
	)

	var chosen_card: PowerUpUnlockCard = overlay.items.get_child(0)
	var chosen_id := chosen_card.power_up_id
	var revision_before_claim := _save_revision()
	chosen_card.get_node("%UnlockButton").pressed.emit()
	assert(PowerUpManager.is_unlocked(chosen_id))
	assert(PowerUpManager.get_pending_unlock_choice_count() == 0)
	assert(_save_revision() == revision_before_claim + 1)
	assert(SaveManager.is_cloud_sync_pending())
	assert(not overlay.visible)

	# One queued checkpoint grants exactly one catalog item.
	var claimed_revision := _save_revision()
	assert(not PowerUpManager.claim_checkpoint_power_up(chosen_id))
	assert(_save_revision() == claimed_revision)
	assert(PowerUpManager.get_unlocked_ids().size() == 1)
	overlay.queue_free()


func _test_backlog_is_capped_by_catalog() -> void:
	# Returning players can receive all reached choices at once, but never more
	# pending choices than there are locked catalog power-ups.
	_reset_progression(200)
	assert(PowerUpManager.queue_lifetime_checkpoint_choices() == POWER_UP_COUNT)
	assert(PowerUpManager.get_pending_unlock_choice_count() == POWER_UP_COUNT)
	assert(
		SaveManager.get_claimed_power_up_checkpoints()
		== [20, 40, 60, 80, 100, 120]
	)

	for _choice_index in POWER_UP_COUNT:
		var candidates := PowerUpManager.get_checkpoint_candidates()
		assert(not candidates.is_empty())
		assert(PowerUpManager.claim_checkpoint_power_up(candidates[0].content_id))

	assert(PowerUpManager.get_pending_unlock_choice_count() == 0)
	assert(PowerUpManager.get_checkpoint_candidates().is_empty())
	assert(PowerUpManager.get_unlocked_ids().size() == POWER_UP_COUNT)
	assert(PowerUpManager.queue_lifetime_checkpoint_choices() == 0)
	assert(
		SaveManager.get_claimed_power_up_checkpoints()
		== [20, 40, 60, 80, 100, 120]
	)


func _reset_progression(lifetime_defusals: int) -> void:
	var snapshot := SaveData.new().to_dictionary(false)
	snapshot["lifetime_defusal_score"] = lifetime_defusals
	assert(SaveManager.apply_cloud_snapshot(snapshot))


func _save_revision() -> int:
	return int(SaveManager.get_snapshot()["save_revision"])
