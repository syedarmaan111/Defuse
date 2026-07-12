extends Node

## SaveManager owns the permanent values that must survive closing the app.
## It exists so UI screens and future gameplay systems have one safe place to
## read and write Best Score, total Gems, and selected skin data.
## Godot creates this autoload before Main, then _ready loads saved values.

const SAVE_PATH := "user://save_data.json"
const DEFAULT_SELECTED_SKIN := "default_bomb"

var best_score: int = 0
var total_gems: int = 0
var selected_skin: String = DEFAULT_SELECTED_SKIN


func _ready() -> void:
	## Loads saved data when Godot creates the autoload at app startup.
	## This makes values available before Home and other UI screens appear.
	load_save()


func load_save() -> void:
	## Reads the local save file or restores safe defaults when it is absent.
	## It is called on app startup and avoids a crash from missing/corrupt data.
	if not FileAccess.file_exists(SAVE_PATH):
		_apply_default_save()
		return

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		_apply_default_save()
		return

	var parsed_data = JSON.parse_string(save_file.get_as_text())
	if typeof(parsed_data) != TYPE_DICTIONARY:
		_apply_default_save()
		return

	best_score = int(parsed_data.get("best_score", 0))
	total_gems = int(parsed_data.get("total_gems", 0))
	selected_skin = str(parsed_data.get("selected_skin", DEFAULT_SELECTED_SKIN))


func save_now() -> void:
	## Writes the current permanent values to disk.
	## Setter methods call this immediately after a persistent value changes.
	var save_data := {
		"best_score": best_score,
		"total_gems": total_gems,
		"selected_skin": selected_skin
	}

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(JSON.stringify(save_data, "\t"))


func get_best_score() -> int:
	## Returns the saved best score for Home and future result screens.
	return best_score


func set_best_score(value: int) -> void:
	## Stores a non-negative best score and saves it immediately.
	## Future game-over logic will call this only when a run beats the old score.
	best_score = max(value, 0)
	save_now()


func get_total_gems() -> int:
	## Returns the player's permanent Gem balance for UI displays.
	return total_gems


func set_total_gems(value: int) -> void:
	## Stores the permanent Gem total and saves it immediately.
	## Future Gem rewards will call this after a successful collection.
	total_gems = max(value, 0)
	save_now()


func get_selected_skin() -> String:
	## Returns the saved skin identifier for future bomb visual selection.
	return selected_skin


func set_selected_skin(skin_id: String) -> void:
	## Saves the selected skin identifier.
	## The future shop will call this when the player chooses a skin.
	selected_skin = skin_id
	save_now()


func _apply_default_save() -> void:
	## Restores known-safe first-launch values.
	## Load failures call this so the UI always receives usable data.
	best_score = 0
	total_gems = 0
	selected_skin = DEFAULT_SELECTED_SKIN
