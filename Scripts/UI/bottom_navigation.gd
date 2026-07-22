extends PanelContainer
class_name BottomNavigation

## Shared navigation emits menu intent through UIManager and highlights the
## active destination without each screen duplicating navigation rules.

@export_enum("home", "shop", "profile") var active_screen := "home"

@onready var home_button: Button = %HomeButton
@onready var shop_button: Button = %ShopButton
@onready var profile_button: Button = %ProfileButton


func _ready() -> void:
	home_button.pressed.connect(UIManager.show_home)
	shop_button.pressed.connect(UIManager.show_shop)
	profile_button.pressed.connect(UIManager.show_profile)
	UIManager.menu_screen_changed.connect(set_active_screen)
	set_active_screen(active_screen)


func set_active_screen(screen_name: String) -> void:
	active_screen = screen_name
	home_button.button_pressed = screen_name == "home"
	shop_button.button_pressed = screen_name == "shop"
	profile_button.button_pressed = screen_name == "profile"


func get_active_screen() -> String:
	return active_screen
