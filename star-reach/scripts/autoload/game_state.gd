extends Node

## Central mutable game state: currency balances, generator levels, tick economy.
## All mutations emit through EventBus so UI stays purely reactive.
## Phase 1 holds state in-memory only. Phase 1.5 adds SaveSystem persistence.

const CURRENCY_PATHS: PackedStringArray = [
	"res://data/currencies/coin.tres",
]

const GENERATOR_PATHS: PackedStringArray = [
	"res://data/generators/miner.tres",
	"res://data/generators/refinery.tres",
]

var currency_defs: Array[CurrencyDef] = []
var generator_defs: Array[GeneratorDef] = []

var _balances: Dictionary[StringName, float] = {}
var _generator_levels: Dictionary[StringName, int] = {}
var _flags: Dictionary[StringName, bool] = {}

func _ready() -> void:
	_load_defs()
	_seed_initial_state()
	IAPService.purchase_completed.connect(_on_iap_purchase_completed)
	IAPService.restore_completed.connect(_on_iap_restore_completed)

## Called by TimeManager each frame (delta already scaled by speed_multiplier).
func tick(delta: float) -> void:
	for def in generator_defs:
		var level: int = _generator_levels.get(def.id, 0)
		if level <= 0:
			continue
		var produced: float = def.base_rate * float(level) * delta
		_add_currency(def.currency_id, produced)
		EventBus.generator_ticked.emit(def.id, produced)

## Bulk time advance for offline progress. Same math as tick() but does not
## emit per-generator tick signals (would flood observers for 8h of deltas).
## Currency changes still emit once-per-currency via _add_currency.
## Returns totals by generator id for summary UI.
func advance_simulation(dt: float) -> Dictionary:
	var totals: Dictionary[StringName, float] = {}
	if dt <= 0.0:
		return totals
	for def in generator_defs:
		var level: int = _generator_levels.get(def.id, 0)
		if level <= 0:
			continue
		var produced: float = def.base_rate * float(level) * dt
		_add_currency(def.currency_id, produced)
		totals[def.id] = produced
	return totals

## Serialize full mutable state for SaveSystem. Keep keys stable across versions.
func to_dict() -> Dictionary:
	return {
		"balances": _dict_stringname_to_string(_balances),
		"generator_levels": _dict_stringname_to_string(_generator_levels),
		"flags": _dict_stringname_to_string(_flags),
	}

## Restore from a Dictionary produced by to_dict (or an older migrated version).
## Defaults to seeded state for any missing key, then overlays saved values.
## Emits currency_changed / generator_purchased so UI rebinds automatically.
func from_dict(d: Dictionary) -> void:
	_balances.clear()
	_generator_levels.clear()
	_flags.clear()
	for c in currency_defs:
		_balances[c.id] = c.initial_amount
	for g in generator_defs:
		_generator_levels[g.id] = 0
	var saved_balances: Dictionary = d.get("balances", {})
	for k in saved_balances:
		_balances[StringName(k)] = float(saved_balances[k])
	var saved_levels: Dictionary = d.get("generator_levels", {})
	for k in saved_levels:
		_generator_levels[StringName(k)] = int(saved_levels[k])
	var saved_flags: Dictionary = d.get("flags", {})
	for k in saved_flags:
		_flags[StringName(k)] = bool(saved_flags[k])
	for c_id in _balances:
		EventBus.currency_changed.emit(c_id, _balances[c_id])
	for g_id in _generator_levels:
		EventBus.generator_purchased.emit(g_id, _generator_levels[g_id])

## StringName keys don't survive JSON round-trip (JSON only has string keys).
## Normalize to plain String on save; StringName on load.
static func _dict_stringname_to_string(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in src:
		out[String(k)] = src[k]
	return out

func get_currency(id: StringName) -> float:
	return _balances.get(id, 0.0)

func get_level(gen_id: StringName) -> int:
	return _generator_levels.get(gen_id, 0)

func cost_of(def: GeneratorDef) -> float:
	var level: int = _generator_levels.get(def.id, 0)
	return def.cost_curve.cost_at(level)

func can_buy(def: GeneratorDef) -> bool:
	return get_currency(def.cost_currency_id) >= cost_of(def)

func try_buy(def: GeneratorDef) -> bool:
	if not can_buy(def):
		return false
	var price: float = cost_of(def)
	_add_currency(def.cost_currency_id, -price)
	var new_level: int = _generator_levels.get(def.id, 0) + 1
	_generator_levels[def.id] = new_level
	EventBus.generator_purchased.emit(def.id, new_level)
	return true

func _load_defs() -> void:
	for path in CURRENCY_PATHS:
		var c: CurrencyDef = load(path) as CurrencyDef
		assert(c != null, "CurrencyDef load failed: %s" % path)
		currency_defs.append(c)
	for path in GENERATOR_PATHS:
		var g: GeneratorDef = load(path) as GeneratorDef
		assert(g != null, "GeneratorDef load failed: %s" % path)
		generator_defs.append(g)

func _seed_initial_state() -> void:
	for c in currency_defs:
		_balances[c.id] = c.initial_amount
		EventBus.currency_changed.emit(c.id, _balances[c.id])
	for g in generator_defs:
		_generator_levels[g.id] = 0

func add_currency(id: StringName, amount: float) -> void:
	_add_currency(id, amount)

func set_flag(key: StringName, value: bool) -> void:
	_flags[key] = value

func get_flag(key: StringName) -> bool:
	return _flags.get(key, false)

## IAPService contract: product.grants is a game-defined Dictionary.
## StarReach convention: { "currency": { "<id>": <amount> }, "flags": [<key>, ...] }
func _on_iap_purchase_completed(product: IAPProduct, _receipt: Dictionary) -> void:
	var grants: Dictionary = product.grants
	if grants.has("currency"):
		var c_dict: Dictionary = grants["currency"]
		for c_id in c_dict:
			_add_currency(StringName(c_id), float(c_dict[c_id]))
	if grants.has("flags"):
		for key in grants["flags"]:
			set_flag(StringName(key), true)

func _on_iap_restore_completed(owned_products: Array) -> void:
	for p in owned_products:
		if p is IAPProduct and p.grants.has("flags"):
			for key in p.grants["flags"]:
				set_flag(StringName(key), true)

func _add_currency(id: StringName, amount: float) -> void:
	_balances[id] = _balances.get(id, 0.0) + amount
	EventBus.currency_changed.emit(id, _balances[id])
