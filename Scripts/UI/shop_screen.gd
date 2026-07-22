extends Control

## Catalog-driven Shop presentation. Business rules remain in ShopManager.

const SHOP_CARD := preload("res://Scenes/UI/Components/ShopCard.tscn")

var _active_category := ShopManager.CATEGORY_SKINS
var _active_content_id := ""

@onready var gem_value: Label = %GemValue
@onready var back_button: Button = %BackButton
@onready var skins_tab: Button = %SkinsTab
@onready var power_ups_tab: Button = %PowerUpsTab
@onready var purchases_tab: Button = %PurchasesTab
@onready var section_title: Label = %SectionTitle
@onready var items: VBoxContainer = %Items
@onready var empty_state: VBoxContainer = %EmptyState
@onready var empty_title: Label = %EmptyTitle
@onready var empty_description: Label = %EmptyDescription
@onready var detail_dialog: ShopDetailDialog = %ShopDetailDialog
@onready var confirmation_dialog: ShopConfirmationDialog = %ShopConfirmationDialog
@onready var feedback_dialog: ShopFeedbackDialog = %ShopFeedbackDialog


func _ready() -> void:
	back_button.pressed.connect(UIManager.show_home)
	skins_tab.pressed.connect(select_category.bind(ShopManager.CATEGORY_SKINS))
	power_ups_tab.pressed.connect(select_category.bind(ShopManager.CATEGORY_POWER_UPS))
	purchases_tab.pressed.connect(select_category.bind(ShopManager.CATEGORY_PURCHASES))
	detail_dialog.acquisition_requested.connect(_on_acquisition_requested)
	detail_dialog.equip_requested.connect(ShopManager.request_equip)
	confirmation_dialog.confirmed.connect(ShopManager.request_acquisition)
	EconomyManager.currency_changed.connect(_on_currency_changed)
	ShopManager.inventory_updated.connect(_on_inventory_updated)
	ShopManager.acquisition_succeeded.connect(_on_acquisition_succeeded)
	ShopManager.acquisition_failed.connect(_on_acquisition_failed)
	_refresh_gems()
	select_category(_active_category)


func select_category(category_id: String) -> void:
	if category_id not in [
		ShopManager.CATEGORY_SKINS,
		ShopManager.CATEGORY_POWER_UPS,
		ShopManager.CATEGORY_PURCHASES,
	]:
		return
	_active_category = category_id
	skins_tab.button_pressed = category_id == ShopManager.CATEGORY_SKINS
	power_ups_tab.button_pressed = category_id == ShopManager.CATEGORY_POWER_UPS
	purchases_tab.button_pressed = category_id == ShopManager.CATEGORY_PURCHASES
	section_title.text = {
		ShopManager.CATEGORY_SKINS: "BOMB SKINS",
		ShopManager.CATEGORY_POWER_UPS: "POWER-UPS",
		ShopManager.CATEGORY_PURCHASES: "PURCHASES",
	}[category_id]
	_rebuild_cards()


func get_presented_gem_balance() -> String:
	return gem_value.text


func get_presented_category_count() -> int:
	return items.get_child_count()


func get_presented_card_states() -> Array[String]:
	var states: Array[String] = []
	for card in items.get_children():
		if card is ShopCard:
			states.append(card.get_presented_state())
	return states


func get_active_category() -> String:
	return _active_category


func _rebuild_cards() -> void:
	for child in items.get_children():
		items.remove_child(child)
		child.queue_free()
	var definitions := ShopManager.get_category_items(_active_category)
	empty_state.visible = definitions.is_empty()
	if definitions.is_empty():
		_set_empty_copy()
		return
	for definition in definitions:
		var card: ShopCard = SHOP_CARD.instantiate()
		items.add_child(card)
		card.configure(definition)
		card.details_requested.connect(_show_details)


func _set_empty_copy() -> void:
	if _active_category == ShopManager.CATEGORY_PURCHASES:
		empty_title.text = "NO PURCHASES AVAILABLE"
		empty_description.text = "There are no paid offers in the catalog. Gems are earned during gameplay and are never sold."
	else:
		empty_title.text = "NOTHING HERE YET"
		empty_description.text = "New catalog entries will appear here automatically."


func _show_details(content_id: String) -> void:
	var definition := ShopManager.get_definition(content_id)
	if definition == null:
		return
	_active_content_id = content_id
	detail_dialog.show_content(definition)


func _on_acquisition_requested(
	content_id: String,
	acquisition_type: AcquisitionOption.AcquisitionType
) -> void:
	var definition := ShopManager.get_definition(content_id)
	if definition == null:
		return
	var display_name := str(definition.get("display_name"))
	var message := "Purchase {item}?"
	if acquisition_type == AcquisitionOption.AcquisitionType.GEM_PURCHASE:
		for option in ShopManager.get_acquisition_options(content_id):
			if option.acquisition_type == acquisition_type:
				message = "Unlock {item} for %d earned Gems?" % option.gem_cost
				break
	else:
		message = "Continue to the purchase provider for {item}?"
	confirmation_dialog.show_confirmation(
		content_id, acquisition_type, display_name, message
	)


func _on_currency_changed(currency_id: String, _new_balance: int) -> void:
	if currency_id == EconomyManager.GEM_CURRENCY_ID:
		_refresh_gems()


func _on_inventory_updated() -> void:
	_refresh_gems()
	_rebuild_cards()
	if detail_dialog.visible and not _active_content_id.is_empty():
		detail_dialog.refresh_state()


func _on_acquisition_succeeded(content_id: String, result_code: String) -> void:
	var definition := ShopManager.get_definition(content_id)
	var display_name := str(definition.get("display_name")) if definition != null else "Item"
	var message := "%s is now equipped." % display_name if result_code in ["equipped", "already_equipped"] else "%s is now owned." % display_name
	feedback_dialog.show_feedback("SUCCESS", message)
	if detail_dialog.visible:
		detail_dialog.refresh_state()


func _on_acquisition_failed(content_id: String, error_code: String) -> void:
	var definition := ShopManager.get_definition(content_id)
	var display_name := str(definition.get("display_name")) if definition != null else "This item"
	var title := "PURCHASE FAILED"
	var message := "The purchase could not be completed."
	match error_code:
		"insufficient_gems":
			title = "NOT ENOUGH GEMS"
			message = "Earn more Gems by defusing reward bombs. Gems are never sold."
		"provider_unavailable":
			message = "Purchases will become available when Play Billing is connected in the release milestone."
		"internet_required":
			title = "INTERNET REQUIRED"
			message = "Reconnect before starting an online purchase."
		"purchase_cancelled":
			title = "PURCHASE CANCELLED"
			message = "No charge was made."
		"already_owned":
			title = "ALREADY OWNED"
			message = "%s is already in your inventory." % display_name
		"checkpoint_choice_required":
			title = "CHECKPOINT REWARD"
			message = "Power-ups are chosen after each eligible 500-defusal checkpoint."
	feedback_dialog.show_feedback(title, message)


func _refresh_gems() -> void:
	gem_value.text = str(EconomyManager.get_gem_balance())
