# 1-2. Multi-Stage Probability — N단계 확률 판정 엔진

> 카테고리: Launch Core
> 정본 문서: `docs/launch_balance_design.md`
> 구현: `scripts/services/launch_service.gd`, `data/launch_balance_config.tres`

## 1. 시스템 개요

발사 요청 시 **`required_stages` 만큼 순차 확률 판정**을 수행하는 이 게임의 코어 엔진. 각 스테이지는 독립 확률 판정이며 하나라도 실패하면 루프 중단. 모든 스테이지 통과 시 목적지 완료 이벤트 발행.

**책임 경계**
- `randf()` 기반 스테이지 판정.
- 구간별 `base_chance` / `max_chance` 구조 적용 (이미 정복한 구간은 자동 최고 확률).
- 업그레이드 보너스 합산 (Launch Tech + Facility Upgrades + IAP buff).
- 스테이지별 XP 지급, 최종 목적지 클리어 시 완료 흐름 트리거.

**책임 아닌 것**
- 컨텍스트 검증(→ 1-1), Stress 판정(→ 1-4), Credit/TechLevel 보상 계산(→ 2-1 Destination).
- XP 배율 계산(→ 2-4 LaunchTech, 2-5 Facility, 7 Monetization).

## 2. 코어 로직

### 2.1 확률 공식

```gdscript
# 스테이지 i의 확률 (LaunchService._get_stage_chance_from_state)
var segment: TierSegment = LaunchBalanceConfig.get_segment_for_stage(i)

if segment.tier <= GameState.highest_completed_tier:
    stage_chance = segment.max_chance        # 이미 정복한 구간 = 상한 고정
else:
    stage_chance = min(segment.base_chance + upgrade_bonus, segment.max_chance)
```

**구간 테이블** (`LaunchBalanceConfig.segments`, 5 TierSegment):

| Tier | 구간명 | 스테이지 | base_chance | max_chance |
|---|---|---|---:|---:|
| 1 | Atmosphere | 1~4 | 50% | 85% |
| 2 | Cislunar | 5~6 | 44% | 78% |
| 3 | Mars Transfer | 7~8 | 36% | 72% |
| 4 | Outer Solar | 9 | 28% | 66% |
| 5 | Interstellar | 10 | 22% | 60% |

### 2.2 업그레이드 보너스 합산 (`get_upgrade_chance_bonus`)

```gdscript
var upgrade_bonus: float = (
    LaunchTechService.get_engine_precision_bonus()       # 세션, 최대 +40%p
    + FacilityUpgradeService.get_engine_tech_bonus()     # 영구, 최대 +10%p
    + IAPService.get_guidance_module_bonus()             # IAP 영구, +5%p
    + IAPService.get_trajectory_surge_bonus()            # IAP 시간제, +3%p
)
```

> 4개 합산 최대치 `+58%p` (`docs/launch_balance_design.md` 표 기준).

### 2.3 발사 전체 플로우 (`launch_rocket`)

```
1. 컨텍스트 검증
   └─ LaunchSessionService.is_session_active()
      └─ false → { rejected = true } 즉시 반환

2. Stress 판정 (tier >= 3일 때만)
   └─ StressService.on_launch_attempt()
      └─ aborted = true → StressService.apply_abort() (Credit 차감)
                       → EventBus.launch_aborted.emit(repair_cost, tier, ...)
                       → AutoLaunchService.stop_auto_launch()
                       → 즉시 반환 (stages_cleared = 0)

3. 목적지 정보 조회
   └─ context = LaunchSessionService.get_current_context()
   └─ required_stages = context.required_stages
   └─ chances[1..required_stages] = get_launch_stage_chances(required_stages)
                                                  (판정 전에 미리 계산)

4. 발사 시작 시그널
   └─ EventBus.launch_started.emit({
        total_stages, stage_duration (= 2.0s),
        destination_id, destination_tier,
        sky_route_key, shared_duration, shared_visible_height
      })

5. 스테이지 루프 (for stage in range(1, required_stages + 1))
   ├─ await get_tree().create_timer(STAGE_DURATION = 2.0).timeout
   ├─ stage_passed = (randf() < chances[stage])
   ├─ if passed:
   │   ├─ stages_cleared += 1
   │   ├─ xp_gain = BASE_GAIN + telemetry_bonus            (LaunchTech)
   │   │          * fuel_optimization_multiplier            (LaunchTech)
   │   │          * (1 + data_collection_bonus)             (Facility)
   │   │          * IAPService.get_xp_multiplier()          (VIP, Boost 등)
   │   ├─ LaunchTechService.add_xp(xp_gain)
   │   └─ EventBus.launch_stage_result.emit(stage_passed = true, current_stage, ...)
   └─ if failed:
       ├─ EventBus.launch_stage_result.emit(stage_passed = false, is_system_overload, stress_level)
       └─ break  (스테이지 루프 즉시 중단)

6. 상태 갱신
   ├─ GameState.current_streak = stages_cleared
   ├─ AutoLaunchService.increment_launches(1)  # total_launches += 1
   └─ MissionService.increment_progress("launches", 1)
       MissionService.increment_progress("max_stage_pass", stages_cleared)

7. 완료 분기
   ├─ if stages_cleared >= required_stages:
   │   ├─ AutoLaunchService.stop_auto_launch()
   │   ├─ MissionService.increment_progress("successes", 1)
   │   ├─ var completion_data := DestinationService.complete_destination()
   │   ├─ EventBus.launch_won.emit(total_launches, credit_gain, tech_level_gain,
   │   │                           destination_id, next_destination_id,
   │   │                           mastery_level_up, discovery_change_type, ...)
   │   ├─ GameState.current_streak = 0
   │   └─ StressService.reset_session()
   └─ else:
       └─ GameState.current_streak = 0

8. TelemetryService.log_event("launch", { result, stages_cleared, total_stages, xp_gain })
9. return result  # 호출자(수동 발사 또는 Auto Launch)에 결과 dict 반환
```

### 2.4 스테이지 시간

- `STAGE_DURATION = 2.0s` (`LaunchConstants`).
- 총 발사 시간 = `required_stages * 2.0s` → T1 `6~8s`, T5 `20s`.
- `shared_duration = LaunchVisualConfig.get_shared_duration(required_stages, stage_duration)` → 하늘 전환 참조 (→ 4-2).

### 2.5 쿨다운

수동 발사 쿨다운은 `AutoLaunchService.get_launch_cooldown()`이 소유 (→ 1-3). `launch_rocket`은 호출 직전 메인 화면 컨트롤러가 쿨다운 게이트를 검사하므로 본 함수 내부에는 쿨다운 검사가 없다. Auto Launch 루프는 쿨다운을 우회하고 `rate`로만 간격 제어.

### 2.6 `get_effective_chance` — UI 표기용

대기 상태에서 UI가 "현재 성공률"을 표시할 때 호출:
- 현재 목적지에서 **아직 미정복인 첫 구간**의 성공률을 반환.
- 이유: 상위 목적지에서 `85%`만 보여주면 실제 난이도가 가려지기 때문. 플레이어가 "진짜 싸우는 구간"의 수치를 우선 표시.

## 3. 정적 데이터 (Config)

### `data/launch_balance_config.tres`

```gdscript
# scripts/data/launch_balance_config.gd
class_name LaunchBalanceConfig
extends Resource

@export var segments: Array[TierSegment]

func get_segment_for_stage(stage_index: int) -> TierSegment: ...
```

```gdscript
# scripts/data/tier_segment.gd
class_name TierSegment
extends Resource

@export var tier: int
@export var stage_start: int
@export var stage_end: int
@export var base_chance: float
@export var max_chance: float
```

### `data/launch_constants.tres`

```gdscript
@export var base_cooldown: float = 3.0       # 수동 발사 간 쿨다운 (초)
@export var min_cooldown: float = 0.5        # 쿨다운 하한
@export var stage_duration: float = 2.0      # 스테이지 1개 소요 시간
@export var stress_min_tier: int = 3         # Stress 적용 시작 티어
```

### `data/launch_tech_config.tres`

`xp_base_gain` 및 각 세션 업그레이드의 성공률 기여도 정의 (→ 2-4 Launch Tech).

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

| 필드 | 타입 | 용도 |
|---|---|---|
| `highest_completed_tier` | `int` | 정복한 최고 티어 → 구간 상한 자동 적용 |
| `current_streak` | `int` | 현재 스테이지 연속 성공 수 (발사 실패/완료 시 0으로 리셋) |
| `total_launches` | `int` | 누적 발사 (Auto Launch 자연 해금, 통계용) |
| `session_flips` | `int` | 세션 내 발사 수 (목적지 변경 시 리셋) |

> `current_streak`는 단일 발사 내에서 stage 루프 도중 `GameState`에서만 증가하다가, 발사 종료 시 최종값이 다음 자동 저장 사이클에서 SaveSystem에 기록.

## 5. 런타임 상태

| 필드 | 위치 | 용도 |
|---|---|---|
| `_last_launch_time` | `LaunchService` | 쿨다운 추적 (`Time.get_ticks_msec()`) |
| `_active_launch_running` | `LaunchService` | 동시 발사 진입 방지 가드 (await 도중 재진입 차단) |

## 6. 시그널 (EventBus)

| 시그널 | 페이로드 | 용도 |
|---|---|---|
| `EventBus.launch_requested` | `()` | 메인 화면 LAUNCH 버튼 → 서비스 호출 (UI → 서비스) |
| `EventBus.launch_started` | `(payload: Dictionary)` | 발사 시작 (시네마틱 트리거) |
| `EventBus.launch_stage_result` | `(stage_passed: bool, current_stage: int, ...)` | 스테이지 단위 결과 |
| `EventBus.launch_won` | `(payload: Dictionary)` | 목적지 완료 (모든 보상/도감 변화 포함) |
| `EventBus.launch_aborted` | `(repair_cost: int, tier: int, ...)` | Stress Abort 발생 (1-4와 공유) |
| `EventBus.t5_completion_announced` | `(destination_id: StringName)` | T5 완주 알림 (이벤트 로그/도전 과제) |

## 7. 의존성

**의존:**
- `GameState`, `AutoLaunchService`, `TelemetryService`, `IAPService`, `MissionService`, `LaunchTechService`, `FacilityUpgradeService`, `DestinationService`, `StressService`, `LaunchSessionService`

**의존받음:**
- `AutoLaunchService._start_auto_launch_loop` — `LaunchService.launch_rocket`을 직접 호출
- `scenes/main/main_screen.gd` — 수동 발사 진입점

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `scripts/services/launch_service.gd` | 판정 로직, 스테이지 루프, XP 합산 |
| `data/launch_balance_config.tres` | 구간별 확률 튜닝 |
| `scripts/data/launch_balance_config.gd` | `LaunchBalanceConfig` 리소스 클래스 |
| `scripts/data/tier_segment.gd` | `TierSegment` 리소스 클래스 |
| `data/launch_constants.tres` | 쿨다운, 스테이지 소요 시간, Stress 시작 티어 |
| `scripts/main/main_screen.gd` | 수동 발사 요청 처리, 쿨다운 게이트 |
| `scripts/autoload/event_bus.gd` | 발사 관련 시그널 정의 |
