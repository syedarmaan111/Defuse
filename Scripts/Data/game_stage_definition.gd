extends Resource
class_name GameStageDefinition

## Typed, reusable progression data shared by every game mode.

@export_range(1, 99, 1) var stage_number: int = 1
@export_range(2, 8, 1) var grid_side: int = 2
@export_range(1, 64, 1) var active_bombs: int = 1
@export_range(0.1, 60.0, 0.05) var timer_seconds: float = 2.6
@export_range(0, 1000000, 1) var starts_at: int = 0


func to_dictionary() -> Dictionary:
	return {
		"stage": stage_number,
		"grid_side": grid_side,
		"active_bombs": active_bombs,
		"timer_seconds": timer_seconds,
		"starts_at": starts_at,
	}


func is_valid() -> bool:
	return (
		stage_number > 0
		and grid_side >= 2
		and active_bombs > 0
		and active_bombs <= grid_side * grid_side
		and timer_seconds > 0.0
		and starts_at >= 0
	)
