# star-reach/ — Godot 4.6 Project Guide

Godot 엔진 내부 코드·씬·리소스 작성 규칙. 루트 지침은 [`../CLAUDE.md`](../CLAUDE.md) 참조.

## 엔진/프로젝트 설정

- Godot **4.6 Standard**, GDScript 전용 (C# 미사용)
- Renderer: `gl_compatibility` (Windows는 D3D12)
- `project.godot`의 `config/features`에 `"4.6"` 포함 — 4.6 포맷 씬/리소스만 편집
- **엔진 자동 생성 디렉터리**: `.godot/` 는 `.gitignore`. AI도 직접 편집하지 않음 (임포트 캐시, 충돌 위험)

## 디렉터리 레이아웃 (생성 시 규칙)

기획 성장에 따라 아래 구조로 점진 확장:

```
star-reach/
├── project.godot
├── main.tscn                    # 진입 씬
├── scenes/                      # .tscn (기능별 폴더)
│   ├── ui/
│   ├── game/
│   └── common/
├── scripts/                     # .gd (씬과 1:1 매칭되지 않는 순수 로직/리소스)
│   ├── autoload/                # GameState, EventBus, SaveSystem, TimeManager
│   ├── resources/               # 커스텀 Resource 클래스 (*.gd, class_name)
│   ├── systems/                 # Tick, Economy, Prestige 등
│   └── ui/
├── data/                        # .tres 인스턴스 (밸런싱 데이터)
│   ├── generators/
│   ├── upgrades/
│   └── currencies/
└── assets/
    ├── art/
    ├── audio/
    └── fonts/
```

**씬과 스크립트 쌍**: `scenes/ui/hud.tscn` ↔ `scenes/ui/hud.gd` (같은 폴더, 같은 이름). 스크립트가 해당 씬만 사용하면 `scripts/` 하위가 아닌 씬 옆에 둡니다.

## 네이밍

- **파일명**: `snake_case.gd`, `snake_case.tscn`, `snake_case.tres`
- **클래스명** (`class_name`): `PascalCase` — 예: `class_name Generator`
- **노드명** (씬 내부): `PascalCase` — 예: `ResourceBar`, `PrestigeButton`
- **상수**: `SCREAMING_SNAKE_CASE`
- **시그널**: `snake_case`, 동사 과거형/상태 변화형 — `resource_changed`, `upgrade_purchased`
- **불리언**: `is_`, `has_`, `can_` 접두

## GDScript 스타일 (필수 규칙)

### 타입 힌트 전면 강제
```gdscript
# O
var health: int = 100
func take_damage(amount: int) -> void: ...
@export var speed: float = 200.0
var enemies: Array[Enemy] = []

# X — 추론에 의존하지 않음
var health = 100
func take_damage(amount): ...
```

### 파일 구성 순서 (엄수)
```gdscript
class_name Foo
extends Node

## 클래스 한 줄 설명 (doc comment)

# 1) Signals
signal value_changed(new_value: int)

# 2) Enums & Constants
enum State { IDLE, ACTIVE }
const MAX_LEVEL := 100

# 3) @export vars
@export var speed: float = 1.0

# 4) Public vars
var current_value: int = 0

# 5) @onready / private vars
@onready var _timer: Timer = $Timer
var _accumulator: float = 0.0

# 6) Built-in callbacks (_init, _ready, _process, _input ...)
func _ready() -> void: ...

# 7) Public API
func do_thing() -> void: ...

# 8) Private helpers
func _compute() -> int: ...
```

### 시그널 연결
- **코드에서 연결**: `button.pressed.connect(_on_button_pressed)` — 에디터 UI 연결은 피합니다 (AI 편집 환경과 충돌 가능).
- 콜백 이름은 `_on_<source>_<signal>` 규칙.

### Autoload 접근
- 오토로드는 **싱글턴 이름 그대로** 참조: `GameState.gold`, `EventBus.level_up.emit(...)`.
- 직접 경로(`/root/GameState`)로 접근 금지 — 리팩터에 취약.

### 금지 패턴
- `get_node("../../Parent/Child")` 같은 **깊은 상대 경로** — `@onready` + `%UniqueName` 사용.
- `match` 없이 긴 `if/elif` 체인 (상태 분기).
- 전역에 `preload()` 남발 — 큰 리소스는 필요 시점에 `load()`.
- `print()` 를 배포 빌드에 남김 — 디버그 출력은 `print_debug()` 또는 `Logger` 유틸.

## 씬(.tscn) 편집 규칙

Godot 4 씬 파일은 텍스트지만 UID/ExtResource 정합성 때문에 민감합니다.

- **UID 보존**: 기존 씬의 `uid="uid://..."`, 외부 리소스의 `uid=` 는 변경하지 않음. 복제 시 새 UID는 `godot --uid-generate` 또는 수동으로 유일한 값으로.
- **ExtResource 번호**: `[ext_resource ... id="1_abcde"]` 의 id 문자열은 씬 내부에서 유일하면 어떤 것이든 OK이나, **기존 id를 바꾸지 말 것**.
- **SubResource**: 이름이 같은 서브리소스가 늘어나면 `id="1"`, `id="2"` ... 순서. 중간 id를 빈 채 두지 말 것.
- **큰 씬 수술은 `godot-scene-surgeon` 에이전트**에 위임.
- **정 안되면 코드 생성으로 회피**: `_ready()` 안에서 `Node.new()` + `add_child()`. 동적 UI에 특히 유리.

## Resource(.tres) 데이터 주도

정적 밸런스는 `.tres`로 분리. 예:

```gdscript
# scripts/resources/generator_def.gd
class_name GeneratorDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var base_cost: float = 10.0
@export var cost_growth: float = 1.15
@export var base_rate: float = 1.0     # resource/sec at level 1
@export var icon: Texture2D
```

```
# data/generators/miner.tres 로 인스턴스 저장
```

**런타임 인스턴스 상태** (현재 레벨, 누적 등)는 별도 `GeneratorState` 구조에 보관 — 정의(Def)와 상태(State)를 분리합니다.

## 오토로드 (기본 세트)

`project.godot`의 `[autoload]` 섹션에 순서대로 등록. 뒤에 올수록 앞의 것을 참조할 수 있음.

| 이름 | 경로 | 역할 |
|---|---|---|
| `EventBus` | `scripts/autoload/event_bus.gd` | 전역 시그널 허브 (상태 없음) |
| `GameState` | `scripts/autoload/game_state.gd` | 재화, 업그레이드, 플레이어 진행도 |
| `TimeManager` | `scripts/autoload/time_manager.gd` | 틱, 오프라인 델타, 시간 배율 |
| `SaveSystem` | `scripts/autoload/save_system.gd` | 저장·로드·마이그레이션 |

**원칙**: 오토로드는 **최소한**. 4개 초과 시 정당성 재검토. 씬 단위 매니저로 내려갈 수 있는 건 오토로드에 두지 않습니다.

## 저장 시스템

```gdscript
# scripts/autoload/save_system.gd (요지)
const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

func save_game() -> void:
    var data := {
        "version": SAVE_VERSION,
        "saved_at": Time.get_unix_time_from_system(),
        "state": GameState.to_dict(),
    }
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    f.store_string(JSON.stringify(data))

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH): return false
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY: return false
    _migrate(parsed)
    GameState.from_dict(parsed["state"])
    return true
```

- `to_dict()` / `from_dict()` 패턴을 `GameState`에 구현.
- `_migrate()`는 `version` 을 보고 `SAVE_VERSION`까지 필드를 업그레이드.
- 세이브 손상 대비: 저장은 **임시 파일에 쓰고 rename** (원자적 쓰기).

## 오프라인 진행 계산

```gdscript
# TimeManager.apply_offline_progress
func apply_offline_progress(last_saved_unix: int) -> float:
    var now := Time.get_unix_time_from_system()
    var delta := max(0.0, float(now - last_saved_unix))
    var capped := min(delta, MAX_OFFLINE_SECONDS)  # 예: 8 * 3600
    GameState.advance_simulation(capped)
    return capped
```

- 로드 직후 1회 호출. 사용자에게 요약 UI 표시.
- `advance_simulation(dt)` 는 실시간 `_process`와 **같은 경로**를 사용 (중복 로직 금지).

## 틱/시간 배율

- 시간 배율(`TimeManager.speed_multiplier`)을 통해 디버그·이벤트 가속을 제어.
- `_process(delta)` 소비자는 항상 `delta * TimeManager.speed_multiplier` 를 사용.

## UI 규칙

- **Control 기반 레이아웃** — Anchor/Margin 대신 **Container 노드** (HBox/VBox/MarginContainer)로 반응형 구성.
- **`%UniqueName`** 으로 참조 — 깊은 경로 지양.
- UI 업데이트는 **시그널 구독**: `GameState.gold_changed.connect(_update_gold_label)`. `_process`에서 매 프레임 읽지 말 것 (불필요한 재할당).
- 숫자 포맷은 `scripts/systems/number_formatter.gd` 하나로 통일.

## 입력

- **InputMap** (`project.godot` `[input]` 섹션) 등록 후 `Input.is_action_*` 사용. 키코드 하드코딩 금지.
- 추가는 `/godot-add-input` 스킬 사용.

## 테스트/검증

- 로직 단위 테스트는 `scripts/tests/` 에 `test_*.gd` 스타일로. 실행은 `godot --headless -s scripts/tests/run_all.gd`.
- GUT/gdUnit4 도입은 기획 확정 후 판단 (조기 도입 금지).

## 빌드/내보내기

- 내보내기 프리셋은 `export_presets.cfg` (커밋 대상). 환경별 비밀값은 `.env` 또는 `--export-with-debug` 플래그로 분리.
- 플랫폼별 유의점은 [`../study/godot_export_platforms.md`](../study/godot_export_platforms.md) 참조.
