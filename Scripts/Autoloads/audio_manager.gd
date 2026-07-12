extends Node

## AudioManager centralizes the paths to the supplied sound files.
## It exists so future gameplay requests named sounds instead of repeating raw
## asset paths. Playback is deliberately not implemented in this UI milestone.
## Godot creates this autoload before any gameplay scene needs sound access.

const SOUND_PATHS := {
	"bomb_armed": "res://Assets/Bomb/Audio/Bomb.wav",
	"bomb_defused": "res://Assets/Bomb/Audio/bomb pop.wav",
	"bomb_exploded": "res://Assets/Bomb/Audio/explode.wav"
}


func has_sound(sound_name: String) -> bool:
	## Checks whether a named sound is available.
	## Future callers use this before requesting playback from the audio service.
	return SOUND_PATHS.has(sound_name)


func get_sound_path(sound_name: String) -> String:
	## Returns the supplied asset path for a named sound.
	## Future playback code calls this after has_sound confirms the name exists.
	return str(SOUND_PATHS.get(sound_name, ""))
