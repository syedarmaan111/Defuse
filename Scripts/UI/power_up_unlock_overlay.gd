class_name PowerUpUnlockOverlay
extends Control

const UNLOCK_CARD := preload("res://Scenes/UI/Components/PowerUpUnlockCard.tscn")

@onready var popup: Control = %Popup
@onready var choice_status: Label = %ChoiceStatus
@onready var items: VBoxContainer = %Items


func _ready() -> void:
	PowerUpManager.unlock_choices_changed.connect(_on_unlock_choices_changed)


func show_if_pending() -> bool:
	if PowerUpManager.get_pending_unlock_choice_count() <= 0:
		hide()
		return false
	if PowerUpManager.get_checkpoint_candidates().is_empty():
		hide()
		return false
	_refresh_choices()
	show()
	_animate_popup()
	return true


func _refresh_choices() -> void:
	for child in items.get_children():
		items.remove_child(child)
		child.queue_free()
	var pending := PowerUpManager.get_pending_unlock_choice_count()
	choice_status.text = (
		"%d UNLOCKS READY — CHOOSE ONE NOW" % pending
		if pending > 1
		else "1 UNLOCK READY — CHOOSE YOUR POWER-UP"
	)
	for definition in PowerUpManager.get_checkpoint_candidates():
		var card: PowerUpUnlockCard = UNLOCK_CARD.instantiate()
		items.add_child(card)
		card.configure(definition)
		card.unlock_requested.connect(_on_unlock_requested)


func _on_unlock_requested(power_up_id: String) -> void:
	if not PowerUpManager.claim_checkpoint_power_up(power_up_id):
		return
	if PowerUpManager.get_pending_unlock_choice_count() <= 0:
		hide()
	else:
		_refresh_choices()


func _on_unlock_choices_changed(pending_count: int) -> void:
	if pending_count <= 0:
		hide()
	elif visible:
		_refresh_choices()
	else:
		show_if_pending()


func _animate_popup() -> void:
	popup.scale = Vector2.ONE * 0.94
	popup.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.18).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.16)
