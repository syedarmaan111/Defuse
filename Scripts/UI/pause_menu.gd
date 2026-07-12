extends Control

## PauseMenu shows a sharp pause dialog over blurred gameplay.
## It exists when the player taps Pause during the gameplay UI shell.
## Resume returns to gameplay, while Quit returns to Home.

const DIALOG_RECT := Rect2(260, 665, 504, 494)
const RESUME_BUTTON_RECT := Rect2(309, 820, 405, 124)
const QUIT_BUTTON_RECT := Rect2(309, 974, 405, 124)

@onready var dialog_image: TextureRect = %DialogImage
@onready var resume_button: Button = %ResumeButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	## Connects overlay buttons after the scene is ready.
	## Resizing keeps the cropped dialog aligned to the original mockup.
	resized.connect(_refresh_layout)
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_refresh_layout()


func _refresh_layout() -> void:
	## Places the sharp dialog crop and invisible buttons in mockup space.
	## The blur is full-screen, but the dialog remains a normal crisp texture.
	UILayout.place_in_design(self, dialog_image, DIALOG_RECT)
	UILayout.place_in_design(self, resume_button, RESUME_BUTTON_RECT)
	UILayout.place_in_design(self, quit_button, QUIT_BUTTON_RECT)


func _on_resume_pressed() -> void:
	## Closes Pause and returns to the gameplay UI shell.
	## Future gameplay timers can resume from this same manager call.
	GameManager.resume_game()


func _on_quit_pressed() -> void:
	## Leaves the run UI and returns to Home.
	## This does not save or modify gameplay because gameplay is not implemented.
	GameManager.return_to_home()
