extends PanelContainer

## Layout-owned banner reservation. The native adapter is asked to show only
## while at least one safe slot is visible; release builds keep the area blank
## until a real provider reports availability.

@onready var placeholder_label: Label = %PlaceholderLabel

var _requester_id := ""


func _ready() -> void:
	_requester_id = "banner_%s" % get_instance_id()
	visibility_changed.connect(_refresh_request)
	AdManager.banner_visibility_changed.connect(_on_banner_visibility_changed)
	call_deferred("_refresh_request")


func _exit_tree() -> void:
	if not _requester_id.is_empty():
		AdManager.release_banner_request(_requester_id)


func _refresh_request() -> void:
	AdManager.set_banner_requested(_requester_id, is_visible_in_tree())
	_refresh_placeholder()


func _on_banner_visibility_changed(_is_visible: bool) -> void:
	_refresh_placeholder()


func _refresh_placeholder() -> void:
	placeholder_label.visible = (
		is_visible_in_tree()
		and AdManager.is_simulation_enabled()
		and AdManager.is_banner_visible()
	)
	placeholder_label.text = "TEST ADVERTISEMENT"
