extends Node

## Rewarded-ad façade. Phase 6d ships a Mock backend (always succeeds after a
## short delay) so the AbortScreen path exercises the full "watch ad → reward"
## flow in development. Android / iOS plugin backends drop in later alongside
## the real app store submission; the API shape is the same.

signal ready_state_changed(is_ready: bool)
## `granted = true` means the user watched the ad to completion. `false` is
## reserved for future cases where the user closed early (Mock only emits true).
signal rewarded_ad_completed(granted: bool)
signal rewarded_ad_failed(reason: String)

const MOCK_LATENCY_SEC: float = 1.5

var _is_ready: bool = false
var _in_flight: bool = false

func _ready() -> void:
	# Mock backend is always ready immediately. Real backends emit this async
	# once the SDK finishes loading its initial ad inventory.
	_is_ready = true
	print("[Ad] Mock backend active (rewarded ad simulates %.1fs wait)" % MOCK_LATENCY_SEC)
	ready_state_changed.emit(true)

# --- Public API ---

func is_ready() -> bool:
	return _is_ready and not _in_flight

func is_playing() -> bool:
	return _in_flight

func show_rewarded_ad() -> void:
	if _in_flight:
		rewarded_ad_failed.emit("ad already in flight")
		return
	if not _is_ready:
		rewarded_ad_failed.emit("ad not ready")
		return
	_in_flight = true
	await get_tree().create_timer(MOCK_LATENCY_SEC).timeout
	_in_flight = false
	rewarded_ad_completed.emit(true)
