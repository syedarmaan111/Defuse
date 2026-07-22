extends Node

## ShopManager exposes catalog queries and content state for later screens.
## Purchase orchestration remains deliberately outside this foundation milestone.

signal inventory_updated()

const CATEGORY_SKINS := "skins"
const CATEGORY_POWER_UPS := "power_ups"
const CATEGORY_PURCHASES := "purchases"
const CATALOG: ContentCatalog = preload("res://Resources/Content/ContentCatalog.tres")


func _ready() -> void:
	var catalog_errors := CATALOG.validate_catalog()
	for error_message in catalog_errors:
		push_error(error_message)
	SaveManager.save_loaded.connect(_on_inventory_changed)
	SaveManager.save_changed.connect(_on_inventory_changed)


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


func get_content_state(content_id: String) -> Dictionary:
	## A stable presentation model keeps future Shop cards free of save logic.
	var skin := CATALOG.get_skin(content_id)
	if skin != null:
		return {
			"content_id": content_id,
			"kind": "skin",
			"owned": SkinManager.is_owned(content_id),
			"equipped": SkinManager.get_equipped_skin_id() == content_id,
			"quantity": 0,
		}
	var power_up := CATALOG.get_power_up(content_id)
	if power_up != null:
		return {
			"content_id": content_id,
			"kind": "power_up",
			"owned": PowerUpManager.is_unlocked(content_id),
			"equipped": false,
			"quantity": PowerUpManager.get_quantity(content_id),
		}
	return {}


func _on_inventory_changed(_snapshot: Dictionary) -> void:
	inventory_updated.emit()
