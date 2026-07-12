extends Node

## GameManager owns the current UI flow for this milestone.
## It exists so buttons can request Home, Gameplay, Pause, Resume, and Game Over
## from one predictable place without implementing bombs, timers, or difficulty.
## Gameplay milestones will later add real run state behind these same methods.

signal screen_changed(screen_name: String)
signal game_over_requested(final_score: int, best_score: int)

enum ScreenName {
	HOME,
	GAMEPLAY,
	PAUSE,
	GAME_OVER
}

var current_screen: ScreenName = ScreenName.HOME
var previous_screen: ScreenName = ScreenName.HOME
var current_score: int = 0


func set_current_screen(next_screen: ScreenName) -> void:
	## Records the requested screen and tells Main which UI should be visible.
	## UI buttons call this indirectly through the public methods below.
	previous_screen = current_screen
	current_screen = next_screen
	screen_changed.emit(ScreenName.keys()[current_screen].to_lower())


func get_current_screen_name() -> String:
	## Returns a readable name for simple validation and future debug labels.
	return ScreenName.keys()[current_screen].to_lower()


func start_game() -> void:
	## Starts the UI run shell from Home or Play Again.
	## This does not create bombs, timers, score rules, or difficulty.
	current_score = 0
	set_current_screen(ScreenName.GAMEPLAY)


func pause_game() -> void:
	## Shows the Pause dialog over the visible gameplay screen.
	## It is called by the pause button in the gameplay mockup.
	if current_screen == ScreenName.GAMEPLAY:
		set_current_screen(ScreenName.PAUSE)


func resume_game() -> void:
	## Hides the Pause dialog and returns to the gameplay shell.
	## It is called by the Resume button on the pause screen.
	if current_screen == ScreenName.PAUSE:
		set_current_screen(ScreenName.GAMEPLAY)


func return_to_home() -> void:
	## Leaves any run-related UI and shows Home.
	## Pause Quit and Game Over Quit both use this path.
	current_score = 0
	set_current_screen(ScreenName.HOME)


func show_game_over(final_score: int = 0) -> void:
	## Shows the Game Over UI with placeholder scores for this UI-only milestone.
	## Later gameplay code will call this after the player loses all lives.
	current_score = max(final_score, 0)
	var best_score := 0
	if has_node("/root/SaveManager"):
		best_score = SaveManager.get_best_score()
	set_current_screen(ScreenName.GAME_OVER)
	game_over_requested.emit(current_score, best_score)
