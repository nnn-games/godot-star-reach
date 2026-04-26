# 8-3. Service Bootstrap — Godot Autoload 패턴

> 카테고리: Shell / Platform
> 구현: `project.godot` `[autoload]`, `scripts/autoload/*.gd`, `scripts/services/*.gd`

## 1. 시스템 개요

Godot의 **Autoload**(글로벌 싱글턴 노드) 메커니즘을 그대로 사용한다. 별도 DI 컨테이너 없이 `project.godot`의 `[autoload]` 섹션 등록 순서가 부팅 순서를 보장한다. 의존성 주입은 `Autoload.method()` 직접 호출 또는 `EventBus` 시그널 구독으로 해결.

**책임 경계**
- 전역 단일 인스턴스 노드(상태, 이벤트 버스, 저장 시스템)를 부팅 시 마운트.
- `_ready()` 깊이 우선 순회로 서비스 초기화.
- 메인 씬 전환 후에도 살아있는 영속 노드 제공.

**책임 아닌 것**
- 의존성 그래프 검증 (Godot 미제공 — 등록 순서로 수동 보장).
- 서비스 동적 추가/제거.

## 2. 코어 로직

### 2.1 Autoload 등록 (`project.godot`)

```ini
[autoload]

EventBus="*res://scripts/autoload/event_bus.gd"
GameState="*res://scripts/autoload/game_state.gd"
SaveSystem="*res://scripts/autoload/save_system.gd"
TelemetryService="*res://scripts/autoload/telemetry_service.gd"
```

**부팅 순서**: 등록 순서대로 인스턴스화 + `_ready()` 호출. 따라서 **leaf 오토로드를 위에 배치**:

| 순서 | 노드 | 의존 |
|---|---|---|
| 1 | `EventBus` | 없음 (leaf) |
| 2 | `GameState` | 없음 (leaf, 메모리 컨테이너) |
| 3 | `SaveSystem` | `GameState` (deserialize 호출) |
| 4 | `TelemetryService` | `EventBus` (이벤트 구독) |

`*` 접두사는 Godot 컨벤션 — 글로벌 변수로 노출.

### 2.2 서비스 노드 패턴

도메인 서비스(`LaunchService`, `DestinationService`, `MissionService` 등)는 두 가지 방식 중 선택:

**A. Autoload로 등록** — 게임 전체 생애 동안 살아야 하는 단일 인스턴스:
```ini
LaunchService="*res://scripts/services/launch_service.gd"
```

**B. 메인 씬 자식 노드** — 메인 게임 진입 후에만 활성:
```
scenes/main/main_screen.tscn
└─ Services (Node)
    ├─ LaunchService
    ├─ DestinationService
    └─ MissionService
```

**선택 가이드**:
- 부팅 직후부터 항상 필요 + 영구 메모리: A
- 메인 씬에서만 의미 있음 + 씬 전환 시 정리: B

### 2.3 서비스 초기화 패턴

```gdscript
# scripts/services/launch_service.gd
extends Node

func _ready() -> void:
    # 1. 자기 상태 초기화
    _cooldown_remaining = 0.0
    # 2. 다른 시스템 구독 (Autoload 또는 EventBus)
    EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
    SaveSystem.profile_loaded.connect(_on_profile_loaded)

func _on_profile_loaded() -> void:
    # GameState가 deserialize된 후에만 안전하게 읽기 가능
    _restore_state_from_save()
```

`SaveSystem._ready()` 종료 시점에 `profile_loaded`가 emit되므로, **세이브 데이터를 읽어야 하는 서비스는 직접 `GameState` 접근 대신 `profile_loaded`를 기다린다**. (Autoload 부팅 순서로 보장되지만, 메인 씬 자식 노드는 부팅이 끝난 뒤 마운트되므로 `SaveSystem.is_loaded` 플래그도 옵션.)

### 2.4 의존성 해결 패턴

| 패턴 | 사용 예 |
|---|---|
| 직접 `Autoload.method()` 호출 | `var c: int = GameState.credit` |
| 직접 `Autoload.field` 읽기 | `if SaveSystem.is_loaded: ...` |
| `EventBus.signal.connect(callback)` | 다른 시스템의 이벤트에 반응 |
| `get_node("/root/Main/Services/X")` | 메인 씬 자식 서비스 참조 (가능하면 회피) |

**원칙**: 도메인 시스템끼리 직접 참조하기보다는 `EventBus`를 거친다. 동기 응답이 필요한 경우(예: `LaunchService`가 `GameState.credit`을 즉시 차감)에만 직접 호출.

### 2.5 라이프사이클 정리

```gdscript
func _exit_tree() -> void:
    # 명시적 disconnect는 보통 불필요 (노드 free 시 자동 해제).
    # 단, EventBus → 단명 노드 연결은 단명 노드 쪽에서 자동 정리됨.
    pass

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        # SaveSystem이 이미 처리 — 추가 cleanup이 필요할 때만 사용
        pass
```

### 2.6 `class_name` vs Autoload 인스턴스

- **`class_name`**: 재사용 가능한 타입(예: `class_name Generator` 데이터 컨테이너). 인스턴스를 여러 번 생성.
- **Autoload**: 단일 인스턴스가 필요할 때만. 일회성 셋업은 메인 씬 자식 노드.

남발 금지 — Autoload는 전역 상태이므로 테스트가 어려워진다. 4~6개 이내 권장.

## 3. 정적 데이터 (Config)

**없음** — 부팅 인프라.

## 4. 플레이어 영속 데이터

**없음**.

## 5. 런타임 상태

각 Autoload 노드 내부에 분산. 8-3 자체는 stateless.

## 6. 시그널 (EventBus)

이 시스템은 시그널을 정의하지 않음. 대신 `SaveSystem.profile_loaded`(8-1)와 `EventBus`(8-2)가 부팅 후 시스템 간 결합 지점을 제공.

## 7. 의존성

**의존받음**: Godot 엔진 부팅 시퀀스가 `[autoload]` 섹션을 자동 처리. 모든 도메인 시스템이 이 메커니즘 위에서 동작.

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `project.godot` `[autoload]` | 오토로드 등록 (부팅 순서 결정) |
| `scripts/autoload/event_bus.gd` | 전역 시그널 버스 (8-2) |
| `scripts/autoload/game_state.gd` | 메모리 상태 컨테이너 (8-1) |
| `scripts/autoload/save_system.gd` | 직렬화/역직렬화 (8-1) |
| `scripts/autoload/telemetry_service.gd` | 로컬 로깅 (8-5) |
| `scripts/services/*.gd` | 도메인 서비스 (메인 씬 자식 또는 Autoload) |
