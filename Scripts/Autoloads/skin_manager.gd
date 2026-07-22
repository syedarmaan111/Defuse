extends Node

## SkinManager validates ownership/equip requests against the content catalog.

signal skin_owned(skin_id: String)
signal skin_equipped(skin_id: String)

const CATALOG: ContentCatalog = preload("res://Resources/Content/ContentCatalog.tres")

var _known_owned_ids: Array[String] = []
var _known_equipped_id := ""


func _ready() -> void:
	_capture_snapshot(SaveManager.get_snapshot(), false)
	SaveManager.save_loaded.connect(_on_save_snapshot)
	SaveManager.save_changed.connect(_on_save_snapshot)


func get_definition(skin_id: String) -> SkinDefinition:
	return CATALOG.get_skin(skin_id)


func get_owned_skin_ids() -> Array[String]:
	var result: Array[String] = []
	for skin_id in SaveManager.get_owned_skin_ids():
		if CATALOG.get_skin(skin_id) != null:
			result.append(skin_id)
	return result


func get_owned_skins() -> Array[SkinDefinition]:
	var result: Array[SkinDefinition] = []
	for skin_id in get_owned_skin_ids():
		result.append(CATALOG.get_skin(skin_id))
	return result


func is_owned(skin_id: String) -> bool:
	return CATALOG.get_skin(skin_id) != null and SaveManager.get_owned_skin_ids().has(skin_id)


func get_equipped_skin_id() -> String:
	return SaveManager.get_selected_skin()


func get_equipped_skin() -> SkinDefinition:
	var definition := CATALOG.get_skin(get_equipped_skin_id())
	return definition if definition != null else CATALOG.get_skin(SaveData.DEFAULT_SKIN_ID)


func grant_skin(skin_id: String) -> bool:
	var definition := CATALOG.get_skin(skin_id)
	if definition == null or not definition.is_available:
		return false
	return SaveManager.grant_skin(skin_id)


func equip_skin(skin_id: String) -> bool:
	if not is_owned(skin_id):
		return false
	return SaveManager.set_selected_skin(skin_id)


func _on_save_snapshot(snapshot: Dictionary) -> void:
	_capture_snapshot(snapshot, true)


func _capture_snapshot(snapshot: Dictionary, emit_changes: bool) -> void:
	var next_owned := SaveData.from_dictionary(snapshot).owned_skin_ids
	var next_equipped := str(snapshot.get("equipped_skin_id", SaveData.DEFAULT_SKIN_ID))
	if emit_changes:
		for skin_id in next_owned:
			if not _known_owned_ids.has(skin_id) and CATALOG.get_skin(skin_id) != null:
				skin_owned.emit(skin_id)
		if next_equipped != _known_equipped_id:
			skin_equipped.emit(next_equipped)
	_known_owned_ids = next_owned
	_known_equipped_id = next_equipped
