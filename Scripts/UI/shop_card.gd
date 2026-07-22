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
@onready var power_toggle_button: Button = %PowerToggleButton


func _ready() -> void:
	details_button.pressed.connect(_on_details_pressed)
	power_toggle_button.pressed.connect(_on_power_toggle_pressed)


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
	var power_up_enabled := bool(state.get("enabled", true))
	power_toggle_button.visible = kind == "power_up"
	power_toggle_button.disabled = kind == "power_up" and not owned
	power_toggle_button.text = "DISABLE" if power_up_enabled else "ENABLE"
	power_toggle_button.tooltip_text = (
		"Exclude this power-up from reward spawns and automatic activation."
		if owned
		else "Unlock this power-up before enabling or disabling it."
	)
	if equipped:
		state_label.text = "EQUIPPED"
		_set_state_colors(Color(0.86, 0.94, 0.8), Color(0.2, 0.4, 0.16))
	elif owned and kind == "skin":
		state_label.text = "OWNED · TAP TO EQUIP"
		_set_state_colors(Color(0.82, 0.92, 0.94), Color(0.16, 0.36, 0.42))
	elif owned and kind == "power_up":
		state_label.text = "UNLOCKED / %s" % ("ENABLED" if power_up_enabled else "DISABLED")
		_set_state_colors(
			Color(0.86, 0.94, 0.8) if power_up_enabled else Color(0.9, 0.88, 0.84),
			Color(0.2, 0.4, 0.16) if power_up_enabled else Color(0.38, 0.35, 0.31)
		)
	elif owned:
		state_label.text = "OWNED"
		_set_state_colors(Color(0.86, 0.94, 0.8), Color(0.2, 0.4, 0.16))
	else:
		state_label.text = _locked_state_text(state.get("acquisition_options", []))
		_set_state_colors(Color(0.97, 0.93, 0.84), Color(0.34, 0.3, 0.23))


func get_presented_state() -> String:
	return state_label.text


func _set_state_colors(background: Color, foreground: Color) -> void:
	var style := state_label.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	style.bg_color = background
	state_label.add_theme_stylebox_override("normal", style)
	state_label.add_theme_color_override("font_color", foreground)
	state_label.modulate = Color.WHITE


func _locked_state_text(options: Array) -> String:
	var has_checkpoint := false
	var checkpoint_requirement := 0
	var has_purchase := false
	for option in options:
		if option == null:
			continue
		match option.acquisition_type:
			AcquisitionOption.AcquisitionType.GEM_PURCHASE:
				return "%d GEMS" % option.gem_cost
			AcquisitionOption.AcquisitionType.LIFETIME_SCORE_CHECKPOINT:
				has_checkpoint = true
				checkpoint_requirement = max(
					checkpoint_requirement, option.lifetime_score_required
				)
			AcquisitionOption.AcquisitionType.REAL_MONEY_PURCHASE:
				has_purchase = true
	if has_checkpoint and has_purchase:
		return "CHECKPOINT OR PURCHASE"
	if has_checkpoint:
		var next_checkpoint := PowerUpManager.get_next_checkpoint_threshold()
		return "%d DEFUSALS · LOCKED" % (
			next_checkpoint if next_checkpoint > 0 else checkpoint_requirement
		)
	if has_purchase:
		return "PURCHASE OPTION"
	return "UNAVAILABLE"


func _on_details_pressed() -> void:
	details_requested.emit(content_id)


func _on_power_toggle_pressed() -> void:
	if not PowerUpManager.is_unlocked(content_id):
		return
	PowerUpManager.set_power_up_enabled(
		content_id, not PowerUpManager.is_power_up_enabled(content_id)
	)
	refresh_state()
