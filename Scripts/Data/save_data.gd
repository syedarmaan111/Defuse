extends RefCounted
class_name SaveData

## SaveData documents the shape of values that SaveManager keeps permanently.
## It exists as a beginner-friendly data model for future save/load expansion.
## It is used when a system needs a complete in-memory save record.

var best_score: int = 0
var total_gems: int = 0
var selected_skin: String = "default_bomb"


func to_dictionary() -> Dictionary:
	## Converts the record into JSON-friendly values.
	## Save code calls this immediately before writing a save file.
	return {
		"best_score": best_score,
		"total_gems": total_gems,
		"selected_skin": selected_skin
	}
