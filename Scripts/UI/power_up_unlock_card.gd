class_name PowerUpUnlockCard
extends PanelContainer

signal unlock_requested(power_up_id: String)

var power_up_id := ""

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %PowerUpName
@onready var description_label: Label = %Description
@onready var unlock_button: Button = %UnlockButton


func _ready() -> void:
	unlock_button.pressed.connect(_on_unlock_pressed)


func configure(definition: PowerUpDefinition) -> void:
	power_up_id = definition.content_id
	icon_rect.texture = definition.icon
	name_label.text = definition.display_name.to_upper()
	description_label.text = definition.description


func _on_unlock_pressed() -> void:
	unlock_requested.emit(power_up_id)
