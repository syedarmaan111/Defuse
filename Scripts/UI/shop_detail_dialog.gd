class_name ShopDetailDialog
extends Control

## Displays catalog metadata and creates acquisition controls from Resource data.

signal acquisition_requested(
	content_id: String,
	acquisition_type: AcquisitionOption.AcquisitionType
)
signal equip_requested(content_id: String)

const PRIMARY_BUTTON := preload("res://Scenes/UI/Components/PrimaryButton.tscn")
const SECONDARY_BUTTON := preload("res://Scenes/UI/Components/SecondaryButton.tscn")

var content_id := ""

@onready var heading: Label = %Heading
@onready var icon_rect: TextureRect = %Icon
@onready var fallback_icon: Label = %FallbackIcon
@onready var item_name: Label = %ItemName
@onready var description: Label = %Description
@onready var state_label: Label = %StateLabel
@onready var actions: VBoxContainer = %Actions
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(hide)
	gui_input.connect(_on_backdrop_input)


func show_content(definition: Resource) -> void:
	content_id = ShopManager.get_content_id(definition)
	var display_name := str(definition.get("display_name"))
	var kind := str(ShopManager.get_content_state(content_id).get("kind", "content"))
	heading.text = "%s DETAILS" % kind.replace("_", " ").to_upper()
	item_name.text = display_name.to_upper()
	description.text = str(definition.get("description"))
	var icon: Texture2D = definition.get("icon")
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	fallback_icon.visible = icon == null
	fallback_icon.text = display_name.left(1).to_upper() if not display_name.is_empty() else "?"
	refresh_state()
	show()


func refresh_state() -> void:
	if content_id.is_empty():
		return
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	var state := ShopManager.get_content_state(content_id)
	var owned := bool(state.get("owned", false))
	var equipped := bool(state.get("equipped", false))
	var kind := str(state.get("kind", ""))

	if equipped:
		state_label.text = "OWNED AND EQUIPPED"
		_add_button("EQUIPPED", true)
		return
	if owned and kind == "skin":
		state_label.text = "OWNED"
		var equip_button: Button = PRIMARY_BUTTON.instantiate()
		equip_button.text = "EQUIP"
		equip_button.pressed.connect(_on_equip_pressed)
		actions.add_child(equip_button)
		return
	if owned:
		state_label.text = "UNLOCKED"
		_add_button("UNLOCKED", true)
		return

	state_label.text = "LOCKED"
	var options: Array = state.get("acquisition_options", [])
	if options.is_empty():
		_add_button("NOT CURRENTLY AVAILABLE", true)
		return
	for option in options:
		if option == null:
			continue
		match option.acquisition_type:
			AcquisitionOption.AcquisitionType.DEFAULT_GRANT:
				_add_button("INCLUDED BY DEFAULT", true)
			AcquisitionOption.AcquisitionType.GEM_PURCHASE:
				_add_acquisition_button(
					"UNLOCK FOR %d GEMS" % option.gem_cost,
					option.acquisition_type
				)
			AcquisitionOption.AcquisitionType.LIFETIME_SCORE_CHECKPOINT:
				var next_checkpoint := PowerUpManager.get_next_checkpoint_threshold()
				_add_button(
					"NEXT CHOICE AT %d LIFETIME DEFUSALS" % (
						next_checkpoint
						if next_checkpoint > 0
						else option.lifetime_score_required
					),
					true
				)
			AcquisitionOption.AcquisitionType.REAL_MONEY_PURCHASE:
				_add_acquisition_button("PURCHASE", option.acquisition_type)


func _add_button(button_text: String, disabled: bool) -> void:
	var button: Button = SECONDARY_BUTTON.instantiate()
	button.text = button_text
	button.disabled = disabled
	actions.add_child(button)


func _add_acquisition_button(
	button_text: String,
	acquisition_type: AcquisitionOption.AcquisitionType
) -> void:
	var button: Button = PRIMARY_BUTTON.instantiate()
	button.text = button_text
	button.pressed.connect(_on_acquisition_pressed.bind(acquisition_type))
	actions.add_child(button)


func _on_equip_pressed() -> void:
	equip_requested.emit(content_id)


func _on_acquisition_pressed(
	acquisition_type: AcquisitionOption.AcquisitionType
) -> void:
	acquisition_requested.emit(content_id, acquisition_type)


func _on_backdrop_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hide()
