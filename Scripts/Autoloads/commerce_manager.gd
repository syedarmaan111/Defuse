extends Node

## Provider-neutral purchase boundary. Milestone 13 will attach Google Play
## Billing; until then requests fail safely without charging or granting items.

signal purchase_succeeded(product_id: String)
signal purchase_cancelled(product_id: String)
signal purchase_failed(product_id: String, error_code: String)
signal purchases_restored(product_ids: Array[String])

var _provider: Object


func set_provider(provider: Object) -> void:
	_provider = provider


func is_available() -> bool:
	return _provider != null and _provider.has_method("purchase")


func purchase(product_id: String) -> bool:
	var safe_id := product_id.strip_edges()
	if safe_id.is_empty():
		purchase_failed.emit(safe_id, "invalid_product_id")
		return false
	if not is_available():
		call_deferred("_emit_provider_unavailable", safe_id)
		return false
	_provider.call("purchase", safe_id)
	return true


func restore_purchases() -> bool:
	if _provider == null or not _provider.has_method("restore_purchases"):
		call_deferred("_emit_restore_unavailable")
		return false
	_provider.call("restore_purchases")
	return true


func report_purchase_succeeded(product_id: String) -> void:
	## Android billing adapters report provider callbacks through these methods.
	purchase_succeeded.emit(product_id)


func report_purchase_cancelled(product_id: String) -> void:
	purchase_cancelled.emit(product_id)


func report_purchase_failed(product_id: String, error_code: String) -> void:
	purchase_failed.emit(product_id, error_code)


func report_purchases_restored(product_ids: Array[String]) -> void:
	purchases_restored.emit(product_ids)


func _emit_provider_unavailable(product_id: String) -> void:
	purchase_failed.emit(product_id, "provider_unavailable")


func _emit_restore_unavailable() -> void:
	purchases_restored.emit([])
