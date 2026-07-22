extends Control

## SaveConflictDialog renders two read-only summaries and requires an explicit
## source choice. It never decides which progression branch is preferable.

@onready var local_summary_label: Label = %LocalSummaryLabel
@onready var cloud_summary_label: Label = %CloudSummaryLabel
@onready var local_button: Button = %LocalButton
@onready var cloud_button: Button = %CloudButton
@onready var dialog_panel: Control = %DialogPanel


func _ready() -> void:
	local_button.pressed.connect(_on_local_pressed)
	cloud_button.pressed.connect(_on_cloud_pressed)
	visible = false


func show_conflict(local_summary: Dictionary, cloud_summary: Dictionary) -> void:
	local_summary_label.text = _format_summary(local_summary)
	cloud_summary_label.text = _format_summary(cloud_summary)
	local_button.disabled = false
	cloud_button.disabled = false
	visible = true
	dialog_panel.pivot_offset = dialog_panel.size * 0.5
	dialog_panel.scale = Vector2.ONE * 0.94
	dialog_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(dialog_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.16)


func _format_summary(summary: Dictionary) -> String:
	var modified_at := int(summary.get("modified_at_unix", 0))
	var modified_text := "First launch"
	if modified_at > 0:
		modified_text = Time.get_datetime_string_from_unix_time(modified_at, true)
	return "Best score: %d\nLifetime defusals: %d\nGems: %d\nRevision: %d\nUpdated: %s" % [
		int(summary.get("best_score", 0)),
		int(summary.get("lifetime_defusal_score", 0)),
		int(summary.get("gems", 0)),
		int(summary.get("save_revision", 0)),
		modified_text,
	]


func _on_local_pressed() -> void:
	_disable_actions()
	if CloudSaveManager.resolve_conflict(CloudSaveManager.SOURCE_LOCAL):
		visible = false
	else:
		local_button.disabled = false
		cloud_button.disabled = false


func _on_cloud_pressed() -> void:
	_disable_actions()
	if CloudSaveManager.resolve_conflict(CloudSaveManager.SOURCE_CLOUD):
		visible = false
	else:
		local_button.disabled = false
		cloud_button.disabled = false


func _disable_actions() -> void:
	local_button.disabled = true
	cloud_button.disabled = true
