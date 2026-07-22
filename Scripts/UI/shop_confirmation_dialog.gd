class_name ShopConfirmationDialog
extends Control

## Reusable purchase confirmation that carries only stable IDs and option type.

signal confirmed(content_id: String, acquisition_type: AcquisitionOption.AcquisitionType)

var _content_id := ""
var _acquisition_type := AcquisitionOption.AcquisitionType.DEFAULT_GRANT

@onready var title_label: Label = %Title
@onready var message_label: Label = %Message
@onready var cancel_button: Button = %CancelButton
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	cancel_button.pressed.connect(hide)
	confirm_button.pressed.connect(_confirm)


func show_confirmation(
	content_id: String,
	acquisition_type: AcquisitionOption.AcquisitionType,
	display_name: String,
	message: String
) -> void:
	_content_id = content_id
	_acquisition_type = acquisition_type
	title_label.text = "CONFIRM PURCHASE"
	message_label.text = message.replace("{item}", display_name)
	confirm_button.text = "BUY"
	show()


func _confirm() -> void:
	hide()
	confirmed.emit(_content_id, _acquisition_type)
