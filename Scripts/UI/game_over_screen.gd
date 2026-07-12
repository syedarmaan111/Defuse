extends Control

## GameOverScreen shows the end-of-run UI over blurred gameplay.
## It is used after future gameplay calls GameManager.show_game_over().
## In this milestone it is fully visual and interactive, but it does not decide
## why the run ended or calculate score.

const DIALOG_RECT := Rect2(224, 406, 576, 806)
const YOUR_SCORE_TITLE_RECT := Rect2(384, 647, 256, 48)
const SCORE_LABEL_RECT := Rect2(438, 725, 148, 62)
const BEST_SCORE_PANEL_MASK_RECT := Rect2(289, 798, 446, 118)
const BEST_SCORE_TITLE_RECT := Rect2(360, 815, 304, 44)
const BEST_SCORE_LABEL_RECT := Rect2(438, 858, 148, 54)
const PLAY_AGAIN_BUTTON_RECT := Rect2(289, 946, 446, 96)
const QUIT_BUTTON_RECT := Rect2(289, 1071, 446, 91)

@onready var dialog_image: TextureRect = %DialogImage
@onready var your_score_title: Label = %YourScoreTitle
@onready var best_score_panel_mask: ColorRect = %BestScorePanelMask
@onready var best_score_title: Label = %BestScoreTitle
@onready var score_label: Label = %ScoreLabel
@onready var best_score_label: Label = %BestScoreLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	## Connects buttons and performs the first responsive placement.
	## The screen starts with zeroes until Main passes real values.
	resized.connect(_refresh_layout)
	play_again_button.pressed.connect(_on_play_again_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	set_scores(0, 0)
	_refresh_layout()


func set_scores(final_score: int, best_score: int) -> void:
	## Updates visible score values.
	## Main calls this when GameManager requests the Game Over screen.
	score_label.text = str(max(final_score, 0))
	best_score_label.text = str(max(best_score, 0))


func _refresh_layout() -> void:
	## Keeps the popup, labels, and buttons aligned to the mockup.
	## It is called on startup and any time the viewport dimensions change.
	UILayout.place_in_design(self, dialog_image, DIALOG_RECT)
	UILayout.place_in_design(self, your_score_title, YOUR_SCORE_TITLE_RECT)
	UILayout.place_in_design(self, best_score_panel_mask, BEST_SCORE_PANEL_MASK_RECT)
	UILayout.place_in_design(self, best_score_title, BEST_SCORE_TITLE_RECT)
	UILayout.place_in_design(self, score_label, SCORE_LABEL_RECT)
	UILayout.place_in_design(self, best_score_label, BEST_SCORE_LABEL_RECT)
	UILayout.place_in_design(self, play_again_button, PLAY_AGAIN_BUTTON_RECT)
	UILayout.place_in_design(self, quit_button, QUIT_BUTTON_RECT)


func _on_play_again_pressed() -> void:
	## Starts a fresh UI run shell.
	## Real gameplay reset will be attached to this manager call later.
	GameManager.start_game()


func _on_quit_pressed() -> void:
	## Returns to Home from the Game Over screen.
	## No gameplay cleanup is needed yet because gameplay is still a mockup.
	GameManager.return_to_home()
