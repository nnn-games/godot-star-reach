# 8-2. EventBus — 전역 시그널 메시지 버스

> 카테고리: Shell / Platform
> 구현: `scripts/autoload/event_bus.gd`

## 1. 시스템 개요

싱글 오프라인 게임의 **시스템 간 결합도를 낮추는 메시지 버스**. 모든 도메인 이벤트(발사 결과, 보상 획득, 업그레이드 구매, 미션 갱신 등)는 EventBus 시그널을 통과한다. 노드 간 직접 참조 체인을 깊게 만들지 않고, 발행자(emitter)와 구독자(subscriber)는 시그널 이름으로만 결합.

**책임 경계**
- 도메인 횡단 시그널 정의의 **단일 위치**.
- 발행자/구독자 간 느슨한 결합.

**책임 아닌 것**
- 비즈니스 로직 (각 도메인 시스템이 담당).
- 데이터 저장 (→ 8-1 `SaveSystem`).
- 시스템 내부에서만 쓰이는 시그널 (해당 시스템 노드에서 직접 정의).

## 2. 코어 로직

### 2.1 EventBus 오토로드 골격

```gdscript
# scripts/autoload/event_bus.gd
extends Node

# === 발사 루프 ===
signal launch_started
signal stage_succeeded(stage_index: int, chance: float)
signal stage_failed(stage_index: int, chance: float)
signal launch_completed(destination_id: String)

# === 목적지 / 보상 ===
signal destination_completed(destination_id: String, reward: Dictionary)
signal region_first_visited(region_id: String)
signal codex_updated(entry_id: String)

# === 업그레이드 / 상점 ===
signal upgrade_purchased(category: String, item_id: String)
signal currency_changed(currency_id: String, new_value: int)

# === Stress / Abort ===
signal stress_changed(new_value: float)
signal stress_overload
signal abort_triggered(repair_cost: int)

# === 미션 ===
signal mission_progress_updated(mission_id: String, progress: Dictionary)
signal mission_claimed(mission_id: String, reward: Dictionary)

# === IAP / 텔레메트리 ===
signal iap_purchased(product_id: String, transaction_id: String)
signal telemetry_event(event_name: String, payload: Dictionary)

# === 오프라인 / 세션 ===
signal offline_progress_computed(summary: Dictionary)
signal session_paused
signal session_resumed
```

### 2.2 발행 / 구독 패턴

**발행자** (예: `LaunchService` 노드):
```gdscript
func launch_rocket() -> void:
    EventBus.launch_started.emit()
    for i in range(total_stages):
        var chance: float = _compute_chance(i)
        if randf() < chance:
            EventBus.stage_succeeded.emit(i, chance)
        else:
            EventBus.stage_failed.emit(i, chance)
            return
    EventBus.launch_completed.emit(GameState.current_destination_id)
```

**구독자** (예: `MainScreen` UI):
```gdscript
func _ready() -> void:
    EventBus.stage_succeeded.connect(_on_stage_succeeded)
    EventBus.launch_completed.connect(_on_launch_completed)

func _on_stage_succeeded(stage_index: int, chance: float) -> void:
    _append_log("Stage %d cleared (%.1f%%)" % [stage_index + 1, chance * 100.0])
```

**규칙**:
- 시그널은 EventBus에 정의된 것만 사용. 임의 새 시그널은 우선 도메인 시스템 노드 자체에 정의 → 횡단 필요성이 명확해지면 EventBus로 승격.
- 발행자는 자신이 관여하지 않는 시그널은 emit하지 않음.
- 구독자는 `tree_exiting` 또는 명시적 `disconnect`로 정리. (Godot이 노드 free 시 자동 해제하지만, 오토로드 → 단명 노드 연결은 명시적 해제가 안전.)

### 2.3 시그널 vs 직접 호출

| 케이스 | 권장 |
|---|---|
| 한 시스템이 다른 시스템의 즉시 응답값을 필요로 함 | 직접 메서드 호출 (예: `GameState.credit`) |
| 한 이벤트에 N개 시스템이 반응해야 함 | EventBus 시그널 |
| UI 갱신 트리거 | EventBus 시그널 |
| 도메인 내부 단일 흐름 | 노드 내부 시그널 또는 함수 호출 |

### 2.4 V2: 외부 통신 (선택)

싱글 오프라인이지만 V2에서 다음 두 가지 네트워크 진입점이 필요할 수 있다 — **게임 로직과 분리**되어야 한다:

1. **클라우드 세이브 동기화** (Steam Cloud / Google Play Saved Games / iCloud)
   - `SaveSystem`이 디스크 저장 후 별도 동기화 노드가 업로드. EventBus `profile_saved` → `cloud_sync.upload()`.
2. **텔레메트리 전송** (Firebase Analytics / GameAnalytics 등)
   - `TelemetryService`(8-5)가 EventBus `telemetry_event` 구독 → `HTTPRequest` 노드로 배치 전송.

두 경로 모두 **실패해도 게임 진행이 막히지 않아야 한다** — fire-and-forget + 로컬 큐.

## 3. 정적 데이터 (Config)

**없음** — 시그널 정의 자체가 코드.

## 4. 플레이어 영속 데이터

**없음** — EventBus는 stateless.

## 5. 런타임 상태

**없음** — Godot 시그널 프레임워크가 모든 연결을 관리. EventBus 자체는 데이터 보관하지 않음.

## 6. 시그널 (EventBus)

위 §2.1 전체. 새 시그널 추가는 다음 절차:
1. 도메인 시스템 노드 내부 시그널로 시작.
2. 두 개 이상의 다른 도메인이 구독해야 하면 EventBus로 승격.
3. 페이로드는 `Dictionary` 또는 명시적 타입 파라미터. 거대 객체 전달 금지.

## 7. 의존성

**의존**: 없음 (leaf 오토로드).

**의존받음**: 거의 모든 도메인 시스템 + UI 셸.

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/autoload/event_bus.gd` | 모든 횡단 시그널 정의 |
| `project.godot` `[autoload]` | `EventBus` 오토로드 등록 |
