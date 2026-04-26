extends Control

## Main playable screen.
## Phase 1: LaunchService wiring + 3-currency display + stage indicator.
## Phase 2: Stress UI + AbortScreen + Pity / Tier-conquest debug.
## Phase 3: SkyProfile transition + camera-equivalent screen shake + flash overlay
##          + milestone highlight in the result modal.

const DESTINATIONS_DIR: String = "res://data/destinations/"
const RESULT_MODAL_SCENE: PackedScene = preload("res://scenes/ui/launch_result_modal.tscn")
const ABORT_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/abort_screen.tscn")
const OFFLINE_MODAL_SCENE: PackedScene = preload("res://scenes/ui/offline_summary_modal.tscn")
const SETTINGS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/settings_panel.tscn")
const CODEX_PANEL_SCENE: PackedScene = preload("res://scenes/ui/codex_panel.tscn")
const BADGE_PANEL_SCENE: PackedScene = preload("res://scenes/ui/badge_panel.tscn")
const MISSION_PANEL_SCENE: PackedScene = preload("res://scenes/ui/mission_panel.tscn")
const SHOP_PANEL_SCENE: PackedScene = preload("res://scenes/ui/shop_panel.tscn")
const BATTLE_PASS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/battle_pass_panel.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text.tscn")
const STRESS_BAR_OVERLOAD_THRESHOLD: float = 100.0

# Immersion: during an active launch, every HUD element except the stage itself
# fades down so the rocket / starfield owns the screen. Values are tuned to
# stay legible (0.35 keeps text outlines readable) but clearly recede.
const UI_DIM_ALPHA: float = 0.35
const UI_FULL_ALPHA: float = 1.0
const UI_FADE_DURATION: float = 0.3

# Accent colors for floating "+X" rewards — match the currency pill palette.
const FLOAT_XP_COLOR: Color = Color(0.5, 0.88, 1.0, 1)
const FLOAT_CREDIT_COLOR: Color = Color(1.0, 0.82, 0.4, 1)
const FLOAT_TECH_COLOR: Color = Color(0.82, 0.62, 1.0, 1)

# Flash colors / shake amplitudes are tuned for a placeholder feel; Phase 5
# will replace them with motion-art curves and proper Tween easing.
const COLOR_FLASH_SUCCESS: Color = Color(1.0, 0.95, 0.7)
const COLOR_FLASH_FAIL: Color = Color(0.6, 0.05, 0.05)
const COLOR_FLASH_ABORT: Color = Color(1.0, 0.25, 0.05)
const SHAKE_AMP_SUCCESS: float = 2.0
const SHAKE_DUR_SUCCESS: float = 0.15
const SHAKE_AMP_FAIL: float = 8.0
const SHAKE_DUR_FAIL: float = 0.5
const SHAKE_AMP_ABORT: float = 16.0
const SHAKE_DUR_ABORT: float = 0.7

# First clear of one of these triggers the milestone-flavoured result modal.
# Mirrors the curated arc: end of T1 zone, end of Lunar, mid-Mars, end-of-T4 Jovian,
# Pluto entry to T5, and the V1 ending at the edge of the Local Group.
const MILESTONE_DESTINATIONS: Array[String] = ["D_010", "D_020", "D_025", "D_050", "D_075", "D_100"]

@onready var _launch_service: LaunchService = $LaunchService
@onready var _stress_service: StressService = $StressService
@onready var _auto_launch_service: AutoLaunchService = $AutoLaunchService
@onready var _offline_progress_service: OfflineProgressService = $OfflineProgressService
@onready var _discovery_service: DiscoveryService = $DiscoveryService
@onready var _badge_service: BadgeService = $BadgeService
@onready var _mission_service: MissionService = $MissionService
@onready var _sky_layer: SkyLayer = %SkyLayer
@onready var _sky_applier: SkyProfileApplier = $SkyProfileApplier
@onready var _screen_shake: ScreenShake = $ScreenShake
@onready var _modal_layer: CanvasLayer = $ModalLayer
@onready var _flash_overlay: FlashOverlay = %FlashOverlay
@onready var _top_hud: HBoxContainer = %TopHUD
@onready var _xp_pill: CurrencyPill = %XPPill
@onready var _credit_pill: CurrencyPill = %CreditPill
@onready var _tech_pill: CurrencyPill = %TechPill
@onready var _destination_label: Label = %DestinationLabel
@onready var _rocket_track: RocketTrack = %RocketTrack
@onready var _result_label: Label = %ResultLabel
@onready var _stress_bar: ProgressBar = %StressBar
@onready var _action_area: VBoxContainer = %ActionArea
@onready var _launch_button: Button = %LaunchButton
@onready var _auto_launch_toggle: CheckButton = %AutoLaunchToggle
@onready var _settings_button: Button = %SettingsButton
@onready var _bottom_tab_bar: HBoxContainer = %BottomTabBar
@onready var _codex_button: Button = %CodexButton
@onready var _badges_button: Button = %BadgesButton
@onready var _missions_button: Button = %MissionsButton
@onready var _battle_pass_button: Button = %BattlePassButton
@onready var _shop_button: Button = %ShopButton
@onready var _debug_label: Label = %DebugLabel

var _destinations: Array[Destination] = []
var _ui_dim_targets: Array[Control] = []
var _ui_dim_tween: Tween

func _ready() -> void:
	_load_all_destinations()
	# Dev-only overlay: stripped from exported release builds so shipping players
	# never see pity / cleared-tiers / raw counters.
	_debug_label.visible = OS.is_debug_build()
	# Wire sibling services through MainScreen — no Autoload bloat.
	_launch_service.stress_service = _stress_service
	_sky_applier.sky_layer = _sky_layer
	_screen_shake.target = self
	_auto_launch_service.launch_service = _launch_service
	_offline_progress_service.auto_launch_service = _auto_launch_service
	_offline_progress_service.destinations = _destinations
	# EventBus subscriptions.
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.launch_started.connect(_on_launch_started)
	EventBus.stage_succeeded.connect(_on_stage_succeeded)
	EventBus.stage_failed.connect(_on_stage_failed)
	EventBus.launch_completed.connect(_on_launch_completed)
	EventBus.destination_completed.connect(_on_destination_completed)
	EventBus.stress_changed.connect(_on_stress_changed)
	EventBus.abort_triggered.connect(_on_abort_triggered)
	EventBus.offline_summary_ready.connect(_on_offline_summary_ready)
	# Codex / Badge meta debug refresh.
	EventBus.codex_entry_unlocked.connect(_on_meta_changed)
	EventBus.codex_entry_updated.connect(_on_meta_changed)
	EventBus.badge_awarded.connect(_on_meta_changed)
	# Boost activation re-labels the Auto Launch toggle with the remaining window.
	EventBus.boost_activated.connect(_on_boost_activated)
	_launch_button.pressed.connect(_on_launch_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_codex_button.pressed.connect(_on_codex_pressed)
	_badges_button.pressed.connect(_on_badges_pressed)
	_missions_button.pressed.connect(_on_missions_pressed)
	_battle_pass_button.pressed.connect(_on_battle_pass_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_auto_launch_toggle.toggled.connect(_on_auto_launch_toggled)
	# Restore destination from save (or default to D_001).
	var initial: Destination = _find_destination_by_id(GameState.current_destination_id)
	if initial == null:
		initial = _destinations[0]
	_launch_service.set_destination(initial)
	# Snap to the right sky on entry — no transition before player even sees it.
	_sky_applier.apply_immediate(initial)
	# Seed pills from current state without count-up animation.
	_xp_pill.set_value(GameState.xp, false)
	_credit_pill.set_value(GameState.credit, false)
	_tech_pill.set_value(GameState.tech_level, false)
	# Register all UI elements that dim during launch; StressBar intentionally
	# stays at full opacity — it's gameplay-critical during an active attempt.
	_ui_dim_targets = [_top_hud, _settings_button, _destination_label, _action_area, _bottom_tab_bar]
	_refresh_all()
	_refresh_auto_launch_toggle()

# --- Currency UI ---

func _on_currency_changed(currency_type: StringName, _new_value: int) -> void:
	match currency_type:
		&"xp": _xp_pill.set_value(GameState.xp)
		&"credit": _credit_pill.set_value(GameState.credit)
		&"tech_level": _tech_pill.set_value(GameState.tech_level)
	_refresh_debug()

func _refresh_all() -> void:
	_xp_pill.set_value(GameState.xp, false)
	_credit_pill.set_value(GameState.credit, false)
	_tech_pill.set_value(GameState.tech_level, false)
	_refresh_destination_label()
	_refresh_stress_bar()
	_refresh_auto_launch_toggle()
	_refresh_debug()

## Dynamic format-string labels don't participate in Godot's auto_translate
## cascade, so we explicitly re-render them when the locale changes live.
## is_node_ready() guards against a pending TRANSLATION_CHANGED arriving
## before @onready vars are resolved (the initial pass happens in _ready()).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_all()

# --- Launch loop ---

func _on_launch_pressed() -> void:
	if _launch_service.is_launching():
		return
	_result_label.text = ""
	_launch_service.start_launch()

func _on_launch_started() -> void:
	_launch_button.disabled = true
	_rocket_track.set_stage_count(_launch_service.get_current_destination().required_stages)
	_dim_ui(UI_DIM_ALPHA)

func _on_stage_succeeded(stage_index: int, chance: float) -> void:
	_rocket_track.advance_stage(stage_index)
	_result_label.text = tr("STAGE_PASS_FMT") % [stage_index, chance * 100.0]
	_flash_overlay.flash(COLOR_FLASH_SUCCESS, 0.20, 0.35)
	_screen_shake.shake(SHAKE_AMP_SUCCESS, SHAKE_DUR_SUCCESS)
	# Per-stage XP is granted immediately by LaunchService → surface it near the rocket.
	_spawn_floating_text(tr("FLOAT_XP_FMT") % LaunchService.XP_PER_STAGE, FLOAT_XP_COLOR)

func _on_stage_failed(stage_index: int, chance: float) -> void:
	_rocket_track.crash(stage_index)
	_result_label.text = tr("STAGE_FAIL_FMT") % [stage_index, chance * 100.0]
	_flash_overlay.flash(COLOR_FLASH_FAIL, 0.30, 0.6)
	_screen_shake.shake(SHAKE_AMP_FAIL, SHAKE_DUR_FAIL)
	_launch_button.disabled = false
	_dim_ui(UI_FULL_ALPHA)
	_refresh_debug()  # consecutive_failures incremented in LaunchService._finalize

func _on_launch_completed(d_id: String) -> void:
	# Inline label is the cheap feedback. Full reward summary lives in the modal,
	# triggered from destination_completed below.
	var d: Destination = _find_destination_by_id(d_id)
	if d != null:
		_result_label.text = tr("DEST_CLEARED_FMT") % d.display_name
		# Reward floaters — stagger so they read as a small celebration stream.
		if d.reward_credit > 0:
			_spawn_floating_text(tr("FLOAT_CREDIT_FMT") % d.reward_credit, FLOAT_CREDIT_COLOR, 0.10)
		if d.reward_tech_level > 0:
			_spawn_floating_text(tr("FLOAT_TECH_FMT") % d.reward_tech_level, FLOAT_TECH_COLOR, 0.22)
	_rocket_track.complete()
	_launch_button.disabled = false
	_dim_ui(UI_FULL_ALPHA)
	# Unlock-on-progress: a fresh T1 clear (or 10 manual launches) reveals the toggle.
	_refresh_auto_launch_toggle()

## destination_completed fires immediately after launch_completed and carries the
## reward dict + is_first_clear. Modal pops here; auto-advance is deferred to
## modal Continue so the player has time to read the reward.
func _on_destination_completed(d_id: String, payload: Dictionary) -> void:
	var d: Destination = _find_destination_by_id(d_id)
	if d == null:
		return
	var is_milestone: bool = MILESTONE_DESTINATIONS.has(d_id) and bool(payload.get("is_first_clear", false))
	var next_d: Destination = _next_destination_for_modal(d)
	var modal: LaunchResultModal = RESULT_MODAL_SCENE.instantiate()
	_modal_layer.add_child(modal)
	modal.setup(d, payload, next_d, is_milestone)
	modal.popup_centered(modal.size)
	modal.closed.connect(_try_auto_advance.bind(d))

## Preview-only lookup: returns the next destination in sequence regardless of
## the tech-level gate (the modal itself shows a "locked" badge if required_tech
## isn't met). Returns null on the last destination in the list.
func _next_destination_for_modal(current: Destination) -> Destination:
	var idx: int = _destinations.find(current)
	if idx < 0 or idx + 1 >= _destinations.size():
		return null
	return _destinations[idx + 1]

# --- Destination management ---

func _try_auto_advance(just_cleared: Destination) -> void:
	if just_cleared == null:
		return
	var idx: int = _destinations.find(just_cleared)
	if idx < 0 or idx + 1 >= _destinations.size():
		return  # last destination cleared — stay until next data drop
	var next: Destination = _destinations[idx + 1]
	if GameState.tech_level >= next.required_tech_level:
		_launch_service.set_destination(next)
		# Sky transition only when actually moving on.
		_sky_applier.transition_to(next)
		_refresh_destination_label()

func _refresh_destination_label() -> void:
	var d: Destination = _launch_service.get_current_destination()
	if d == null:
		_destination_label.text = "—"
		return
	_destination_label.text = tr("DEST_LABEL_FMT") % [d.id, d.display_name, d.tier, d.required_stages]
	# Stress bar is hidden until you reach a tier where the risk system activates.
	_stress_bar.visible = d.tier >= 3
	if _stress_bar.visible:
		_refresh_stress_bar()

# --- Stress / Abort ---

func _on_stress_changed(value: float) -> void:
	if _stress_bar.visible:
		_stress_bar.value = min(value, STRESS_BAR_OVERLOAD_THRESHOLD)
	_refresh_debug()

func _on_abort_triggered(repair_cost: int) -> void:
	# Launch never started → buttons stayed enabled, UI never dimmed. Just show the modal.
	_flash_overlay.flash(COLOR_FLASH_ABORT, 0.40, 0.75)
	_screen_shake.shake(SHAKE_AMP_ABORT, SHAKE_DUR_ABORT)
	# Stop auto-launch on abort so the player gets the modal instead of an instant retry.
	if _auto_launch_service.is_enabled():
		_auto_launch_service.set_enabled(false)
		_auto_launch_toggle.set_pressed_no_signal(false)
	var modal: AbortScreen = ABORT_SCREEN_SCENE.instantiate()
	_modal_layer.add_child(modal)
	modal.setup(repair_cost)
	modal.popup_centered(modal.size)

# --- UI dim + floating text ---

## Tween the non-critical HUD alpha so the rocket stage owns the screen during
## an active launch. StressBar and RocketTrack are excluded: the first is
## critical readout, the second is the game view itself.
func _dim_ui(target_alpha: float) -> void:
	if _ui_dim_tween != null and _ui_dim_tween.is_valid():
		_ui_dim_tween.kill()
	_ui_dim_tween = create_tween().set_parallel(true)
	for ctrl in _ui_dim_targets:
		_ui_dim_tween.tween_property(ctrl, "modulate:a", target_alpha, UI_FADE_DURATION)

## Spawn a one-shot floating label at the rocket's screen position. Delay lets
## multiple rewards read as a stream rather than landing on top of each other.
func _spawn_floating_text(txt: String, color: Color, delay: float = 0.0) -> void:
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_spawn_floating_text.bind(txt, color, 0.0), CONNECT_ONE_SHOT)
		return
	var anchor: Vector2 = _rocket_track.get_rocket_global_position()
	# Random horizontal jitter so sequential floaters drift apart.
	anchor.x += randf_range(-24.0, 24.0)
	anchor.y -= 10.0
	var ft: FloatingText = FLOATING_TEXT_SCENE.instantiate()
	_modal_layer.add_child(ft)
	ft.setup(txt, color, anchor)

# --- Auto Launch ---

func _on_auto_launch_toggled(on: bool) -> void:
	_auto_launch_service.set_enabled(on)

func _refresh_auto_launch_toggle() -> void:
	var unlocked: bool = _auto_launch_service.is_unlocked()
	_auto_launch_toggle.visible = unlocked
	if unlocked:
		# Sync the visual switch with persisted state (e.g. after loading a save).
		_auto_launch_toggle.set_pressed_no_signal(_auto_launch_service.is_enabled())
	_auto_launch_toggle.text = _auto_launch_toggle_text()

## Build the toggle label. Boost active → show ★ + rounded remaining window;
## otherwise use the plain translation key so auto_translate re-renders on locale change.
func _auto_launch_toggle_text() -> String:
	var remaining: int = _auto_launch_service.get_boost_time_remaining(AutoLaunchService.BOOST_AUTO_PASS)
	if remaining <= 0:
		return "AUTO_LAUNCH_TOGGLE"
	var days: int = remaining / 86400
	var hours_only: int = (remaining % 86400) / 3600
	if days > 0:
		return tr("AUTO_LAUNCH_TOGGLE_BOOSTED_FMT") % [days, hours_only]
	var hours_total: int = remaining / 3600
	return tr("AUTO_LAUNCH_TOGGLE_BOOSTED_SHORT_FMT") % hours_total

func _on_boost_activated(_boost_id: StringName, _expire_at: int) -> void:
	_refresh_auto_launch_toggle()

# --- Offline progress ---

func _on_offline_summary_ready(summary: Dictionary) -> void:
	var modal: OfflineSummaryModal = OFFLINE_MODAL_SCENE.instantiate()
	_modal_layer.add_child(modal)
	modal.setup(summary)
	modal.popup_centered(modal.size)

func _refresh_stress_bar() -> void:
	if _stress_bar.visible:
		_stress_bar.value = min(GameState.stress_value, STRESS_BAR_OVERLOAD_THRESHOLD)

## Lightweight QA / dev overlay. Removed before V1 ship (or hidden behind a debug flag).
func _refresh_debug() -> void:
	var tier_strs: Array[String] = []
	for t in GameState.cleared_tiers:
		tier_strs.append("T%d" % t)
	var conquered: String = "[" + ", ".join(tier_strs) + "]"
	_debug_label.text = "Pity %d | %s | Stress %d | Codex %d/%d | Badges %d/%d | Missions %d/%d" % [
		GameState.consecutive_failures,
		conquered,
		int(GameState.stress_value),
		_discovery_service.get_unlocked_count(), _discovery_service.get_total_entries(),
		_badge_service.get_earned_count(), _badge_service.get_total_badges(),
		_mission_service.get_claimed_count(), _mission_service.get_total_today(),
	]

func _on_meta_changed(_id: String) -> void:
	_refresh_debug()

# --- Resource loading ---

func _load_all_destinations() -> void:
	var dir: DirAccess = DirAccess.open(DESTINATIONS_DIR)
	if dir == null:
		push_error("[MainScreen] cannot open %s" % DESTINATIONS_DIR)
		return
	var files: PackedStringArray = dir.get_files()
	files.sort()  # filename sort yields D_001, D_002, ... in order
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var d: Destination = load(DESTINATIONS_DIR.path_join(f)) as Destination
		if d != null:
			_destinations.append(d)

func _find_destination_by_id(id: String) -> Destination:
	for d in _destinations:
		if d.id == id:
			return d
	return null

# --- Navigation ---
# "Back to Menu" moved into SettingsPanel so the main game surface stays uncluttered.

func _on_settings_pressed() -> void:
	var panel: SettingsPanel = SETTINGS_PANEL_SCENE.instantiate()
	_modal_layer.add_child(panel)
	panel.popup_centered(panel.size)

func _on_codex_pressed() -> void:
	var panel: CodexPanel = CODEX_PANEL_SCENE.instantiate()
	_modal_layer.add_child(panel)
	panel.popup_centered(panel.size)

func _on_badges_pressed() -> void:
	var panel: BadgePanel = BADGE_PANEL_SCENE.instantiate()
	_modal_layer.add_child(panel)
	panel.popup_centered(panel.size)

func _on_missions_pressed() -> void:
	var panel: MissionPanel = MISSION_PANEL_SCENE.instantiate()
	_modal_layer.add_child(panel)
	panel.popup_centered(panel.size)

func _on_shop_pressed() -> void:
	var panel: ShopPanel = SHOP_PANEL_SCENE.instantiate()
	_modal_layer.add_child(panel)
	panel.popup_centered(panel.size)

func _on_battle_pass_pressed() -> void:
	var panel: BattlePassPanel = BATTLE_PASS_PANEL_SCENE.instantiate()
	_modal_layer.add_child(panel)
	panel.popup_centered(panel.size)
