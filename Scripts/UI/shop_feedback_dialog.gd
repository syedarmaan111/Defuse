class_name ShopFeedbackDialog
extends Control

## Small reusable result dialog for success, insufficient Gems, and failures.

@onready var title_label: Label = %Title
@onready var message_label: Label = %Message
@onready var ok_button: Button = %OkButton


func _ready() -> void:
	ok_button.pressed.connect(hide)


func show_feedback(title: String, message: String) -> void:
	title_label.text = title
	message_label.text = message
	show()
