extends Control

## Welcome-back modal showing offline earnings.
## Usage from game.gd:
##   var dlg := preload("res://scenes/common/offline_summary_dialog.tscn").instantiate()
##   modal_layer.add_child(dlg)
##   dlg.setup(SaveSystem.last_offline_summary)
##   await dlg.closed
##   dlg.queue_free()

signal closed

@onready var _title: Label = %Title
@onready var _elapsed: Label = %Elapsed
@onready var _breakdown: Label = %Breakdown
@onready var _close_btn: Button = %CloseBtn

func _ready() -> void:
	_close_btn.pressed.connect(_on_close)

func setup(summary: Dictionary) -> void:
	var elapsed: float = float(summary.get("elapsed_seconds", 0.0))
	var capped: float = float(summary.get("capped_seconds", 0.0))
	var produced: Dictionary = summary.get("produced", {})
	_title.text = "Welcome back!"
	_elapsed.text = _format_duration(elapsed)
	if capped < elapsed:
		_elapsed.text += "  (capped at %s)" % _format_duration(capped)
	_breakdown.text = _format_produced(produced)

func _format_duration(seconds: float) -> String:
	var total: int = int(seconds)
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	if h > 0:
		return "Away for %dh %dm" % [h, m]
	if m > 0:
		return "Away for %dm %ds" % [m, s]
	return "Away for %ds" % s

func _format_produced(produced: Dictionary) -> String:
	if produced.is_empty():
		return "No production while away."
	var lines: PackedStringArray = []
	# Aggregate by currency (sum across generators of the same output currency).
	var by_currency: Dictionary[StringName, float] = {}
	for gen_id in produced:
		var def: GeneratorDef = _find_generator(StringName(gen_id))
		if def == null:
			continue
		var amt: float = float(produced[gen_id])
		var c_id: StringName = def.currency_id
		by_currency[c_id] = by_currency.get(c_id, 0.0) + amt
	for c_id in by_currency:
		lines.append("+%d %s" % [int(by_currency[c_id]), c_id])
	return "\n".join(lines)

func _find_generator(gen_id: StringName) -> GeneratorDef:
	for def in GameState.generator_defs:
		if def.id == gen_id:
			return def
	return null

func _on_close() -> void:
	closed.emit()
