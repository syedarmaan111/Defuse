extends Control

## Gameplay displays the supplied gameplay mockup as a UI-only shell.
## It exists so Pause and Game Over can be tested over a realistic gameplay
## background before bomb, timer, score, or difficulty systems are implemented.
## Godot calls this script while the Gameplay scene is visible under Main.

const PAUSE_BUTTON_RECT := Rect2(46, 317, 124, 143)
const GEM_ICON_RECT := Rect2(768, 350, 74, 74)

@onready var mockup_base: TextureRect = %MockupBase
@onready var gem_icon_overlay: TextureRect = %GemIconOverlay
@onready var pause_button: Button = %PauseButton

func _ready() -> void:
	## Connects the Pause button only.
	## No bomb grid logic is created in this milestone.
	resized.connect(_refresh_layout)
	pause_button.pressed.connect(_on_pause_pressed)
	_refresh_layout()


func _refresh_layout() -> void:
	## Keeps the full gameplay mockup and invisible pause touch area aligned.
	## It is called on startup and whenever the viewport size changes.
	UILayout.fit_to_design_frame(self, mockup_base)
	UILayout.place_in_design(self, gem_icon_overlay, GEM_ICON_RECT)
	UILayout.place_in_design(self, pause_button, PAUSE_BUTTON_RECT)


func _on_pause_pressed() -> void:
	## Requests the Pause overlay from GameManager.
	## Active gameplay timers do not exist yet, so this only changes UI state.
	GameManager.pause_game()
