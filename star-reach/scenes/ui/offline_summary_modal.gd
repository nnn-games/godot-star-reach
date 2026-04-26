class_name OfflineSummaryModal
extends PopupPanel

## "Welcome back" modal shown on boot when OfflineProgressService produced
## a non-trivial summary. Auto-dismissable; player taps Continue to proceed.

signal closed

@onready var _title: Label = %TitleLabel
@onready var _detail: Label = %DetailLabel
@onready var _continue_button: Button = %ContinueButton

func _ready() -> void:
	_continue_button.pressed.connect(_on_continue)

func setup(summary: Dictionary) -> void:
	var elapsed: float = float(summary.get("elapsed_seconds", 0.0))
	var was_capped: bool = bool(summary.get("was_capped", false))
	var hours: int = int(elapsed / 3600.0)
	var minutes: int = int(fmod(elapsed, 3600.0) / 60.0)
	_title.text = tr("OFFLINE_TITLE")
	var lines: Array[String] = []
	var time_str: String = tr("OFFLINE_TIME_FMT") % [hours, minutes]
	if was_capped:
		time_str += tr("OFFLINE_CAPPED_SUFFIX")
	lines.append(time_str)
	lines.append(tr("OFFLINE_DEST_FMT") % String(summary.get("destination_name", "—")))
	lines.append(tr("OFFLINE_LAUNCHES_FMT") % [
		int(summary.get("simulated_launches", 0)),
		int(summary.get("wins", 0)),
	])
	lines.append(tr("OFFLINE_REWARD_FMT") % [
		int(summary.get("xp_earned", 0)),
		int(summary.get("credit_earned", 0)),
		int(summary.get("tech_level_earned", 0)),
	])
	_detail.text = "\n".join(lines)

func _on_continue() -> void:
	closed.emit()
	queue_free()
