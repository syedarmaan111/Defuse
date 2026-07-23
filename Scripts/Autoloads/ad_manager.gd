extends Node

## Provider-neutral ad coordinator. Development builds can simulate callbacks;
## Android release builds require a native DefuseAds singleton and never grant
## a reward or impression merely because a request was made.

signal banner_visibility_changed(is_visible: bool)
signal interstitial_requested()
signal interstitial_presented()
signal interstitial_finished()
signal interstitial_failed(error_code: String)
signal rewarded_presented(placement_id: String)
signal rewarded_completed(placement_id: String)
signal rewarded_failed(placement_id: String, error_code: String)
signal ad_impression_recorded(format_name: String)
signal new_run_ready()

const INTERSTITIAL_INTERVAL := 4
const PROVIDER_SINGLETON_NAME := "DefuseAds"

var _provider: Object
var _simulation_enabled := false
var _banner_requesters: Dictionary = {}
var _banner_is_visible := false
var _interstitial_in_flight := false
var _new_run_waiting := false
var _rewarded_in_flight := false
var _rewarded_placement_id := ""
var _reward_was_earned := false


func _ready() -> void:
	_simulation_enabled = (
		bool(ProjectSettings.get_setting("defuse/development/simulate_ads", false))
		or bool(
			ProjectSettings.get_setting(
				"defuse/development/simulate_rewarded_ads", false
			)
		)
	) and (OS.get_name() != "Android" or OS.is_debug_build())
	if Engine.has_singleton(PROVIDER_SINGLETON_NAME):
		_provider = Engine.get_singleton(PROVIDER_SINGLETON_NAME)
	_connect_provider_callbacks()
	NetworkManager.internet_availability_changed.connect(
		_on_internet_availability_changed
	)
	call_deferred("_attempt_restored_interstitial")


func is_simulation_enabled() -> bool:
	return _simulation_enabled


func is_provider_available() -> bool:
	return _provider != null


func can_show_rewarded() -> bool:
	if not NetworkManager.can_start_game() or _rewarded_in_flight:
		return false
	if _simulation_enabled:
		return true
	return (
		_provider != null
		and _provider.has_method("is_rewarded_ready")
		and _provider.has_method("show_rewarded")
		and bool(_provider.call("is_rewarded_ready"))
	)


func request_rewarded(placement_id: String) -> bool:
	var safe_placement := placement_id.strip_edges()
	if safe_placement.is_empty() or not can_show_rewarded():
		return false
	_rewarded_in_flight = true
	_rewarded_placement_id = safe_placement
	_reward_was_earned = false
	if _simulation_enabled:
		call_deferred("_complete_simulated_rewarded")
		return true
	if not bool(_provider.call("show_rewarded", safe_placement)):
		_fail_rewarded("request_failed")
		return false
	return true


func set_banner_requested(requester_id: String, is_requested: bool) -> void:
	var safe_id := requester_id.strip_edges()
	if safe_id.is_empty():
		return
	if is_requested:
		_banner_requesters[safe_id] = true
	else:
		_banner_requesters.erase(safe_id)
	_refresh_banner()


func release_banner_request(requester_id: String) -> void:
	set_banner_requested(requester_id, false)


func register_completed_run() -> Dictionary:
	## SaveManager performs the counter/pending mutation atomically before Game
	## Over controls become visible. Showing is deferred until the tree is safe.
	var result := SaveManager.record_completed_run(INTERSTITIAL_INTERVAL)
	if bool(result["pending_interstitial"]):
		call_deferred("_try_show_pending_interstitial")
	return result


func intercept_new_run_request() -> bool:
	## Returns true only when startup must wait for one pending ad resolution.
	if not SaveManager.has_pending_interstitial():
		return false
	_new_run_waiting = true
	if not NetworkManager.can_start_game():
		return true
	_try_show_pending_interstitial()
	return true


func is_interstitial_in_flight() -> bool:
	return _interstitial_in_flight


func is_banner_visible() -> bool:
	return _banner_is_visible


func _try_show_pending_interstitial() -> void:
	if (
		not SaveManager.has_pending_interstitial()
		or _interstitial_in_flight
		or not NetworkManager.can_start_game()
	):
		return
	_interstitial_in_flight = true
	interstitial_requested.emit()
	if _simulation_enabled:
		call_deferred("_complete_simulated_interstitial")
		return
	if (
		_provider == null
		or not _provider.has_method("is_interstitial_ready")
		or not _provider.has_method("show_interstitial")
		or not bool(_provider.call("is_interstitial_ready"))
	):
		_fail_interstitial("no_fill")
		return
	if not bool(_provider.call("show_interstitial")):
		_fail_interstitial("request_failed")


func _complete_simulated_interstitial() -> void:
	if not _interstitial_in_flight:
		return
	interstitial_presented.emit()
	ad_impression_recorded.emit("interstitial")
	_finish_interstitial()


func _complete_simulated_rewarded() -> void:
	if not _rewarded_in_flight:
		return
	rewarded_presented.emit(_rewarded_placement_id)
	ad_impression_recorded.emit("rewarded")
	_complete_rewarded()


func _finish_interstitial() -> void:
	if not _interstitial_in_flight:
		return
	_interstitial_in_flight = false
	SaveManager.clear_pending_interstitial()
	interstitial_finished.emit()
	_release_waiting_new_run()


func _fail_interstitial(error_code: String) -> void:
	if not _interstitial_in_flight:
		return
	_interstitial_in_flight = false
	# A normal no-fill/failure consumes the single saved opportunity.
	SaveManager.clear_pending_interstitial()
	interstitial_failed.emit(error_code)
	_release_waiting_new_run()


func _complete_rewarded() -> void:
	if not _rewarded_in_flight:
		return
	var placement := _rewarded_placement_id
	_rewarded_in_flight = false
	_rewarded_placement_id = ""
	_reward_was_earned = true
	rewarded_completed.emit(placement)


func _fail_rewarded(error_code: String) -> void:
	if not _rewarded_in_flight:
		return
	var placement := _rewarded_placement_id
	_rewarded_in_flight = false
	_rewarded_placement_id = ""
	_reward_was_earned = false
	rewarded_failed.emit(placement, error_code)


func _release_waiting_new_run() -> void:
	if not _new_run_waiting:
		return
	_new_run_waiting = false
	new_run_ready.emit()


func _attempt_restored_interstitial() -> void:
	if SaveManager.has_pending_interstitial() and NetworkManager.can_start_game():
		_try_show_pending_interstitial()


func _on_internet_availability_changed(_is_available: bool) -> void:
	_refresh_banner()
	if NetworkManager.can_start_game() and SaveManager.has_pending_interstitial():
		call_deferred("_try_show_pending_interstitial")


func _refresh_banner() -> void:
	var should_show := (
		not _banner_requesters.is_empty()
		and NetworkManager.can_start_game()
		and (
			_simulation_enabled
			or (
				_provider != null
				and _provider.has_method("show_banner")
			)
		)
	)
	if should_show == _banner_is_visible:
		return
	_banner_is_visible = should_show
	if _provider != null and not _simulation_enabled:
		if should_show:
			_provider.call("show_banner")
		elif _provider.has_method("hide_banner"):
			_provider.call("hide_banner")
	if should_show and _simulation_enabled:
		ad_impression_recorded.emit("banner")
	banner_visibility_changed.emit(_banner_is_visible)


func _connect_provider_callbacks() -> void:
	if _provider == null:
		return
	_connect_provider_signal("interstitial_shown", _on_provider_interstitial_shown)
	_connect_provider_signal("interstitial_closed", _on_provider_interstitial_closed)
	_connect_provider_signal("interstitial_failed", _on_provider_interstitial_failed)
	_connect_provider_signal("rewarded_shown", _on_provider_rewarded_shown)
	_connect_provider_signal("rewarded_earned", _on_provider_rewarded_earned)
	_connect_provider_signal("rewarded_closed", _on_provider_rewarded_closed)
	_connect_provider_signal("rewarded_failed", _on_provider_rewarded_failed)


func _connect_provider_signal(signal_name: StringName, callback: Callable) -> void:
	if _provider.has_signal(signal_name) and not _provider.is_connected(signal_name, callback):
		_provider.connect(signal_name, callback)


func _on_provider_interstitial_shown() -> void:
	if not _interstitial_in_flight:
		return
	interstitial_presented.emit()
	ad_impression_recorded.emit("interstitial")


func _on_provider_interstitial_closed() -> void:
	_finish_interstitial()


func _on_provider_interstitial_failed(error_code: String = "provider_failed") -> void:
	_fail_interstitial(error_code)


func _on_provider_rewarded_shown() -> void:
	if not _rewarded_in_flight:
		return
	rewarded_presented.emit(_rewarded_placement_id)
	ad_impression_recorded.emit("rewarded")


func _on_provider_rewarded_earned() -> void:
	_complete_rewarded()


func _on_provider_rewarded_closed() -> void:
	if _rewarded_in_flight and not _reward_was_earned:
		_fail_rewarded("reward_not_earned")


func _on_provider_rewarded_failed(error_code: String = "provider_failed") -> void:
	_fail_rewarded(error_code)
