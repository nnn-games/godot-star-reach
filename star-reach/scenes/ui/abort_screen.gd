class_name AbortScreen
extends PopupPanel

## Shown when StressService aborts a launch attempt. Phase 2 shipped with
## Shield / Watch Ad stubs; Phase 6d activates them.
##   - Shield: consume one T3 shield from GameState.shield_inventory, reset
##     stress, close. Player retries Launch with a clean stress bar.
##   - Watch Ad: play a rewarded ad via AdService. On completion, reset stress
##     and close (no shield inventory touched — ad is a free bypass).
##   - Try Again: just close. The next Launch re-rolls the abort chance.

signal closed

@onready var _cost_label: Label = %CostLabel
@onready var _retry_button: Button = %RetryButton
@onready var _shield_button: Button = %ShieldButton
@onready var _ad_button: Button = %AdButton

func _ready() -> void:
	_retry_button.pressed.connect(_on_retry)
	_shield_button.pressed.connect(_on_shield)
	_ad_button.pressed.connect(_on_ad)
	_refresh_shield_button()
	_refresh_ad_button()
	AdService.rewarded_ad_completed.connect(_on_ad_completed)
	AdService.rewarded_ad_failed.connect(_on_ad_failed)

func setup(repair_cost: int) -> void:
	if repair_cost > 0:
		_cost_label.text = tr("ABORT_COST_FMT") % repair_cost
	else:
		_cost_label.text = tr("ABORT_NO_COST")

# --- Shield ---

func _refresh_shield_button() -> void:
	var count: int = int(GameState.shield_inventory.get(&"T3", 0))
	if count > 0:
		_shield_button.text = tr("ABORT_SHIELD_FMT") % count
		_shield_button.disabled = false
	else:
		_shield_button.text = tr("ABORT_SHIELD_EMPTY")
		_shield_button.disabled = true

func _on_shield() -> void:
	var count: int = int(GameState.shield_inventory.get(&"T3", 0))
	if count < 1:
		return
	GameState.shield_inventory[&"T3"] = count - 1
	_clear_stress()
	closed.emit()
	queue_free()

# --- Ad ---

func _refresh_ad_button() -> void:
	if AdService.is_ready():
		_ad_button.text = tr("ABORT_WATCH_AD")
		_ad_button.disabled = false
	else:
		_ad_button.text = tr("ABORT_AD_NOT_READY")
		_ad_button.disabled = true

func _on_ad() -> void:
	if not AdService.is_ready():
		return
	_ad_button.text = tr("ABORT_AD_PLAYING")
	_ad_button.disabled = true
	_shield_button.disabled = true
	_retry_button.disabled = true
	AdService.show_rewarded_ad()

func _on_ad_completed(granted: bool) -> void:
	if not is_inside_tree():
		return
	if granted:
		_clear_stress()
		closed.emit()
		queue_free()
	else:
		_refresh_ad_button()
		_shield_button.disabled = false
		_retry_button.disabled = false

func _on_ad_failed(_reason: String) -> void:
	if not is_inside_tree():
		return
	_refresh_ad_button()
	_shield_button.disabled = false
	_retry_button.disabled = false

# --- Plain retry ---

func _on_retry() -> void:
	closed.emit()
	queue_free()

# --- Helpers ---

func _clear_stress() -> void:
	GameState.stress_value = 0.0
	EventBus.stress_changed.emit(0.0)
