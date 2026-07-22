extends Node

## Headless coverage for Milestone 6 menu navigation and Profile presentation.

const PROFILE_SCENE := preload("res://Scenes/UI/ProfileScreen.tscn")
const SHOP_SCENE := preload("res://Scenes/UI/ShopScreen.tscn")
const MAIN_SCENE := preload("res://Scenes/Main.tscn")
const GAMEPLAY_SCENE := preload("res://Scenes/Gameplay/Gameplay.tscn")


func _ready() -> void:
	_seed_profile_progression()
	await _test_profile_presentation()
	await _test_shop_currency_summary()
	await _test_main_menu_visibility()
	await _test_android_safe_life_icons()
	print("Milestone 6 smoke test passed.")
	get_tree().quit()


func _seed_profile_progression() -> void:
	var snapshot := SaveData.new().to_dictionary(false)
	snapshot["best_score"] = 42
	snapshot["lifetime_defusal_score"] = 735
	snapshot["currencies"] = {"gems": 17}
	snapshot["unlocked_powerup_ids"] = ["shield", "scan"]
	snapshot["owned_power_up_quantities"] = {"shield": 1}
	assert(SaveManager.apply_cloud_snapshot(snapshot))


func _test_profile_presentation() -> void:
	var profile := PROFILE_SCENE.instantiate()
	add_child(profile)
	await get_tree().process_frame

	var state: Dictionary = profile.get_presented_state()
	assert(state["skin_name"] == "Default Bomb")
	assert(state["has_skin_preview"])
	assert(state["best_score"] == "42")
	assert(state["lifetime_defusals"] == "735")
	assert(state["gems"] == "17")
	assert(state["owned_skins"] == "1")
	assert(state["unlocked_power_ups"] == "2")
	assert(state["has_settings_entry"])

	profile.get_node("%SettingsButton").pressed.emit()
	assert("Settings milestone" in profile.get_node("%SettingsStatus").text)
	profile.queue_free()


func _test_shop_currency_summary() -> void:
	var shop := SHOP_SCENE.instantiate()
	add_child(shop)
	await get_tree().process_frame
	assert(shop.get_presented_gem_balance() == "17")
	assert(EconomyManager.earn_gems(3))
	assert(shop.get_presented_gem_balance() == "20")
	shop.queue_free()


func _test_main_menu_visibility() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	GameManager.show_home_if_ready()

	UIManager.show_shop()
	assert(main.get_node("ScreenRoot/ShopScreen").visible)
	assert(not main.get_node("ScreenRoot/HomeScreen").visible)
	assert(not main.get_node("ScreenRoot/HomeScreen").has_node("SafeMargins/Content/BottomNavigation"))
	main.get_node("ScreenRoot/ShopScreen").get_node("%BackButton").pressed.emit()
	assert(main.get_node("ScreenRoot/HomeScreen").visible)
	UIManager.show_profile()
	assert(main.get_node("ScreenRoot/ProfileScreen").visible)
	assert(not main.get_node("ScreenRoot/ShopScreen").visible)
	main.get_node("ScreenRoot/ProfileScreen").get_node("%BackButton").pressed.emit()
	assert(main.get_node("ScreenRoot/HomeScreen").visible)
	main.queue_free()


func _test_android_safe_life_icons() -> void:
	var gameplay := GAMEPLAY_SCENE.instantiate()
	add_child(gameplay)
	await get_tree().process_frame
	for life_name in ["Life1", "Life2", "Life3"]:
		var life_icon = gameplay.get_node("%" + life_name)
		assert(life_icon is LifeHeart)
		assert(life_icon.filled)
		assert(life_icon.custom_minimum_size.x >= 48.0)
		assert(life_icon._build_heart_points(Vector2.ZERO).size() == 64)
	assert(gameplay.get_node("SafeMargins/Content/Lives/Caption").text == "LIVES")
	gameplay.queue_free()
