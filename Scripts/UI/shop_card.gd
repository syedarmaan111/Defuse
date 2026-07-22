class_name ShopCard
extends PanelContainer

## One catalog-driven card used by skins, power-ups, and purchase offers.

signal details_requested(content_id: String)

var content_id := ""

@onready var icon_rect: TextureRect = %Icon
@onready var fallback_icon: Label = %FallbackIcon
@onready var title_label: Label = %ItemName
@onready var description_label: Label = %Description
@onready var state_label: Label = %StateLabel
@onready var details_button: Button = %DetailsButton


func _ready() -> void:
	details_button.pressed.connect(_on_details_pressed)


func configure(definition: Resource) -> void:
	content_id = ShopManager.get_content_id(definition)
	var display_name := str(definition.get("display_name"))
	var description := str(definition.get("description"))
	var icon: Texture2D = definition.get("icon")
	title_label.text = display_name
	description_label.text = description
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	fallback_icon.visible = icon == null
	fallback_icon.text = display_name.left(1).to_upper() if not display_name.is_empty() else "?"
	refresh_state()


func refresh_state() -> void:
	var state := ShopManager.get_content_state(content_id)
	var kind := str(state.get("kind", ""))
	var owned := bool(state.get("owned", false))
	var equipped := bool(state.get("equipped", false))
	if equipped:
		state_label.text = "EQUIPPED"
		state_label.modulate = Color(0.31, 0.62, 0.25)
	elif owned and kind == "skin":
		state_label.text = "OWNED · TAP TO EQUIP"
		state_label.modulate = Color(0.22, 0.49, 0.57)
	elif owned and kind == "power_up":
		state_label.text = "UNLOCKED · QTY %d" % int(state.get("quantity", 0))
		state_label.modulate = Color(0.31, 0.62, 0.25)
	elif owned:
		state_label.text = "OWNED"
		state_label.modulate = Color(0.31, 0.62, 0.25)
	else:
		state_label.text = _locked_state_text(state.get("acquisition_options", []))
		state_label.modulate = Color(0.55, 0.39, 0.17)


func get_presented_state() -> String:
	return state_label.text


func _locked_state_text(options: Array) -> String:
	var has_checkpoint := false
	var has_purchase := false
	for option in options:
		if option == null:
			continue
		match option.acquisition_type:
			AcquisitionOption.AcquisitionType.GEM_PURCHASE:
				return "%d GEMS" % option.gem_cost
			AcquisitionOption.AcquisitionType.LIFETIME_SCORE_CHECKPOINT:
				has_checkpoint = true
			AcquisitionOption.AcquisitionType.REAL_MONEY_PURCHASE:
				has_purchase = true
	if has_checkpoint and has_purchase:
		return "CHECKPOINT OR PURCHASE"
	if has_checkpoint:
		return "500 DEFUSALS · LOCKED"
	if has_purchase:
		return "PURCHASE OPTION"
	return "UNAVAILABLE"


func _on_details_pressed() -> void:
	details_requested.emit(content_id)
