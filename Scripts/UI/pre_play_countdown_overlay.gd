class_name PrePlayCountdownOverlay
extends Control

## Renders the manager-owned countdown without owning gameplay time.

@onready var reason_label: Label = %ReasonLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var ring: PanelContainer = %Ring

var _number_tween: Tween
var _visibility_tween: Tween


func _ready() -> void:
	GameManager.countdown_started.connect(_on_countdown_started)
	GameManager.countdown_tick.connect(_on_countdown_tick)
	GameManager.countdown_finished.connect(_on_countdown_finished)
	hide()


func _on_countdown_started(reason: String) -> void:
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()
	modulate.a = 1.0
	reason_label.text = "REVIVED" if reason == "revive" else "GET READY"
	countdown_label.text = str(GameManager.get_countdown_value())
	show()
	_animate_number()


func _on_countdown_tick(value: int, _reason: String) -> void:
	countdown_label.text = str(value)
	_animate_number()


func _on_countdown_finished(_reason: String) -> void:
	if _number_tween != null and _number_tween.is_valid():
		_number_tween.kill()
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_visibility_tween.tween_callback(
		func() -> void:
			hide()
			modulate.a = 1.0
	)


func _animate_number() -> void:
	if _number_tween != null and _number_tween.is_valid():
		_number_tween.kill()
	modulate.a = 1.0
	ring.scale = Vector2.ONE * 0.72
	countdown_label.modulate.a = 0.2
	_number_tween = create_tween().set_parallel(true)
	_number_tween.tween_property(ring, "scale", Vector2.ONE, 0.22).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_number_tween.tween_property(countdown_label, "modulate:a", 1.0, 0.12)
