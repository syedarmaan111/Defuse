extends Control

## GameOverScreen displays final values supplied by GameManager.
## The screen owns visual rendering and emits intent only.

@onready var score_label: Label = %ScoreLabel
@onready var best_score_label: Label = %BestScoreLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var revive_button: Button = %ReviveButton
@onready var quit_button: Button = %QuitButton
@onready var popup: Control = %Popup


func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	revive_button.pressed.connect(_on_revive_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	visibility_changed.connect(_animate_popup)
	GameManager.revive_availability_changed.connect(_on_revive_availability_changed)
	NetworkManager.internet_availability_changed.connect(
		func(_is_available: bool) -> void: _refresh_revive_button()
	)
	set_scores(0, 0)
	_refresh_revive_button()


func set_scores(final_score: int, best_score: int) -> void:
	## Updates visible score values when a run ends.
	score_label.text = str(max(final_score, 0))
	best_score_label.text = str(max(best_score, 0))


func _animate_popup() -> void:
	## Replays the shared modal entrance whenever this overlay becomes visible.
	if not visible:
		return
	_refresh_revive_button()
	popup.scale = Vector2.ONE * 0.94
	popup.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.16)


func _on_play_again_pressed() -> void:
	GameManager.start_game()


func _on_revive_pressed() -> void:
	if not GameManager.request_rewarded_revive():
		_refresh_revive_button()
		return
	revive_button.disabled = true
	revive_button.text = "REWARD REQUESTED..."


func _on_revive_availability_changed(_is_available: bool) -> void:
	_refresh_revive_button()


func _refresh_revive_button() -> void:
	var is_available := GameManager.can_offer_rewarded_revive()
	revive_button.visible = is_available
	revive_button.disabled = not is_available
	revive_button.text = "WATCH AD TO REVIVE\nCONTINUE WITH 1 LIFE"


func _on_quit_pressed() -> void:
	GameManager.return_to_home()
