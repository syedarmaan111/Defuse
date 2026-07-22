extends PanelContainer
class_name ProfileStatCard

## A reusable read-only progression card used by the Profile stat grid.

@export var title := "STAT"
@export var value := "0"

@onready var title_label: Label = %TitleLabel
@onready var value_label: Label = %ValueLabel


func _ready() -> void:
	_refresh_labels()


func set_value(next_value: Variant) -> void:
	value = str(next_value)
	if is_node_ready():
		value_label.text = value


func get_value() -> String:
	return value


func _refresh_labels() -> void:
	title_label.text = title
	value_label.text = value
