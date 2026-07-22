extends Resource
class_name ContentCatalog

## The single source of truth for selectable content. Screens query this data
## through ShopManager and never contain item-specific layout or business logic.

@export var skins: Array[SkinDefinition] = []
@export var power_ups: Array[PowerUpDefinition] = []
@export var offers: Array[ShopOfferDefinition] = []


func get_skin(content_id: String) -> SkinDefinition:
	for definition in skins:
		if definition != null and definition.content_id == content_id:
			return definition
	return null


func get_power_up(content_id: String) -> PowerUpDefinition:
	for definition in power_ups:
		if definition != null and definition.content_id == content_id:
			return definition
	return null


func get_offer(offer_id: String) -> ShopOfferDefinition:
	for definition in offers:
		if definition != null and definition.offer_id == offer_id:
			return definition
	return null


func validate_catalog() -> PackedStringArray:
	## Returns actionable authoring errors without crashing a release build.
	var errors := PackedStringArray()
	var known_ids := {}
	for definition in skins:
		_validate_content_definition(definition, "skin", known_ids, errors)
	for definition in power_ups:
		_validate_content_definition(definition, "power_up", known_ids, errors)
	for offer in offers:
		if offer == null:
			errors.append("Catalog contains a null offer.")
			continue
		_validate_id(offer.offer_id, "offer", known_ids, errors)
		_validate_options(offer.acquisition_options, offer.offer_id, errors)
	if get_skin(SaveData.DEFAULT_SKIN_ID) == null:
		errors.append("Catalog must contain default_bomb.")
	return errors


func _validate_content_definition(
	definition: Resource,
	kind: String,
	known_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	if definition == null:
		errors.append("Catalog contains a null %s." % kind)
		return
	_validate_id(definition.content_id, kind, known_ids, errors)
	_validate_options(definition.acquisition_options, definition.content_id, errors)


func _validate_id(
	content_id: String,
	kind: String,
	known_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	if content_id.strip_edges().is_empty():
		errors.append("Catalog %s has an empty ID." % kind)
	elif known_ids.has(content_id):
		errors.append("Catalog ID '%s' is duplicated." % content_id)
	else:
		known_ids[content_id] = true


func _validate_options(
	options: Array[AcquisitionOption],
	content_id: String,
	errors: PackedStringArray
) -> void:
	for option in options:
		if option == null or not option.is_valid():
			errors.append("Catalog item '%s' has an invalid acquisition option." % content_id)
