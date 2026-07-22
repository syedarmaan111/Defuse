extends Node

## EconomyManager is the only gameplay-facing API for earned Gems and debits.

signal currency_changed(currency_id: String, new_balance: int)

const GEM_CURRENCY_ID := "gems"

var _last_gem_balance := 0


func _ready() -> void:
	_last_gem_balance = SaveManager.get_currency_balance(GEM_CURRENCY_ID)
	SaveManager.save_loaded.connect(_on_save_snapshot)
	SaveManager.save_changed.connect(_on_save_snapshot)


func get_gem_balance() -> int:
	return SaveManager.get_currency_balance(GEM_CURRENCY_ID)


func can_afford_gems(amount: int) -> bool:
	return amount >= 0 and get_gem_balance() >= amount


func earn_gems(amount: int) -> bool:
	## Gems are earn-only; there is intentionally no paid top-up or exchange API.
	if amount <= 0:
		return false
	return SaveManager.set_currency_balance(GEM_CURRENCY_ID, get_gem_balance() + amount)


func spend_gems(amount: int) -> bool:
	if amount <= 0 or not can_afford_gems(amount):
		return false
	return SaveManager.set_currency_balance(GEM_CURRENCY_ID, get_gem_balance() - amount)


func _on_save_snapshot(snapshot: Dictionary) -> void:
	var currencies = snapshot.get("currencies", {})
	var balance := 0
	if typeof(currencies) == TYPE_DICTIONARY:
		balance = int(currencies.get(GEM_CURRENCY_ID, 0))
	if balance == _last_gem_balance:
		return
	_last_gem_balance = balance
	currency_changed.emit(GEM_CURRENCY_ID, balance)
