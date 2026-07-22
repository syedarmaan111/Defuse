extends Control
class_name RewardBadge

## One reusable, background-free reward marker attached to a bomb. The parent
## bomb remains the touch target, so the marker cannot intercept gameplay input.

@onready var gem_icon: TextureRect = %GemIcon
@onready var gem_amount_label: Label = %GemAmountLabel
@onready var power_icon: TextureRect = %PowerIcon

var _pulse_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	resized.connect(_refresh_pivot)


func show_reward(
	reward_type: String,
	reward_id: String,
	display_name: String,
	reward_amount: int = 1
) -> void:
	visible = true
	var is_gem := reward_type == "gem"
	gem_icon.visible = is_gem
	gem_amount_label.visible = is_gem
	gem_amount_label.text = "+%d" % maxi(reward_amount, 1)
	var definition := PowerUpManager.get_definition(reward_id)
	power_icon.texture = definition.icon if definition != null else null
	power_icon.visible = reward_type == "power_up" and power_icon.texture != null
	tooltip_text = display_name
	_start_pulse()


func clear_reward() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	scale = Vector2.ONE
	visible = false


func _start_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_refresh_pivot()
	# Return to the exact resting size on every cycle. Sine easing gives both
	# ends zero velocity, so the loop breathes instead of visibly snapping.
	scale = Vector2.ONE
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "scale", Vector2.ONE * 1.085, 0.62).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.62).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)


func _refresh_pivot() -> void:
	pivot_offset = size * 0.5
