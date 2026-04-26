class_name BattlePassPanel
extends PopupPanel

## Phase 6c Battle Pass viewer / claim panel. Renders a row per tier with:
##   - Tier label + XP threshold (dimmed if not yet reached)
##   - Free reward summary + Claim button (claimable once threshold met)
##   - Premium reward summary + Claim button (greyed until battle_pass_premium_s1 purchased)
## Premium unlock is via Shop — this panel only surfaces the CTA label.

const GOLD: Color = Color(0.941, 0.725, 0.369, 1)
const DIM: Color = Color(0.5, 0.53, 0.66, 1)
const UNREACHED: Color = Color(0.42, 0.45, 0.58, 1)

@onready var _season_label: Label = %SeasonLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _premium_status: Label = %PremiumStatusLabel
@onready var _list: VBoxContainer = %ListVBox
@onready var _close: Button = %CloseButton

var _bp: BattlePassService

func _ready() -> void:
	_bp = _find_bp_service()
	_close.pressed.connect(_on_close)
	_refresh()

func _refresh() -> void:
	if _bp == null or _bp.get_season() == null:
		_progress_label.text = "—"
		return
	_season_label.text = tr(_bp.get_season().display_name)
	var current_tier: int = _bp.get_current_tier_index()
	var total: int = _bp.get_season().tiers.size()
	_progress_label.text = tr("BP_PROGRESS_FMT") % [_bp.get_xp(), current_tier, total]
	_premium_status.text = tr("BP_PREMIUM_ACTIVE") if _bp.is_premium_unlocked() else tr("BP_PREMIUM_LOCKED")
	_premium_status.modulate = GOLD if _bp.is_premium_unlocked() else DIM
	for child in _list.get_children():
		child.queue_free()
	for tier in _bp.get_season().tiers:
		_list.add_child(_build_row(tier))

func _build_row(tier: BattlePassTier) -> Control:
	var reached: bool = GameState.battle_pass_xp >= tier.xp_required
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var header: Label = Label.new()
	header.text = tr("BP_TIER_FMT") % [tier.tier, tier.xp_required]
	header.add_theme_font_size_override("font_size", 16)
	if not reached:
		header.modulate = UNREACHED
	row.add_child(header)

	var tracks: HBoxContainer = HBoxContainer.new()
	tracks.add_theme_constant_override("separation", 12)
	row.add_child(tracks)

	tracks.add_child(_build_track(tier, false))
	tracks.add_child(_build_track(tier, true))
	return row

func _build_track(tier: BattlePassTier, premium: bool) -> Control:
	var card: VBoxContainer = VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 4)

	var header: Label = Label.new()
	header.text = tr("BP_PREMIUM_TRACK") if premium else tr("BP_FREE_TRACK")
	header.add_theme_font_size_override("font_size", 13)
	if premium:
		header.modulate = GOLD
	card.add_child(header)

	var grants: Dictionary = tier.premium_reward if premium else tier.free_reward
	var summary: Label = Label.new()
	summary.text = _format_reward(grants)
	summary.add_theme_font_size_override("font_size", 13)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(summary)

	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_font_size_override("font_size", 13)
	card.add_child(btn)

	var already: Array[int] = GameState.battle_pass_claimed_premium if premium else GameState.battle_pass_claimed_free
	if already.has(tier.tier):
		btn.text = tr("BP_CLAIMED")
		btn.disabled = true
		summary.modulate = DIM
	elif _bp.is_claimable(tier.tier, premium):
		btn.text = tr("BP_CLAIM")
		btn.pressed.connect(_on_claim_pressed.bind(tier.tier, premium))
	elif premium and not _bp.is_premium_unlocked():
		btn.text = tr("BP_LOCKED_PREMIUM")
		btn.disabled = true
		summary.modulate = DIM
	else:
		btn.text = tr("BP_LOCKED_XP")
		btn.disabled = true
		summary.modulate = UNREACHED
	return card

func _format_reward(grants: Dictionary) -> String:
	var parts: Array[String] = []
	if grants.has("credit"):
		parts.append(tr("BP_REWARD_CREDIT_FMT") % int(grants["credit"]))
	if grants.has("tech_level"):
		parts.append(tr("BP_REWARD_TECH_FMT") % int(grants["tech_level"]))
	if grants.has("boosts"):
		var boosts: Dictionary = grants["boosts"]
		for boost_id in boosts:
			var sec: int = int(boosts[boost_id])
			parts.append(tr("BP_REWARD_BOOST_FMT") % [String(boost_id), sec / 86400])
	return "  ·  ".join(parts) if not parts.is_empty() else "—"

func _on_claim_pressed(tier_num: int, premium: bool) -> void:
	if _bp.claim(tier_num, premium):
		_refresh()

func _find_bp_service() -> BattlePassService:
	var main_screen: Node = get_tree().current_scene
	if main_screen == null:
		return null
	return main_screen.get_node_or_null("BattlePassService") as BattlePassService

func _on_close() -> void:
	hide()
	queue_free()
