extends Resource
class_name PowerUpDefinition

## Catalog metadata and tunable gameplay values for one automatic power-up.

enum EffectType {
	SHIELD,
	SLOW_MOTION,
	SCAN,
	EXTRA_LIFE,
	COMBO_BOOST,
	CHAIN_DEFUSE,
}

@export var content_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var is_available: bool = true
@export var icon: Texture2D
@export var effect_type: EffectType = EffectType.SHIELD
@export_range(0.0, 60.0, 0.1) var duration_seconds: float = 0.0
@export_range(0.0, 10.0, 0.05) var effect_strength: float = 1.0
@export var acquisition_options: Array[AcquisitionOption] = []


func has_acquisition_type(type: AcquisitionOption.AcquisitionType) -> bool:
	for option in acquisition_options:
		if option != null and option.acquisition_type == type:
			return true
	return false
