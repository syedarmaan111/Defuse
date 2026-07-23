extends Control

## ProfileScreen presents saved progression only. It never mutates inventory,
## currency, or gameplay state.

@onready var skin_preview: TextureRect = %SkinPreview
@onready var skin_name_label: Label = %SkinNameLabel
@onready var best_score_card: ProfileStatCard = %BestScoreCard
@onready var lifetime_card: ProfileStatCard = %LifetimeCard
@onready var gems_card: ProfileStatCard = %GemsCard
@onready var skins_card: ProfileStatCard = %SkinsCard
@onready var power_ups_card: ProfileStatCard = %PowerUpsCard
@onready var settings_button: Button = %SettingsButton
@onready var settings_status: Label = %SettingsStatus
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(UIManager.show_home)
	SaveManager.save_loaded.connect(_on_save_snapshot)
	SaveManager.save_changed.connect(_on_save_snapshot)
	SkinManager.skin_equipped.connect(_on_skin_equipped)
	settings_button.pressed.connect(_on_settings_pressed)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_profile(SaveManager.get_snapshot())


func get_presented_state() -> Dictionary:
	## Exposes the rendered values for lightweight headless UI validation.
	return {
		"skin_name": skin_name_label.text,
		"has_skin_preview": skin_preview.texture != null,
		"best_score": best_score_card.get_value(),
		"lifetime_defusals": lifetime_card.get_value(),
		"gems": gems_card.get_value(),
		"owned_skins": skins_card.get_value(),
		"unlocked_power_ups": power_ups_card.get_value(),
		"has_settings_entry": settings_button != null,
	}


func _on_save_snapshot(snapshot: Dictionary) -> void:
	_refresh_profile(snapshot)


func _on_skin_equipped(_skin_id: String) -> void:
	_refresh_skin()


func _on_visibility_changed() -> void:
	if visible and is_node_ready():
		_refresh_profile(SaveManager.get_snapshot())


func _refresh_profile(snapshot: Dictionary) -> void:
	best_score_card.set_value(max(int(snapshot.get("best_score", 0)), 0))
	lifetime_card.set_value(max(int(snapshot.get("lifetime_defusal_score", 0)), 0))
	gems_card.set_value(EconomyManager.get_gem_balance())
	skins_card.set_value(SkinManager.get_owned_skin_ids().size())
	power_ups_card.set_value(PowerUpManager.get_unlocked_ids().size())
	_refresh_skin()


func _refresh_skin() -> void:
	var definition := SkinManager.get_equipped_skin()
	if definition == null:
		skin_preview.texture = null
		skin_name_label.text = "Default Bomb"
		return
	skin_preview.texture = definition.idle_texture if definition.idle_texture != null else definition.icon
	skin_name_label.text = definition.display_name


func _on_settings_pressed() -> void:
	UIManager.show_settings()
