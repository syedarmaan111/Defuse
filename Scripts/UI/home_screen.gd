extends Control

## HomeScreen renders saved summary values and handles primary menu shortcuts.

@onready var play_button: Button = %PlayButton
@onready var shop_button: Button = %ShopButton
@onready var profile_button: Button = %ProfileButton
@onready var gem_value: Label = %GemValue
@onready var best_score_value: Label = %BestScoreValue


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	shop_button.pressed.connect(UIManager.show_shop)
	profile_button.pressed.connect(UIManager.show_profile)
	SaveManager.save_loaded.connect(_on_save_snapshot)
	SaveManager.save_changed.connect(_on_save_snapshot)
	EconomyManager.currency_changed.connect(_on_currency_changed)
	_refresh_summary()


func _on_play_pressed() -> void:
	## Requests the gameplay UI screen.
	## Real gameplay startup is intentionally deferred to later milestones.
	GameManager.start_game()


func _on_save_snapshot(_snapshot: Dictionary) -> void:
	_refresh_summary()


func _on_currency_changed(currency_id: String, _new_balance: int) -> void:
	if currency_id == EconomyManager.GEM_CURRENCY_ID:
		_refresh_summary()


func _refresh_summary() -> void:
	gem_value.text = str(EconomyManager.get_gem_balance())
	best_score_value.text = str(SaveManager.get_best_score())
