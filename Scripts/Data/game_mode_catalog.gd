extends Resource
class_name GameModeCatalog

## Ordered source of truth for mode selection and stable save record IDs.

@export var modes: Array[GameModeDefinition] = []


func get_mode(mode_id: String) -> GameModeDefinition:
	for definition in modes:
		if definition != null and definition.mode_id == mode_id:
			return definition
	return null


func get_mode_ids() -> Array[String]:
	var result: Array[String] = []
	for definition in modes:
		if definition != null:
			result.append(definition.mode_id)
	return result


func validate_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	var known_ids := {}
	for definition in modes:
		if definition == null or not definition.is_valid():
			errors.append("Mode catalog contains an invalid definition.")
			continue
		if known_ids.has(definition.mode_id):
			errors.append("Mode ID '%s' is duplicated." % definition.mode_id)
		else:
			known_ids[definition.mode_id] = true
	if get_mode("endless") == null:
		errors.append("Mode catalog must contain Endless.")
	return errors
