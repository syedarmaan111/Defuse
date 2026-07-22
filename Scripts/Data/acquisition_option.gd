extends Resource
class_name AcquisitionOption

## Describes one supported way to permanently acquire catalog content.
## Provider-specific purchase work remains in the later commerce milestone.

enum AcquisitionType {
	DEFAULT_GRANT,
	GEM_PURCHASE,
	LIFETIME_SCORE_CHECKPOINT,
	REAL_MONEY_PURCHASE,
}

@export var acquisition_type: AcquisitionType = AcquisitionType.DEFAULT_GRANT
@export_range(0, 1000000, 1) var gem_cost: int = 0
@export_range(0, 1000000, 1) var lifetime_score_required: int = 0
@export var product_id: String = ""


func is_valid() -> bool:
	## Rejects incomplete catalog entries before a Shop or purchase flow uses them.
	match acquisition_type:
		AcquisitionType.DEFAULT_GRANT:
			return true
		AcquisitionType.GEM_PURCHASE:
			return gem_cost > 0
		AcquisitionType.LIFETIME_SCORE_CHECKPOINT:
			return lifetime_score_required > 0
		AcquisitionType.REAL_MONEY_PURCHASE:
			return not product_id.strip_edges().is_empty()
	return false
