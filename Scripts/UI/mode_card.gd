extends PanelContainer
class_name ModeCard

signal play_requested(mode_id: String)

@onready var name_label: Label = %NameLabel
@onready var rules_label: Label = %RulesLabel
@onready var record_label: Label = %RecordLabel
@onready var unlock_label: Label = %UnlockLabel
@onready var unlock_progress: ProgressBar = %UnlockProgress
@onready var play_button: Button = %PlayButton
@onready var background_art: TextureRect = %BackgroundArt

var mode_id := ""

const MODE_ART := {
	"endless": "res://Assets/UI/GameModes/classic.png",
	"zen": "res://Assets/UI/GameModes/zen.png",
	"memory": "res://Assets/UI/GameModes/memory.png",
	"time_attack": "res://Assets/UI/GameModes/time_attack.png",
	"precision": "res://Assets/UI/GameModes/precision.png",
	"hardcore": "res://Assets/UI/GameModes/hardcore.png",
}


func _ready() -> void:
	play_button.pressed.connect(
		func() -> void: play_requested.emit(mode_id)
	)


func configure(
	definition: GameModeDefinition,
	best_score: int,
	lifetime_defusals: int,
	is_unlocked: bool
) -> void:
	mode_id = definition.mode_id
	name = "Mode_%s" % mode_id
	background_art.texture = load(str(MODE_ART.get(mode_id, ""))) as Texture2D
	name_label.text = definition.display_name.to_upper()
	rules_label.text = definition.rules_summary
	record_label.text = (
		"MAXIMUM LEVEL REACHED  %d" % max(best_score, 0)
		if definition.mode_id in ["precision", "memory"]
		else "BEST  %d  %s" % [max(best_score, 0), definition.score_label]
	)
	if is_unlocked:
		unlock_label.text = "AVAILABLE NOW"
		unlock_progress.max_value = 1.0
		unlock_progress.value = 1.0
	else:
		unlock_label.text = "%d / %d LIFETIME DEFUSALS" % [
			min(lifetime_defusals, definition.unlock_lifetime_defusals),
			definition.unlock_lifetime_defusals,
		]
		unlock_progress.max_value = definition.unlock_lifetime_defusals
		unlock_progress.value = min(
			lifetime_defusals, definition.unlock_lifetime_defusals
		)
	play_button.disabled = not is_unlocked
	play_button.text = "PLAY  >" if is_unlocked else "LOCKED"
	modulate = Color.WHITE if is_unlocked else Color(0.76, 0.75, 0.71, 1.0)


func get_presented_state() -> Dictionary:
	return {
		"mode_id": mode_id,
		"display_name": name_label.text,
		"record": record_label.text,
		"unlock": unlock_label.text,
		"unlocked": not play_button.disabled,
	}
