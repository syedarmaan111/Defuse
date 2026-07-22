extends Node

## Headless coverage for Milestone 7 catalog rendering and acquisition flows.

const SHOP_SCENE := preload("res://Scenes/UI/ShopScreen.tscn")


func _ready() -> void:
	_seed_progression()
	await _test_catalog_driven_shop()
	await _test_atomic_gem_purchase_and_equip()
	await _test_safe_purchase_failures()
	print("Milestone 7 smoke test passed.")
	get_tree().quit()


func _seed_progression() -> void:
	var snapshot := SaveData.new().to_dictionary(false)
	snapshot["currencies"] = {"gems": 25}
	assert(SaveManager.apply_cloud_snapshot(snapshot))


func _test_catalog_driven_shop() -> void:
	var shop := SHOP_SCENE.instantiate()
	add_child(shop)
	await get_tree().process_frame
	assert(shop.get_active_category() == ShopManager.CATEGORY_SKINS)
	assert(shop.get_presented_category_count() == 1)
	assert(shop.get_presented_card_states() == ["EQUIPPED"])

	shop.select_category(ShopManager.CATEGORY_POWER_UPS)
	await get_tree().process_frame
	assert(shop.get_presented_category_count() == 6)
	for state in shop.get_presented_card_states():
		assert(state == "500 DEFUSALS · LOCKED")

	shop.select_category(ShopManager.CATEGORY_PURCHASES)
	await get_tree().process_frame
	assert(shop.get_presented_category_count() == 0)
	assert(shop.get_node("%EmptyState").visible)
	assert("never sold" in shop.get_node("%EmptyDescription").text)
	shop.queue_free()


func _test_atomic_gem_purchase_and_equip() -> void:
	var test_skin := _make_skin("milestone7_gem_skin", "Gem Test Skin")
	var gem_option := AcquisitionOption.new()
	gem_option.acquisition_type = AcquisitionOption.AcquisitionType.GEM_PURCHASE
	gem_option.gem_cost = 20
	test_skin.acquisition_options.append(gem_option)
	ShopManager.CATALOG.skins.append(test_skin)

	var starting_revision := int(SaveManager.get_snapshot()["save_revision"])
	assert(ShopManager.request_acquisition(
		test_skin.content_id, AcquisitionOption.AcquisitionType.GEM_PURCHASE
	))
	assert(EconomyManager.get_gem_balance() == 5)
	assert(SkinManager.is_owned(test_skin.content_id))
	assert(int(SaveManager.get_snapshot()["save_revision"]) == starting_revision + 1)
	assert(ShopManager.request_equip(test_skin.content_id))
	var state := ShopManager.get_content_state(test_skin.content_id)
	assert(state["owned"])
	assert(state["equipped"])
	assert(state["selected"])

	var shop := SHOP_SCENE.instantiate()
	add_child(shop)
	await get_tree().process_frame
	assert(shop.get_presented_category_count() == 2)
	assert("EQUIPPED" in shop.get_presented_card_states())
	var test_card: ShopCard = shop.get_node("%Items").get_child(1)
	test_card.get_node("%DetailsButton").pressed.emit()
	var detail_dialog := shop.get_node("%ShopDetailDialog")
	assert(detail_dialog.visible)
	assert(detail_dialog.get_node("%ItemName").text == "GEM TEST SKIN")
	shop.queue_free()


func _test_safe_purchase_failures() -> void:
	var errors: Array[String] = []
	ShopManager.acquisition_failed.connect(
		func(_content_id: String, error_code: String) -> void: errors.append(error_code)
	)

	var expensive_skin := _make_skin("milestone7_expensive_skin", "Expensive Skin")
	var expensive_option := AcquisitionOption.new()
	expensive_option.acquisition_type = AcquisitionOption.AcquisitionType.GEM_PURCHASE
	expensive_option.gem_cost = 100
	expensive_skin.acquisition_options.append(expensive_option)
	ShopManager.CATALOG.skins.append(expensive_skin)
	assert(not ShopManager.request_acquisition(
		expensive_skin.content_id, AcquisitionOption.AcquisitionType.GEM_PURCHASE
	))
	assert(errors.has("insufficient_gems"))
	assert(EconomyManager.get_gem_balance() == 5)
	assert(not SkinManager.is_owned(expensive_skin.content_id))

	var paid_skin := _make_skin("milestone7_paid_skin", "Paid Test Skin")
	var paid_option := AcquisitionOption.new()
	paid_option.acquisition_type = AcquisitionOption.AcquisitionType.REAL_MONEY_PURCHASE
	paid_option.product_id = "defuse.test.skin"
	paid_skin.acquisition_options.append(paid_option)
	ShopManager.CATALOG.skins.append(paid_skin)
	assert(not ShopManager.request_acquisition(
		paid_skin.content_id, AcquisitionOption.AcquisitionType.REAL_MONEY_PURCHASE
	))
	await get_tree().process_frame
	assert(errors.has("provider_unavailable"))
	assert(not SkinManager.is_owned(paid_skin.content_id))


func _make_skin(content_id: String, display_name: String) -> SkinDefinition:
	var definition := SkinDefinition.new()
	definition.content_id = content_id
	definition.display_name = display_name
	definition.description = "Test catalog entry rendered without item-specific UI."
	definition.icon = load("res://Assets/Bomb/bomb_reference.png")
	return definition
