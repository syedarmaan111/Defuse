extends Control

## GameOverScreen displays final values supplied by GameManager.
## The screen owns visual rendering and emits intent only.

@onready var score_label: Label = %ScoreLabel
@onready var best_score_label: Label = %BestScoreLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var quit_button: Button = %QuitButton
@onready var popup: Control = %Popup


func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	visibility_changed.connect(_animate_popup)
	set_scores(0, 0)


func set_scores(final_score: int, best_score: int) -> void:
	## Updates visible score values when a run ends.
	score_label.text = str(max(final_score, 0))
	best_score_label.text = str(max(best_score, 0))


func _animate_popup() -> void:
	## Replays the shared modal entrance whenever this overlay becomes visible.
	if not visible:
		return
	popup.scale = Vector2.ONE * 0.94
	popup.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.16)


func _on_play_again_pressed() -> void:
	GameManager.start_game()


func _on_quit_pressed() -> void:
	GameManager.return_to_home()
