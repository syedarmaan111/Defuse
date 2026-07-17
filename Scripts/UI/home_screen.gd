extends Control

## HomeScreen renders the responsive Home layout and handles menu taps.
## It remains a menu shell until gameplay is implemented in later milestones.

@onready var play_button: Button = %PlayButton


func _ready() -> void:
	## Connects the real button after its container layout is ready.
	play_button.pressed.connect(_on_play_pressed)


func _on_play_pressed() -> void:
	## Requests the gameplay UI screen.
	## Real gameplay startup is intentionally deferred to later milestones.
	GameManager.start_game()
