extends Node

## Headless coverage for the Milestone 5 catalog and progression manager APIs.


func _ready() -> void:
	_reset_progression()
	_test_catalog_and_shop_queries()
	_test_economy_revision_and_signal()
	_test_skin_ownership_and_equip_validation()
	_test_power_up_inventory_and_candidates()
	print("Milestone 5 smoke test passed.")
	get_tree().quit()


func _reset_progression() -> void:
	assert(SaveManager.apply_cloud_snapshot(SaveData.new().to_dictionary(false)))


func _test_catalog_and_shop_queries() -> void:
	var catalog := ShopManager.get_catalog()
	assert(catalog.validate_catalog().is_empty())
	assert(catalog.get_skin("default_bomb") != null)
	assert(catalog.get_power_up("shield") != null)
	assert(ShopManager.get_category_items(ShopManager.CATEGORY_SKINS).size() == 1)
	assert(ShopManager.get_category_items(ShopManager.CATEGORY_POWER_UPS).size() == 6)
	assert(ShopManager.get_category_items(ShopManager.CATEGORY_PURCHASES).is_empty())
	assert(
		catalog.get_power_up("shield").has_acquisition_type(
			AcquisitionOption.AcquisitionType.LIFETIME_SCORE_CHECKPOINT
		)
	)


func _test_economy_revision_and_signal() -> void:
	var changed_balances: Array[int] = []
	EconomyManager.currency_changed.connect(
		func(currency_id: String, balance: int) -> void:
			assert(currency_id == EconomyManager.GEM_CURRENCY_ID)
			changed_balances.append(balance)
	)
	var starting_revision := int(SaveManager.get_snapshot()["save_revision"])
	assert(EconomyManager.earn_gems(8))
	assert(EconomyManager.get_gem_balance() == 8)
	assert(int(SaveManager.get_snapshot()["save_revision"]) == starting_revision + 1)
	assert(EconomyManager.spend_gems(3))
	assert(EconomyManager.get_gem_balance() == 5)
	assert(not EconomyManager.spend_gems(6))
	assert(changed_balances == [8, 5])
	assert(SaveManager.is_cloud_sync_pending())


func _test_skin_ownership_and_equip_validation() -> void:
	assert(SkinManager.is_owned("default_bomb"))
	assert(SkinManager.get_equipped_skin_id() == "default_bomb")
	assert(not SkinManager.equip_skin("missing_skin"))

	var test_skin := SkinDefinition.new()
	test_skin.content_id = "smoke_test_skin"
	test_skin.display_name = "Smoke Test Skin"
	SkinManager.CATALOG.skins.append(test_skin)
	var owned_events: Array[String] = []
	var equipped_events: Array[String] = []
	SkinManager.skin_owned.connect(func(skin_id: String) -> void: owned_events.append(skin_id))
	SkinManager.skin_equipped.connect(func(skin_id: String) -> void: equipped_events.append(skin_id))
	assert(SkinManager.grant_skin(test_skin.content_id))
	assert(SkinManager.equip_skin(test_skin.content_id))
	assert(SkinManager.is_owned(test_skin.content_id))
	assert(SkinManager.get_equipped_skin_id() == test_skin.content_id)
	assert(owned_events == [test_skin.content_id])
	assert(equipped_events == [test_skin.content_id])


func _test_power_up_inventory_and_candidates() -> void:
	var candidates_before := PowerUpManager.get_checkpoint_candidates().size()
	var unlocked_events: Array[String] = []
	var quantity_events: Array[int] = []
	PowerUpManager.power_up_unlocked.connect(
		func(power_up_id: String) -> void: unlocked_events.append(power_up_id)
	)
	PowerUpManager.power_up_quantity_changed.connect(
		func(power_up_id: String, quantity: int) -> void:
			if power_up_id == "shield":
				quantity_events.append(quantity)
	)

	var starting_revision := int(SaveManager.get_snapshot()["save_revision"])
	assert(PowerUpManager.unlock("shield", 2))
	assert(int(SaveManager.get_snapshot()["save_revision"]) == starting_revision + 1)
	assert(PowerUpManager.is_unlocked("shield"))
	assert(PowerUpManager.get_quantity("shield") == 2)
	assert(PowerUpManager.get_checkpoint_candidates().size() == candidates_before - 1)
	assert(PowerUpManager.add_quantity("shield", 1))
	assert(PowerUpManager.consume("shield", 2))
	assert(PowerUpManager.get_quantity("shield") == 1)
	assert(not PowerUpManager.consume("shield", 2))
	assert(unlocked_events == ["shield"])
	assert(quantity_events == [2, 3, 1])

	var state := ShopManager.get_content_state("shield")
	assert(state["owned"])
	assert(int(state["quantity"]) == 1)
