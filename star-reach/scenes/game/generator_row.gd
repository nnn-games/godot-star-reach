extends PanelContainer

## Reusable row for one generator. One instance per GeneratorDef.
## Subscribes to EventBus for its own generator + currency updates.

@onready var _icon: ColorRect = %Icon
@onready var _name: Label = %Name
@onready var _stats: Label = %Stats
@onready var _buy_btn: Button = %BuyBtn

var _def: GeneratorDef

func bind(def: GeneratorDef) -> void:
	_def = def
	_name.text = def.display_name
	_buy_btn.pressed.connect(_on_buy_pressed)
	EventBus.generator_purchased.connect(_on_generator_purchased)
	EventBus.currency_changed.connect(_on_currency_changed)
	_refresh()

func _refresh() -> void:
	var level: int = GameState.get_level(_def.id)
	var rate: float = _def.base_rate * float(level)
	_stats.text = "Lv %d  •  %.1f/s" % [level, rate]
	var cost: float = GameState.cost_of(_def)
	_buy_btn.text = "Buy  %d" % int(ceil(cost))
	_buy_btn.disabled = not GameState.can_buy(_def)

func _on_buy_pressed() -> void:
	GameState.try_buy(_def)

func _on_generator_purchased(gen_id: StringName, _new_level: int) -> void:
	if gen_id == _def.id:
		_refresh()

func _on_currency_changed(id: StringName, _amount: float) -> void:
	if id == _def.cost_currency_id:
		_refresh_button_only()

## Lighter refresh: currency changes happen every tick, but only the buy button's
## disabled/label need update — leveling and rate labels stay put.
func _refresh_button_only() -> void:
	var cost: float = GameState.cost_of(_def)
	_buy_btn.text = "Buy  %d" % int(ceil(cost))
	_buy_btn.disabled = not GameState.can_buy(_def)
