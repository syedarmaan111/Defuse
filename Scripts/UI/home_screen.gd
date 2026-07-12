extends Control

## HomeScreen displays the supplied Home mockup and handles menu taps.
## It exists as the first screen in the app. The Play button starts only the
## UI gameplay shell in this milestone, not bombs or timers.
## Godot calls this script whenever the Home scene is visible in Main.

const PLAY_BUTTON_RECT := Rect2(185, 611, 654, 187)
const GEM_ICON_RECT := Rect2(735, 356, 86, 86)

@onready var mockup_base: TextureRect = %MockupBase
@onready var gem_icon_overlay: TextureRect = %GemIconOverlay
@onready var play_button: Button = %PlayButton

func _ready() -> void:
	## Connects UI events after children are ready.
	## The resized signal keeps the layout correct if the device changes size.
	resized.connect(_refresh_layout)
	play_button.pressed.connect(_on_play_pressed)
	_refresh_layout()


func _refresh_layout() -> void:
	## Repositions artwork, Gem overlay, and touch targets from mockup space.
	## This is what prevents fixed pixels from breaking on Android screens.
	UILayout.fit_to_design_frame(self, mockup_base)
	UILayout.place_in_design(self, gem_icon_overlay, GEM_ICON_RECT)
	UILayout.place_in_design(self, play_button, PLAY_BUTTON_RECT)


func _on_play_pressed() -> void:
	## Requests the gameplay UI screen.
	## Real gameplay startup is intentionally deferred to later milestones.
	GameManager.start_game()
