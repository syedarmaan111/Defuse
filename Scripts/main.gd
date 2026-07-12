extends Node

## Main controls which top-level UI scene is visible.
## It exists because Home, Gameplay, Pause, and Game Over are separate screens
## that need one coordinator. Game rules stay out of this script.
## Godot calls this script when the main scene starts.

@onready var home_screen: Control = $ScreenRoot/HomeScreen
@onready var gameplay_screen: Control = $ScreenRoot/Gameplay
@onready var pause_menu: Control = $OverlayRoot/PauseMenu
@onready var game_over_screen: Control = $OverlayRoot/GameOverScreen


func _ready() -> void:
	## Connects manager signals once the scene tree exists.
	## The first refresh ensures the game opens on Home.
	GameManager.screen_changed.connect(_on_screen_changed)
	GameManager.game_over_requested.connect(_on_game_over_requested)
	_on_screen_changed(GameManager.get_current_screen_name())


func _on_screen_changed(screen_name: String) -> void:
	## Shows one base screen and optional overlay based on GameManager state.
	## Pause and Game Over keep gameplay visible behind their popups.
	home_screen.visible = screen_name == "home"
	gameplay_screen.visible = screen_name in ["gameplay", "pause", "game_over"]
	pause_menu.visible = screen_name == "pause"
	game_over_screen.visible = screen_name == "game_over"


func _on_game_over_requested(final_score: int, best_score: int) -> void:
	## Passes score text into the Game Over screen.
	## During this UI milestone these values are placeholders supplied by callers.
	game_over_screen.set_scores(final_score, best_score)
