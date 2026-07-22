extends Resource
class_name ShopOfferDefinition

## A provider-neutral bundle/offer record for later real-money integration.

@export var offer_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var is_available: bool = true
@export var icon: Texture2D
@export var granted_content_ids: Array[String] = []
@export var acquisition_options: Array[AcquisitionOption] = []
