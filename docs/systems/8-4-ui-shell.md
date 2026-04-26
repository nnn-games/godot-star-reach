# 8-4. UI Shell — MainScreen + GlobalHUD

> 카테고리: Shell / Platform
> 구현: `scenes/main/main_screen.tscn`, `scripts/ui/main_screen.gd`, `scenes/ui/global_hud.tscn`, `scenes/ui/launch_app.tscn`, `scripts/services/player_state_service.gd`

## 1. 시스템 개요

Godot `Control` 기반 UI 셸. 메인 화면(`MainScreen`)이 항상 표시되며, 메뉴/오버레이는 `CanvasLayer`(`GlobalHUD`) 위에 마운트된다. UI 상태는 `PlayerStateService`가 5개 상태(idle / launching / cinematic / overlay / settings)로 관리.

**책임 경계**
- 메인 화면 레이아웃 (상단 3화폐 / 중앙 발사 영역 / 하단 LAUNCH).
- `GlobalHUD` 메뉴 진입점 (Codex / Mission / Upgrade / Settings).
- `LaunchApp` 발사 시퀀스 오버레이.
- `PlayerStateService` UI 상태 머신.
- `EventBus` 시그널 구독 → UI 반영.

**책임 아닌 것**
- 게임 로직 (각 도메인 시스템).
- 시네마틱 재생 자체 (전용 시스템에 위임).
- 데이터 저장 (→ 8-1).

## 2. 코어 로직

### 2.1 씬 트리 구조

```
scenes/main/main_screen.tscn  (Control, full-rect)
├─ Background (TextureRect)
├─ TopBar (HBoxContainer)
│   ├─ CreditLabel
│   ├─ TechLevelLabel
│   └─ XPLabel
├─ CenterArea (Control)
│   ├─ DestinationInfo (VBoxContainer)
│   └─ LaunchPad (TextureRect)
├─ BottomBar (VBoxContainer)
│   ├─ StressGauge (ProgressBar)
│   ├─ AutoLaunchToggle (CheckBox)
│   └─ LaunchButton (Button)
└─ Services (Node)
    ├─ LaunchService
    ├─ DestinationService
    └─ MissionService

scenes/ui/global_hud.tscn  (CanvasLayer, layer=10)
└─ HUDRoot (Control)
    └─ MenuBar (HBoxContainer)
        ├─ CodexButton
        ├─ MissionButton
        ├─ UpgradeButton
        └─ SettingsButton

scenes/ui/launch_app.tscn  (CanvasLayer, layer=20)
└─ LaunchOverlay (Control)
    ├─ StageProgressBar
    ├─ LogPanel (RichTextLabel)
    └─ AbortButton
```

`GlobalHUD`와 `LaunchApp`은 별도 `CanvasLayer`로 분리해 메인 화면 위에 겹친다 — `layer` 값이 클수록 위에 그려진다.

### 2.2 UI 상태 머신 (`PlayerStateService`)

```gdscript
# scripts/services/player_state_service.gd
extends Node

enum UIState { IDLE, LAUNCHING, CINEMATIC, OVERLAY, SETTINGS }

signal state_changed(prev: UIState, next: UIState)

var current: UIState = UIState.IDLE

func transition(next: UIState) -> bool:
    if not _is_valid_transition(current, next):
        push_warning("Invalid UI transition: %s → %s" % [current, next])
        return false
    var prev: UIState = current
    current = next
    state_changed.emit(prev, next)
    return true

func _is_valid_transition(from: UIState, to: UIState) -> bool:
    match from:
        UIState.IDLE:
            return to in [UIState.LAUNCHING, UIState.OVERLAY, UIState.SETTINGS]
        UIState.LAUNCHING:
            return to in [UIState.CINEMATIC, UIState.IDLE]
        UIState.CINEMATIC:
            return to == UIState.IDLE
        UIState.OVERLAY, UIState.SETTINGS:
            return to == UIState.IDLE
    return false
```

**상태 정의**:

| 상태 | 활성 UI | 진입 트리거 | 퇴장 트리거 |
|---|---|---|---|
| `IDLE` | MainScreen + GlobalHUD | 부팅 후, 발사 종료, 오버레이 닫기 | 사용자 입력 |
| `LAUNCHING` | + LaunchApp 오버레이 | LAUNCH 버튼 | 모든 스테이지 종료 / Abort |
| `CINEMATIC` | LaunchApp (입력 차단) | 발사 성공 후 시네마틱 재생 | 시네마틱 종료 |
| `OVERLAY` | + 메뉴 패널 (Codex 등) | GlobalHUD 메뉴 버튼 | 닫기 버튼 / ESC |
| `SETTINGS` | + Settings 패널 | Settings 버튼 | 닫기 |

### 2.3 MainScreen 스크립트 — EventBus 구독

```gdscript
# scripts/ui/main_screen.gd
extends Control

@onready var credit_label: Label = %CreditLabel
@onready var tech_label: Label = %TechLevelLabel
@onready var xp_label: Label = %XPLabel
@onready var stress_gauge: ProgressBar = %StressGauge
@onready var launch_button: Button = %LaunchButton
@onready var auto_toggle: CheckBox = %AutoLaunchToggle

func _ready() -> void:
    SaveSystem.profile_loaded.connect(_refresh_all)
    EventBus.currency_changed.connect(_on_currency_changed)
    EventBus.stress_changed.connect(_on_stress_changed)
    EventBus.launch_started.connect(_on_launch_started)
    EventBus.launch_completed.connect(_on_launch_completed)
    EventBus.offline_progress_computed.connect(_on_offline_summary)
    launch_button.pressed.connect(_on_launch_pressed)
    auto_toggle.toggled.connect(_on_auto_toggled)
    _refresh_all()

func _refresh_all() -> void:
    credit_label.text = NumberFormat.compact(GameState.credit)
    tech_label.text = NumberFormat.compact(GameState.tech_level)
    xp_label.text = NumberFormat.compact(GameState.launch_tech_session.get("xp", 0))
    stress_gauge.value = GameState.risk_session.get("gauge", 0.0)
    auto_toggle.button_pressed = GameState.auto_launch_enabled

func _on_currency_changed(currency_id: String, new_value: int) -> void:
    match currency_id:
        "credit": credit_label.text = NumberFormat.compact(new_value)
        "tech_level": tech_label.text = NumberFormat.compact(new_value)
        "xp": xp_label.text = NumberFormat.compact(new_value)

func _on_launch_pressed() -> void:
    if PlayerStateService.transition(PlayerStateService.UIState.LAUNCHING):
        LaunchService.launch_rocket()
```

**규칙** (CLAUDE.md): UI는 `GameState` 필드를 **읽기만** 한다. 쓰기는 도메인 서비스(`LaunchService` 등)를 호출하고, 결과는 `EventBus` 시그널로 받는다.

### 2.4 GlobalHUD — 메뉴 진입점

```gdscript
# scripts/ui/global_hud.gd
extends CanvasLayer

@onready var codex_btn: Button = %CodexButton
@onready var mission_btn: Button = %MissionButton
@onready var upgrade_btn: Button = %UpgradeButton
@onready var settings_btn: Button = %SettingsButton

const PANEL_SCENES: Dictionary = {
    "codex": preload("res://scenes/ui/panels/codex_panel.tscn"),
    "mission": preload("res://scenes/ui/panels/mission_panel.tscn"),
    "upgrade": preload("res://scenes/ui/panels/upgrade_panel.tscn"),
    "settings": preload("res://scenes/ui/panels/settings_panel.tscn"),
}

var _current_panel: Control = null

func _ready() -> void:
    codex_btn.pressed.connect(_open.bind("codex", PlayerStateService.UIState.OVERLAY))
    mission_btn.pressed.connect(_open.bind("mission", PlayerStateService.UIState.OVERLAY))
    upgrade_btn.pressed.connect(_open.bind("upgrade", PlayerStateService.UIState.OVERLAY))
    settings_btn.pressed.connect(_open.bind("settings", PlayerStateService.UIState.SETTINGS))

func _open(panel_id: String, target_state: int) -> void:
    if not PlayerStateService.transition(target_state):
        return
    _current_panel = PANEL_SCENES[panel_id].instantiate()
    add_child(_current_panel)
    _current_panel.tree_exiting.connect(_on_panel_closed)

func _on_panel_closed() -> void:
    _current_panel = null
    PlayerStateService.transition(PlayerStateService.UIState.IDLE)
```

### 2.5 LaunchApp — 발사 오버레이

발사 시퀀스 동안 메인 화면 위에 활성. `PlayerStateService.LAUNCHING` 상태에서만 보인다.

```gdscript
# scripts/ui/launch_app.gd
extends CanvasLayer

@onready var stage_bar: ProgressBar = %StageProgressBar
@onready var log_panel: RichTextLabel = %LogPanel
@onready var abort_button: Button = %AbortButton

func _ready() -> void:
    visible = false
    PlayerStateService.state_changed.connect(_on_state_changed)
    EventBus.stage_succeeded.connect(_on_stage_succeeded)
    EventBus.stage_failed.connect(_on_stage_failed)
    EventBus.abort_triggered.connect(_on_abort)
    abort_button.pressed.connect(_on_abort_pressed)

func _on_state_changed(_prev: int, next: int) -> void:
    visible = next in [PlayerStateService.UIState.LAUNCHING, PlayerStateService.UIState.CINEMATIC]

func _on_stage_succeeded(idx: int, chance: float) -> void:
    log_panel.append_text("[color=green]Stage %d cleared (%.1f%%)[/color]\n" % [idx + 1, chance * 100.0])
```

### 2.6 부팅 시퀀스

```
1. project.godot 부팅 → Autoloads ready
   (EventBus → GameState → SaveSystem → TelemetryService → PlayerStateService)
2. SaveSystem._load_or_seed() → GameState 채움 → profile_loaded.emit()
3. main.tscn → main_screen.tscn 인스턴스화
4. MainScreen._ready() → _refresh_all() (현재 GameState 반영)
5. SaveSystem.compute_offline_progress() → EventBus.offline_progress_computed
6. MainScreen이 오프라인 요약 팝업 표시
7. PlayerStateService.current = IDLE
```

### 2.7 숫자 표시 유틸 (`NumberFormat`)

3화폐 표시는 과학 표기 / SI 접두어 포맷터로 일원화 (CLAUDE.md 규칙):

```gdscript
# scripts/util/number_format.gd
class_name NumberFormat

static func compact(n: float) -> String:
    var abs_n: float = absf(n)
    if abs_n < 1000.0:
        return "%d" % int(n)
    var suffixes: Array = ["K", "M", "B", "T", "Qa", "Qi"]
    var idx: int = -1
    while abs_n >= 1000.0 and idx + 1 < suffixes.size():
        abs_n /= 1000.0
        idx += 1
    return "%.2f%s" % [n / pow(1000.0, idx + 1), suffixes[idx]]
```

## 3. 정적 데이터 (Config)

| 리소스 | 역할 |
|---|---|
| `data/ui/theme.tres` | Godot `Theme` 리소스 (폰트, 색상, StyleBox) |
| `data/ui/layout_constants.tres` | 패딩/마진/브레이크포인트 |

`scenes/main/main_screen.tscn`이 `theme` 프로퍼티로 참조. 변경 시 모든 `Control` 자식이 자동 갱신.

## 4. 플레이어 영속 데이터

**없음** — UI 자체 상태는 메모리. 사용자 설정(볼륨, 언어 등)은 `GameState.settings` 별도 필드로 분리해 저장.

## 5. 런타임 상태

| 위치 | 필드 | 용도 |
|---|---|---|
| `PlayerStateService` | `current: UIState` | 5-state UI 상태 머신 |
| `MainScreen` | `@onready var` 캐시 | UI 노드 참조 |
| `GlobalHUD` | `_current_panel: Control` | 현재 마운트된 메뉴 패널 |

## 6. 시그널 (EventBus)

이 시스템이 **구독하는** 시그널 (대표):
- `currency_changed`, `stress_changed`
- `launch_started`, `stage_succeeded`, `stage_failed`, `launch_completed`
- `abort_triggered`
- `offline_progress_computed`
- `mission_progress_updated`, `codex_updated`, `upgrade_purchased`

이 시스템이 **발행하는** 시그널:
- `PlayerStateService.state_changed` (자체 시그널 — 횡단성 약함)

## 7. 의존성

**의존**:
- `EventBus`, `GameState`, `SaveSystem`, `PlayerStateService` (모두 Autoload)
- `LaunchService`, `DestinationService` 등 도메인 서비스 (직접 메서드 호출)

**의존받음**:
- `main.tscn` (메인 씬 루트)

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scenes/main/main_screen.tscn` | 메인 화면 씬 |
| `scripts/ui/main_screen.gd` | 메인 화면 스크립트 |
| `scenes/ui/global_hud.tscn` | 메뉴 HUD (CanvasLayer) |
| `scripts/ui/global_hud.gd` | HUD 스크립트 |
| `scenes/ui/launch_app.tscn` | 발사 오버레이 (CanvasLayer) |
| `scripts/ui/launch_app.gd` | 발사 오버레이 스크립트 |
| `scenes/ui/panels/*.tscn` | Codex / Mission / Upgrade / Settings 패널 |
| `scripts/services/player_state_service.gd` | UI 상태 머신 (Autoload) |
| `scripts/util/number_format.gd` | 숫자 포맷터 |
| `data/ui/theme.tres` | UI 테마 리소스 |
| `data/ui/layout_constants.tres` | 레이아웃 상수 |
