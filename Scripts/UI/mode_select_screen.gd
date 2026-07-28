extends Control

## Responsive, data-driven mode selector. Cards never own unlock or start rules.

const MODE_CARD_SCENE := preload("res://Scenes/UI/Components/ModeCard.tscn")

@onready var back_button: Button = %BackButton
@onready var lifetime_label: Label = %LifetimeLabel
@onready var cards: VBoxContainer = %Cards
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	back_button.pressed.connect(GameManager.return_to_home)
	SaveManager.save_loaded.connect(_on_save_snapshot)
	SaveManager.save_changed.connect(_on_save_snapshot)
	GameManager.mode_start_rejected.connect(_on_mode_start_rejected)
	visibility_changed.connect(_on_visibility_changed)
	_rebuild_cards()


func get_presented_state() -> Dictionary:
	var mode_states := {}
	for child in cards.get_children():
		if child is ModeCard:
			var state: Dictionary = child.get_presented_state()
			mode_states[state["mode_id"]] = state
	return {
		"lifetime": lifetime_label.text,
		"modes": mode_states,
	}


func _on_save_snapshot(_snapshot: Dictionary) -> void:
	if visible:
		_rebuild_cards()


func _on_visibility_changed() -> void:
	if visible and is_node_ready():
		status_label.text = ""
		_rebuild_cards()


func _rebuild_cards() -> void:
	if not is_node_ready():
		return
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var lifetime := SaveManager.get_lifetime_defusals()
	lifetime_label.text = "%d LIFETIME DEFUSALS" % lifetime
	for definition in GameManager.get_mode_definitions():
		var card := MODE_CARD_SCENE.instantiate() as ModeCard
		cards.add_child(card)
		card.configure(
			definition,
			SaveManager.get_mode_best_score(definition.mode_id),
			lifetime,
			GameManager.is_mode_unlocked(definition.mode_id)
		)
		card.play_requested.connect(_on_play_requested)


func _on_play_requested(mode_id: String) -> void:
	status_label.text = ""
	GameManager.start_game(mode_id)


func _on_mode_start_rejected(mode_id: String, reason: String) -> void:
	var definition := GameManager.MODE_CATALOG.get_mode(mode_id)
	var mode_name := definition.display_name if definition != null else "That mode"
	status_label.text = (
		"%s unlocks with more lifetime defusals." % mode_name
		if reason == "locked"
		else "%s is unavailable." % mode_name
	)
