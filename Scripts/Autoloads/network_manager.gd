extends Node

## NetworkManager owns the validated-internet online gate.
## Android builds query ConnectivityManager through Godot's AndroidRuntime bridge.
## A development bypass exists for deliberate local testing, but defaults off.

signal wifi_connection_changed(is_connected: bool)
signal internet_availability_changed(is_available: bool)
signal gameplay_connection_lost()
signal gameplay_connection_restored()

const REFRESH_INTERVAL_SECONDS := 1.0

var _wifi_connected := false
var _internet_available := false
var _last_connection_status := "not_checked"
var _gameplay_active := false
var _gameplay_connection_was_lost := false
var _refresh_elapsed := 0.0
var _online_gate_enabled := true
var _development_bypass := false


func _ready() -> void:
	_online_gate_enabled = bool(
		ProjectSettings.get_setting("defuse/online_gate/enabled", true)
	)
	_development_bypass = (
		_online_gate_enabled
		and
		OS.get_name() != "Android"
		and bool(ProjectSettings.get_setting("defuse/development/bypass_online_gate", false))
	)
	set_process(_online_gate_enabled and OS.get_name() == "Android")
	if _online_gate_enabled:
		call_deferred("refresh_connection_state")
	else:
		_last_connection_status = "online_gate_disabled"


func _process(delta: float) -> void:
	## Refreshes current Android network capabilities often enough for UI gating.
	_refresh_elapsed += delta
	if _refresh_elapsed < REFRESH_INTERVAL_SECONDS:
		return
	_refresh_elapsed = 0.0
	refresh_connection_state()


func is_wifi_connected() -> bool:
	return _wifi_connected


func has_internet_access() -> bool:
	return _internet_available


func get_last_connection_status() -> String:
	return _last_connection_status


func can_start_game() -> bool:
	## Android's internet capability works for both Wi-Fi and cellular data.
	return not _online_gate_enabled or _development_bypass or _internet_available


func is_online_gate_enabled() -> bool:
	return _online_gate_enabled


func is_development_bypass_active() -> bool:
	return _development_bypass


func set_gameplay_active(is_active: bool) -> void:
	## Lets the manager distinguish a live run from menus when connectivity changes.
	_gameplay_active = is_active
	if not is_active:
		_gameplay_connection_was_lost = false
	elif not can_start_game():
		_emit_gameplay_connection_lost_once()


func refresh_connection_state() -> void:
	## Reads fresh Android capabilities instead of trusting transport presence alone.
	if not _online_gate_enabled or _development_bypass:
		return
	if OS.get_name() != "Android":
		_set_connection_state(false, false)
		return

	var android_runtime := Engine.get_singleton("AndroidRuntime")
	var java_wrapper := Engine.get_singleton("JavaClassWrapper")
	if android_runtime == null or java_wrapper == null:
		_allow_when_check_unavailable("android_bridge_unavailable")
		return

	var application_context: Object = android_runtime.getApplicationContext()
	if java_wrapper.get_exception() != null:
		_allow_when_check_unavailable("application_context_error")
		return

	if application_context == null:
		_allow_when_check_unavailable("application_context_unavailable")
		return

	var connectivity_manager: Object = application_context.getSystemService("connectivity")
	if java_wrapper.get_exception() != null:
		_allow_when_check_unavailable("connectivity_service_error")
		return

	if connectivity_manager == null:
		_allow_when_check_unavailable("connectivity_service_unavailable")
		return

	var active_network: Object = connectivity_manager.getActiveNetwork()
	if java_wrapper.get_exception() != null:
		_allow_when_check_unavailable("active_network_error")
		return

	if active_network == null:
		_set_connection_state(false, false, "no_active_network")
		return

	var capabilities: Object = connectivity_manager.getNetworkCapabilities(active_network)
	if java_wrapper.get_exception() != null:
		_allow_when_check_unavailable("network_capabilities_error")
		return

	if capabilities == null:
		_allow_when_check_unavailable("network_capabilities_unavailable")
		return

	var network_capabilities: Object = java_wrapper.wrap("android.net.NetworkCapabilities")
	if network_capabilities == null or java_wrapper.get_exception() != null:
		_allow_when_check_unavailable("network_capabilities_class_unavailable")
		return

	var has_internet := bool(capabilities.hasCapability(network_capabilities.NET_CAPABILITY_INTERNET))
	if java_wrapper.get_exception() != null:
		_allow_when_check_unavailable("internet_capability_error")
		return

	var uses_wifi := bool(capabilities.hasTransport(network_capabilities.TRANSPORT_WIFI))
	if java_wrapper.get_exception() != null:
		uses_wifi = false

	var is_validated := bool(capabilities.hasCapability(network_capabilities.NET_CAPABILITY_VALIDATED))
	if java_wrapper.get_exception() != null:
		is_validated = false

	var internet_available := has_internet and is_validated
	var status := "validated_internet" if internet_available else "internet_not_validated"
	if not has_internet:
		status = "no_internet_capability"
	_set_connection_state(uses_wifi, internet_available, status)


func _allow_when_check_unavailable(reason: String) -> void:
	## The online-only launch contract must remain enforced if the platform check fails.
	if _last_connection_status != reason:
		push_warning("Android connection check unavailable: %s" % reason)
	_set_connection_state(false, false, reason)


func _set_connection_state(
	wifi_connected: bool,
	internet_available: bool,
	status: String = "test_override"
) -> void:
	var wifi_changed := _wifi_connected != wifi_connected
	var availability_changed := _internet_available != internet_available
	_wifi_connected = wifi_connected
	_internet_available = internet_available
	_last_connection_status = status

	if wifi_changed:
		wifi_connection_changed.emit(_wifi_connected)
	if availability_changed:
		internet_availability_changed.emit(_internet_available)

	if not _gameplay_active:
		return
	if can_start_game():
		if _gameplay_connection_was_lost:
			_gameplay_connection_was_lost = false
			gameplay_connection_restored.emit()
	else:
		_emit_gameplay_connection_lost_once()


func _emit_gameplay_connection_lost_once() -> void:
	if _gameplay_connection_was_lost:
		return
	_gameplay_connection_was_lost = true
	gameplay_connection_lost.emit()
