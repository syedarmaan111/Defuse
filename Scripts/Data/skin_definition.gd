extends Resource
class_name SkinDefinition

## A complete data record for one bomb skin. Adding a normal skin should only
## require its supplied assets, a resource file, and a catalog entry.

@export var content_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var is_available: bool = true
@export var icon: Texture2D
@export var idle_texture: Texture2D
@export_dir var armed_frames_directory: String = ""
@export var armed_audio: AudioStream
@export var defuse_audio: AudioStream
@export var explosion_audio: AudioStream
@export var acquisition_options: Array[AcquisitionOption] = []


func has_acquisition_type(type: AcquisitionOption.AcquisitionType) -> bool:
	for option in acquisition_options:
		if option != null and option.acquisition_type == type:
			return true
	return false
