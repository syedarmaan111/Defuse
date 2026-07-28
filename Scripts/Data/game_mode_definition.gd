extends Resource
class_name GameModeDefinition

## Stable-ID behavior metadata. Milestones 15-17 implement the specialized
## mechanics; shared screens and managers consume this contract now.

@export var mode_id: String = "endless"
@export var display_name: String = "Classic"
@export_multiline var rules_summary: String = ""
@export var score_label: String = "DEFUSALS"
@export_range(0, 1000000, 1) var unlock_lifetime_defusals: int = 0
@export_range(0, 99, 1) var maximum_lives: int = 3
@export var has_life_system: bool = true
@export var power_ups_enabled: bool = true
@export var grid_gem_rewards_enabled: bool = true
@export var rewarded_revive_enabled: bool = true
@export var lifetime_credit_enabled: bool = true
@export_range(0.0, 3600.0, 1.0) var run_duration_seconds: float = 0.0
@export var initial_phase_name: String = "RUNNING"
@export var stages: Array[GameStageDefinition] = []


func get_stage_for_progress(progress: int) -> GameStageDefinition:
	if stages.is_empty():
		return null
	var selected := stages[0]
	for definition in stages:
		if definition != null and progress >= definition.starts_at:
			selected = definition
	return selected


func is_valid() -> bool:
	if (
		mode_id.strip_edges().is_empty()
		or display_name.strip_edges().is_empty()
		or score_label.strip_edges().is_empty()
		or unlock_lifetime_defusals < 0
		or (has_life_system and maximum_lives <= 0)
		or (not has_life_system and maximum_lives != 0)
		or stages.is_empty()
	):
		return false
	for definition in stages:
		if definition == null or not definition.is_valid():
			return false
	return true
