extends Node

## ShopManager exposes catalog queries and owns provider-neutral acquisition
## orchestration. Screens render its state and never mutate progression directly.

signal inventory_updated()
signal acquisition_succeeded(content_id: String, result_code: String)
signal acquisition_failed(content_id: String, error_code: String)
signal purchase_started(content_id: String)

const CATEGORY_SKINS := "skins"
const CATEGORY_POWER_UPS := "power_ups"
const CATEGORY_PURCHASES := "purchases"
const CATALOG: ContentCatalog = preload("res://Resources/Content/ContentCatalog.tres")

var _pending_products: Dictionary = {}


func _ready() -> void:
	var catalog_errors := CATALOG.validate_catalog()
	for error_message in catalog_errors:
		push_error(error_message)
	SaveManager.save_loaded.connect(_on_inventory_changed)
	SaveManager.save_changed.connect(_on_inventory_changed)
	CommerceManager.purchase_succeeded.connect(_on_purchase_succeeded)
	CommerceManager.purchase_cancelled.connect(_on_purchase_cancelled)
	CommerceManager.purchase_failed.connect(_on_purchase_failed)
	CommerceManager.purchases_restored.connect(_on_purchases_restored)


func get_catalog() -> ContentCatalog:
	return CATALOG


func get_category_items(category_id: String) -> Array[Resource]:
	var result: Array[Resource] = []
	match category_id:
		CATEGORY_SKINS:
			for definition in CATALOG.skins:
				if definition != null and (definition.is_available or SkinManager.is_owned(definition.content_id)):
					result.append(definition)
		CATEGORY_POWER_UPS:
			for definition in CATALOG.power_ups:
				if definition != null and definition.is_available:
					result.append(definition)
		CATEGORY_PURCHASES:
			for definition in CATALOG.offers:
				if definition != null and definition.is_available:
					result.append(definition)
	return result


func get_acquisition_options(content_id: String) -> Array[AcquisitionOption]:
	var skin := CATALOG.get_skin(content_id)
	if skin != null:
		return skin.acquisition_options.duplicate()
	var power_up := CATALOG.get_power_up(content_id)
	if power_up != null:
		return power_up.acquisition_options.duplicate()
	var offer := CATALOG.get_offer(content_id)
	if offer != null:
		return offer.acquisition_options.duplicate()
	return []


func get_definition(content_id: String) -> Resource:
	var definition: Resource = CATALOG.get_skin(content_id)
	if definition == null:
		definition = CATALOG.get_power_up(content_id)
	if definition == null:
		definition = CATALOG.get_offer(content_id)
	return definition


func get_content_id(definition: Resource) -> String:
	if definition is SkinDefinition or definition is PowerUpDefinition:
		return definition.content_id
	if definition is ShopOfferDefinition:
		return definition.offer_id
	return ""


func get_content_state(content_id: String) -> Dictionary:
	## A stable presentation model keeps future Shop cards free of save logic.
	var skin := CATALOG.get_skin(content_id)
	if skin != null:
		return {
			"content_id": content_id,
			"kind": "skin",
			"owned": SkinManager.is_owned(content_id),
			"equipped": SkinManager.get_equipped_skin_id() == content_id,
			"selected": SkinManager.get_equipped_skin_id() == content_id,
			"quantity": 0,
			"acquisition_options": skin.acquisition_options.duplicate(),
		}
	var power_up := CATALOG.get_power_up(content_id)
	if power_up != null:
		return {
			"content_id": content_id,
			"kind": "power_up",
			"owned": PowerUpManager.is_unlocked(content_id),
			"equipped": false,
			"selected": false,
			"enabled": PowerUpManager.is_power_up_enabled(content_id),
			"quantity": PowerUpManager.get_quantity(content_id),
			"acquisition_options": power_up.acquisition_options.duplicate(),
		}
	var offer := CATALOG.get_offer(content_id)
	if offer != null:
		return {
			"content_id": content_id,
			"kind": "offer",
			"owned": SaveManager.get_purchased_content_ids().has(content_id),
			"equipped": false,
			"selected": false,
			"quantity": 0,
			"acquisition_options": offer.acquisition_options.duplicate(),
		}
	return {}


func request_equip(skin_id: String) -> bool:
	if not SkinManager.is_owned(skin_id):
		acquisition_failed.emit(skin_id, "not_owned")
		return false
	if SkinManager.get_equipped_skin_id() == skin_id:
		acquisition_succeeded.emit(skin_id, "already_equipped")
		return true
	if not SkinManager.equip_skin(skin_id):
		acquisition_failed.emit(skin_id, "equip_failed")
		return false
	acquisition_succeeded.emit(skin_id, "equipped")
	return true


func request_acquisition(
	content_id: String,
	acquisition_type: AcquisitionOption.AcquisitionType
) -> bool:
	## Validates the selected catalog option before any economy or provider call.
	var definition := get_definition(content_id)
	if definition == null:
		acquisition_failed.emit(content_id, "content_not_found")
		return false
	var option := _find_option(content_id, acquisition_type)
	if option == null:
		acquisition_failed.emit(content_id, "option_not_found")
		return false

	var state := get_content_state(content_id)
	if bool(state.get("owned", false)):
		if state.get("kind", "") == "skin":
			return request_equip(content_id)
		acquisition_failed.emit(content_id, "already_owned")
		return false

	match acquisition_type:
		AcquisitionOption.AcquisitionType.DEFAULT_GRANT:
			acquisition_failed.emit(content_id, "not_purchasable")
			return false
		AcquisitionOption.AcquisitionType.GEM_PURCHASE:
			return _purchase_skin_with_gems(content_id, option.gem_cost)
		AcquisitionOption.AcquisitionType.LIFETIME_SCORE_CHECKPOINT:
			acquisition_failed.emit(content_id, "checkpoint_choice_required")
			return false
		AcquisitionOption.AcquisitionType.REAL_MONEY_PURCHASE:
			return _start_real_money_purchase(content_id, option.product_id)
	return false


func _find_option(
	content_id: String,
	acquisition_type: AcquisitionOption.AcquisitionType
) -> AcquisitionOption:
	for option in get_acquisition_options(content_id):
		if option != null and option.acquisition_type == acquisition_type:
			return option
	return null


func _purchase_skin_with_gems(content_id: String, gem_cost: int) -> bool:
	if CATALOG.get_skin(content_id) == null:
		acquisition_failed.emit(content_id, "gems_not_supported")
		return false
	if not EconomyManager.can_afford_gems(gem_cost):
		acquisition_failed.emit(content_id, "insufficient_gems")
		return false
	if not SaveManager.purchase_skin_with_gems(content_id, gem_cost):
		acquisition_failed.emit(content_id, "purchase_failed")
		return false
	acquisition_succeeded.emit(content_id, "owned")
	return true


func _start_real_money_purchase(content_id: String, product_id: String) -> bool:
	if not NetworkManager.can_start_game():
		acquisition_failed.emit(content_id, "internet_required")
		return false
	_pending_products[product_id] = content_id
	purchase_started.emit(content_id)
	return CommerceManager.purchase(product_id)


func _grant_paid_content(content_id: String) -> bool:
	var granted := false
	if CATALOG.get_skin(content_id) != null:
		granted = SkinManager.is_owned(content_id) or SkinManager.grant_skin(content_id)
	elif CATALOG.get_power_up(content_id) != null:
		granted = PowerUpManager.is_unlocked(content_id) or PowerUpManager.unlock(content_id)
	else:
		var offer := CATALOG.get_offer(content_id)
		if offer != null:
			for granted_id in offer.granted_content_ids:
				_grant_paid_content(granted_id)
			granted = true
	if granted:
		SaveManager.record_purchased_content(content_id)
	return granted


func _on_purchase_succeeded(product_id: String) -> void:
	var content_id := str(_pending_products.get(product_id, ""))
	_pending_products.erase(product_id)
	if content_id.is_empty() or not _grant_paid_content(content_id):
		acquisition_failed.emit(content_id, "grant_failed")
		return
	acquisition_succeeded.emit(content_id, "owned")


func _on_purchase_cancelled(product_id: String) -> void:
	var content_id := str(_pending_products.get(product_id, ""))
	_pending_products.erase(product_id)
	acquisition_failed.emit(content_id, "purchase_cancelled")


func _on_purchase_failed(product_id: String, error_code: String) -> void:
	var content_id := str(_pending_products.get(product_id, ""))
	_pending_products.erase(product_id)
	acquisition_failed.emit(content_id, error_code)


func _on_purchases_restored(product_ids: Array[String]) -> void:
	for product_id in product_ids:
		for category_id in [CATEGORY_SKINS, CATEGORY_POWER_UPS, CATEGORY_PURCHASES]:
			for definition in get_category_items(category_id):
				var content_id := get_content_id(definition)
				var option := _find_option(
					content_id, AcquisitionOption.AcquisitionType.REAL_MONEY_PURCHASE
				)
				if option != null and option.product_id == product_id:
					_grant_paid_content(content_id)


func _on_inventory_changed(_snapshot: Dictionary) -> void:
	inventory_updated.emit()
