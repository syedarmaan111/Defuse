extends Node

## NetworkManager owns the internet-reachability gate.
## A small HTTPS request is authoritative because Android's VALIDATED capability
## can be stale or unavailable even when mobile data can reach the internet.

signal wifi_connection_changed(is_connected: bool)
signal internet_availability_changed(is_available: bool)
signal connection_check_finished(is_available: bool)
signal gameplay_connection_lost()
signal gameplay_connection_restored()

const ONLINE_REFRESH_INTERVAL_SECONDS := 20.0
const OFFLINE_REFRESH_INTERVAL_SECONDS := 5.0
const PROBE_TIMEOUT_SECONDS := 5.0
const PRIMARY_PROBE_URL := "https://connectivitycheck.gstatic.com/generate_204"
const FALLBACK_PROBE_URL := "https://cp.cloudflare.com/generate_204"

var _wifi_connected := false
var _internet_available := false
var _last_connection_status := "not_checked"
var _gameplay_active := false
var _gameplay_connection_was_lost := false
var _refresh_elapsed := 0.0
var _online_gate_enabled := true
var _development_bypass := false
var _probe_request: HTTPRequest
var _probe_in_flight := false
var _probe_url_index := -1
var _last_probe_failure := "not_checked"
var _probe_urls := PackedStringArray([PRIMARY_PROBE_URL, FALLBACK_PROBE_URL])


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
	_probe_request = HTTPRequest.new()
	_probe_request.timeout = PROBE_TIMEOUT_SECONDS
	_probe_request.request_completed.connect(_on_probe_request_completed)
	add_child(_probe_request)
	set_process(_online_gate_enabled and not _development_bypass)
	if _online_gate_enabled:
		call_deferred("refresh_connection_state")
	else:
		_last_connection_status = "online_gate_disabled"


func _process(delta: float) -> void:
	## Check more frequently while offline so reconnecting does not require a restart.
	_refresh_elapsed += delta
	var refresh_interval := (
		ONLINE_REFRESH_INTERVAL_SECONDS
		if _internet_available
		else OFFLINE_REFRESH_INTERVAL_SECONDS
	)
	if _refresh_elapsed < refresh_interval:
		return
	_refresh_elapsed = 0.0
	refresh_connection_state()


func is_wifi_connected() -> bool:
	return _wifi_connected


func has_internet_access() -> bool:
	return _internet_available


func get_last_connection_status() -> String:
	return _last_connection_status


func is_connection_check_in_progress() -> bool:
	return _probe_in_flight


func can_start_game() -> bool:
	return not _online_gate_enabled or _development_bypass or _internet_available


func is_online_gate_enabled() -> bool:
	return _online_gate_enabled


func is_development_bypass_active() -> bool:
	return _development_bypass


func set_gameplay_active(is_active: bool) -> void:
	## Lets the manager distinguish a live run from menus when connectivity changes.
	var activity_changed := _gameplay_active != is_active
	_gameplay_active = is_active
	if not is_active:
		_gameplay_connection_was_lost = false
	elif not can_start_game():
		_emit_gameplay_connection_lost_once()
	if activity_changed:
		# Recheck when a run starts and when it ends. The current cached result
		# remains usable while the non-blocking request is in flight.
		call_deferred("refresh_connection_state")


func refresh_connection_state() -> void:
	## Starts a non-blocking, zero-body HTTPS reachability probe.
	if not _online_gate_enabled or _development_bypass:
		return
	if _probe_in_flight:
		return
	_probe_in_flight = true
	_probe_url_index = -1
	_last_probe_failure = "probe_not_started"
	_start_next_probe()


func _start_next_probe() -> void:
	_probe_url_index += 1
	if _probe_url_index >= _probe_urls.size():
		_finish_connection_check(false, _last_probe_failure)
		return

	var request_error := _probe_request.request(
		_probe_urls[_probe_url_index],
		PackedStringArray(["Cache-Control: no-cache"]),
		HTTPClient.METHOD_GET
	)
	if request_error != OK:
		_last_probe_failure = "probe_start_error_%d" % request_error
		call_deferred("_start_next_probe")


func _on_probe_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	var request_succeeded := (
		result == HTTPRequest.RESULT_SUCCESS
		and response_code >= 200
		and response_code < 300
	)
	if request_succeeded:
		_finish_connection_check(true, "reachability_probe_succeeded_%d" % response_code)
		return

	_last_probe_failure = "probe_failed_result_%d_http_%d" % [result, response_code]
	call_deferred("_start_next_probe")


func _finish_connection_check(is_available: bool, status: String) -> void:
	_probe_in_flight = false
	_refresh_elapsed = 0.0
	_set_connection_state(_wifi_connected, is_available, status)
	# Emitted after every completed check, even when state did not change, so
	# Retry UI can always leave its checking state.
	connection_check_finished.emit(is_available)


func _allow_when_check_unavailable(reason: String) -> void:
	## Retained for deterministic tests and fail-closed error handling.
	if _last_connection_status != reason:
		push_warning("Connection check unavailable: %s" % reason)
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
