# 1-4. Stress / Overload / Abort — 시스템 부하와 발사 중단

> 카테고리: Launch Core
> 정본 문서: `docs/launch_balance_design.md`
> 구현: `scripts/services/stress_service.gd`, `data/stress_config.tres`

## 1. 시스템 개요

**T3(Mars Transfer) 이상 목적지에서만 활성화**되는 리스크 시스템. 발사마다 스트레스 게이지가 쌓이고, `MAX_GAUGE(100)`를 넘으면 `SYSTEM OVERLOAD` 상태 돌입 → 이후 발사 시 `Abort Chance` 확률로 발사가 중단되고 `Repair Cost` Credit 차감.

**책임 경계**
- 게이지 누적/감쇠, Overload 진입, Abort 판정, Repair Cost 차감.
- Idle 시간 기반 자연 감쇠 (`IDLE_THRESHOLD` 후 초당 감소).
- Launch Tech `Stress Bypass` 보정 적용.
- `System Purge` / `Launch Fail-safe` IAP 효과 적용.

**책임 아닌 것**
- 확률 판정(→ 1-2), Credit 잔고 소유(→ 3-1 Currency).

## 2. 코어 로직

### 2.1 티어별 파라미터 (`StressConfig`)

| Tier | stress_per_fail | abort_chance | repair_cost |
|---|---:|---:|---:|
| 1 | 0 | 0% | 0 |
| 2 | 0 | 0% | 0 |
| **3** | **10** | **40%** | **300 C** |
| **4** | **15** | **50%** | **700 C** |
| **5** | **20** | **60%** | **1,500 C** |

공통:
- `max_gauge = 100`
- `idle_threshold = 5.0` 초 (마지막 발사 후 이 시간 지나면 감쇠 시작)
- `decay_per_second = 2.0` (감쇠 속도)
- `LaunchConstants.stress_min_tier = 3` (이 티어 미만에선 전체 스킵)

### 2.2 상태 전이

```
[IDLE]  gauge = 0, is_overload_locked = false
  └─ on_launch_attempt() (모든 발사마다)
       ├─ tier < 3 → { skip = true, aborted = false } 즉시 반환
       ├─ var elapsed: float = Time.get_unix_time_from_system() - last_launch_time
       ├─ if elapsed > idle_threshold:
       │     decay = (elapsed - idle_threshold) * decay_per_second
       │     gauge = max(0.0, gauge - decay)
       │     if gauge < max_gauge: is_overload_locked = false
       └─ stress_increase = stress_per_fail[tier] * (1.0 - stress_bypass_reduction)
          gauge = min(gauge + stress_increase, max_gauge * 2.0)   # 오버슈트 허용 (표시용)
       ↓
[ACCUMULATING]
  └─ gauge >= max_gauge → is_overload_locked = true
       ↓
[OVERLOAD]  is_overload_locked = true
  └─ on_launch_attempt:
       └─ if randf() < abort_chance[tier]:
            aborted = true
            repair_cost = repair_cost_table[tier]
       ↓
[ABORT]
  └─ LaunchService가 aborted = true 수신:
       ├─ StressService.apply_abort(repair_cost)
       │    ├─ GameState.spend_credit(repair_cost)
       │    ├─ self.reset_session()
       │    └─ last_abort_fine = deducted  (Fail-safe 환불용)
       ├─ GameState.current_streak = 0
       ├─ AutoLaunchService.stop_auto_launch()
       └─ EventBus.launch_aborted.emit({ aborted, repair_cost, tier, credit_balance })
       ↓
[IDLE]  (reset_session으로 gauge = 0)
```

### 2.3 중요한 함수 시그니처

```gdscript
func on_launch_attempt() -> Dictionary:
    # {
    #   aborted: bool,
    #   skip: bool,            # tier < stress_min_tier일 때 true
    #   repair_cost: int,
    #   tier: int,
    #   is_system_overload: bool,
    #   stress_level: float,   # 0.0 ~ 1.0 (UI 표시용)
    # }

func apply_abort(repair_cost: int) -> Dictionary  # { credit_balance, deducted }
func reset_session() -> void
func reduce_stress(amount: float) -> void          # System Purge
func get_last_repair_cost() -> int                 # Launch Fail-safe 환불 계산용
func clear_last_repair_cost() -> void              # 환불 후 클리어
func get_stress_status() -> Dictionary             # { is_system_overload, stress_level }
```

### 2.4 Launch Tech 보정 — `Stress Bypass` (stress_bypass_level)

```gdscript
stress_increase = stress_per_fail[tier] * (1.0 - stress_bypass_reduction)
```

`LaunchTechService.get_stress_bypass_bonus()`가 0~1 사이 감쇠율 반환. 상세 값은 `data/launch_tech_config.tres` 참조 (→ 2-4).

### 2.5 리셋 트리거 (`reset_session`)

| 트리거 | 호출자 |
|---|---|
| 목적지 완료 | `LaunchService.launch_rocket` 승리 분기 |
| Abort 발생 | `StressService.apply_abort` 내부 |
| 수동 리셋 / 디버그 | `force_abort` 경로 |
| System Purge IAP | `reduce_stress(30)` (완전 리셋이 아닌 `30` 차감) |

> **주의:** Abort도 `reset_session`을 호출 → gauge 0부터 다시 시작. 따라서 Abort는 "처벌이자 정화 이벤트" 성격.

### 2.6 영속 저장

`stress_session = { gauge, is_overload_locked, last_abort_fine, last_launch_time }`이 `user://savegame.json`에 저장됨. 게임을 종료하고 다시 켜도 게이지가 유지되며, `last_launch_time` 기반 감쇠 계산이 자동 적용된다 (오프라인 진행과 동일한 메커니즘).

## 3. 정적 데이터 (Config)

### `data/stress_config.tres`

```gdscript
# scripts/data/stress_config.gd
class_name StressConfig
extends Resource

@export var max_gauge: float = 100.0
@export var stress_per_fail: Dictionary = { 1: 0, 2: 0, 3: 10, 4: 15, 5: 20 }
@export var idle_threshold: float = 5.0
@export var decay_per_second: float = 2.0
@export var abort_chance: Dictionary = { 1: 0.0, 2: 0.0, 3: 0.40, 4: 0.50, 5: 0.60 }
@export var repair_cost: Dictionary = { 1: 0, 2: 0, 3: 300, 4: 700, 5: 1500 }
@export var abort_popup_duration: float = 5.0
```

### `data/launch_constants.tres`

```gdscript
@export var stress_min_tier: int = 3   # 이 티어 이상에서만 스트레스 활성
```

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

`stress_session` 객체 (하위 필드):

| 필드 | 타입 | 용도 |
|---|---|---|
| `gauge` | `float` | 현재 게이지 (0 ~ 200, 표시는 0 ~ 100) |
| `is_overload_locked` | `bool` | OVERLOAD 진입 여부 |
| `last_abort_fine` | `int` | 직전 Abort에서 실제 차감된 Credit (Launch Fail-safe 환불에 사용) |
| `last_launch_time` | `float` | 마지막 발사 시각 (`Time.get_unix_time_from_system()`, 감쇠 계산용) |

## 5. 런타임 상태

별도 메모리 캐시 없음 — `GameState.stress_session` Dictionary를 직접 읽고 쓴다. `_process()`에서 UI 게이지 실시간 표시가 필요할 경우 클라이언트 측 예측 로직(elapsed 기반 감쇠 계산)을 메인 화면 컨트롤러가 수행.

## 6. 시그널 (EventBus)

| 시그널 | 페이로드 | 용도 |
|---|---|---|
| `EventBus.launch_aborted` | `(payload: Dictionary)` `{ aborted, repair_cost, tier, credit_balance, shield_used?, refunded_cost? }` | Abort 발생 알림 (1-2와 공유) |
| `EventBus.abort_acknowledged` | `()` | UI에서 Abort 팝업 닫기 → 후속 처리 |
| `EventBus.stress_state_changed` | `(is_system_overload: bool, stress_level: float)` | UI 상태 동기화 (게이지 바, OVERLOAD 표시) |

## 7. 의존성

**의존:** `GameState` (게이지 저장/Credit 차감), `LaunchTechService` (StressBypass 보정).

**의존받음:**
- `LaunchService.launch_rocket` — `on_launch_attempt` 선제 호출, `aborted = true` 시 `apply_abort` 호출
- `IAPService` — `System Purge` 구매 시 `reduce_stress(30)` 호출, `Launch Fail-safe` 환불 시 `get_last_repair_cost`/`clear_last_repair_cost`
- `scripts/main/main_screen.gd` — `get_stress_status` 폴링 또는 `stress_state_changed` 구독으로 게이지 표시

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `scripts/services/stress_service.gd` | 게이지/Abort 로직 |
| `data/stress_config.tres` | 티어별 수치 튜닝 |
| `scripts/data/stress_config.gd` | `StressConfig` 리소스 클래스 |
| `data/launch_constants.tres` | `stress_min_tier` |
| `scripts/services/iap_service.gd` | System Purge / Launch Fail-safe 연동 |
| `scenes/main/abort_screen.tscn` | Abort 팝업 UI |
| `scripts/main/abort_screen.gd` | Abort 팝업 컨트롤러 (Shield 재구매 옵션) |
| `scripts/autoload/event_bus.gd` | Stress/Abort 관련 시그널 정의 |

## 9. 설계 주의점

1. **Overload 진입 후에도 발사는 계속 시도 가능**: OVERLOAD는 "락"이 아니라 "Abort 확률 활성" 상태. 사용자는 계속 발사 버튼을 누를 수 있고, 매 시도마다 40~60% 확률로 Abort 발생.
2. **Idle 감쇠는 "다음 발사 시점"에 계산**: 게이지가 실시간으로 감소하는 것이 아니라, 다음 `on_launch_attempt` 진입 시 `now - last_launch_time`으로 역계산. UI 실시간 감소 표시가 필요하면 메인 화면 컨트롤러가 별도 예측 로직 수행.
3. **오버슈트 허용 (`max_gauge * 2`)**: 게이지 값이 100을 넘어 최대 200까지 올라갈 수 있음. UI 게이지 바가 가득 찬 상태에서도 추가 스트레스 누적을 기록하려는 의도. 정규화값(`stress_level`)은 `clamp(gauge / max_gauge, 0.0, 1.0)`.
4. **Abort도 영속 데이터에 영향**: `current_streak = 0`, Credit 차감도 `GameState`에 즉시 반영 → 다음 자동 저장 사이클에 SaveSystem이 기록.
5. **`force_abort`는 디버그/테스트용**: 정상 흐름에선 호출되지 않음.
