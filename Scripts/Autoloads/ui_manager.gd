extends Node

## UIManager owns navigation between the non-gameplay menu sections. Main keeps
## responsibility for displaying the current top-level launch/gameplay state.

signal menu_screen_changed(screen_name: String)

enum MenuScreen {
	HOME,
	SHOP,
	PROFILE,
	SETTINGS,
}

var _current_menu_screen: MenuScreen = MenuScreen.HOME


func show_home() -> void:
	_set_menu_screen(MenuScreen.HOME)


func show_shop() -> void:
	_set_menu_screen(MenuScreen.SHOP)


func show_profile() -> void:
	_set_menu_screen(MenuScreen.PROFILE)


func show_settings() -> void:
	_set_menu_screen(MenuScreen.SETTINGS)


func get_current_menu_screen_name() -> String:
	return MenuScreen.keys()[_current_menu_screen].to_lower()


func _set_menu_screen(next_screen: MenuScreen) -> void:
	## Re-emitting is useful when Main has just returned from gameplay and needs
	## to restore the selected menu screen, even if the value did not change.
	_current_menu_screen = next_screen
	menu_screen_changed.emit(get_current_menu_screen_name())
