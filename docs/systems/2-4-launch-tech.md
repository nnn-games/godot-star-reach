# 2-4. Launch Tech — 세션형 5종 업그레이드

> 카테고리: Progression
> 구현: `scripts/services/launch_tech_service.gd`, `data/launch_tech_config.tres`

## 1. 시스템 개요

**XP** 화폐를 소비해 5종 세션형 업그레이드를 구매하는 오토로드 서비스. 목적지 변경/완료 시 **전체 리셋**되는 세션 성장 축 (Facility Upgrades는 영구, → 2-5와 대비).

**책임 경계**
- XP 잔고 관리 (`add_xp`, `spend_xp`).
- 5종 업그레이드의 레벨, 비용, 효과 계산.
- 각 업그레이드의 보너스 값을 타 서비스에 제공 (getter).
- 세션 리셋 (`DestinationService.select_destination`/`complete_destination`에서 트리거).

**책임 아닌 것**
- XP 실제 지급(→ 1-2 `LaunchService` 스테이지 성공 시).
- 확률 적용(→ 1-2), 쿨다운 적용(→ 1-3), 스트레스 적용(→ 1-4).

## 2. 코어 로직

### 2.1 5종 업그레이드 테이블 (`launch_tech_config.tres`)

| tech_id | 이름 | 효과 | max_level | bonus_per_level | cost_base | cost_growth |
|---|---|---|---:|---:|---:|---:|
| `engine_precision` | Engine Precision | +성공률 | 20 | +0.02 (최대 +40%p) | 5 | 1.4 |
| `telemetry` | Telemetry | +XP 획득량 | 10 | +1 (최대 +10 base XP) | 6 | 1.4 |
| `fuel_optimization` | Fuel Optimization | XP 배율 | 10 | +0.05 (최대 1.5x) | 8 | 1.5 |
| `auto_checklist` | Auto-Checklist | -쿨다운 | 10 | +0.05 (최대 -50%) | 7 | 1.4 |
| `stress_bypass` | Stress Bypass | -스트레스 | 10 | +0.03 (레벨당 -3%) | 10 | 1.5 |

**`XP_BASE_GAIN = 5`** (스테이지 1개 성공 시 기본 XP, Telemetry 보너스와 합산).

### 2.2 비용 공식

```gdscript
func get_tech_cost(tech_id: String, current_level: int) -> int:
    var tech: TechDef = techs[tech_id]
    return roundi(tech.cost_base * pow(tech.cost_growth, current_level))
```

> `pow(growth, current_level)`로 지수 증가. `level=0`일 때 `cost_base` 그대로(레벨 1까지 올리는 비용).

### 2.3 구매 흐름 (`purchase_tech`)

```
1. tech = launch_tech_config.techs.get(tech_id)
   └─ null → "Tech not found"
2. session_key = TECH_TO_SESSION_KEY[tech_id]    # "engine_precision_level" etc.
3. current_level = GameState.launch_tech_session[session_key]
4. if current_level >= tech.max_level → "Max level"
5. cost = get_tech_cost(tech_id, current_level)
6. if not spend_xp(cost) → "Not enough XP"
7. GameState.launch_tech_session[session_key] = current_level + 1
8. EventBus.launch_tech_changed.emit(get_tech_status())
9. return { success=true, tech_status=get_tech_status() }
```

### 2.4 보너스 getter (→ 다른 서비스가 호출)

| 메서드 | 공식 | 호출자 | 의미 |
|---|---|---|---|
| `get_engine_precision_bonus()` | `min(level * 0.02, 0.40)` | `LaunchService.get_upgrade_chance_bonus` | 성공률 보정 (가산) |
| `get_telemetry_bonus()` | `level * 1` | `LaunchService` (XP 합산) | 기본 XP에 가산 |
| `get_fuel_optimization_multiplier()` | `1.0 + level * 0.05` | `LaunchService` (XP 합산) | XP 배수 (1.0 ~ 1.5) |
| `get_auto_checklist_reduction()` | `level * 0.05` | `AutoLaunchService.get_launch_cooldown`/`get_auto_launch_rate` | 쿨다운 감소 + auto rate 보정 |
| `get_stress_bypass_bonus()` | `level * 0.03` | `StressService.on_launch_attempt` | 스트레스 증가량 감소 |

### 2.5 XP 합산식 (`LaunchService` 내부, 참조용)

```gdscript
var base_xp: int = LaunchTechConfig.XP_BASE_GAIN + LaunchTechService.get_telemetry_bonus()
var fuel_opt_mult: float = LaunchTechService.get_fuel_optimization_multiplier()
var data_coll_bonus: float = FacilityUpgradeService.get_xp_gain_bonus()

var xp_gain: int = roundi(base_xp * fuel_opt_mult * (1.0 + data_coll_bonus))
LaunchTechService.add_xp(xp_gain)
```

### 2.6 세션 리셋 (`reset_session`)

목적지 변경(`select_destination`) / 자동 진행(`complete_destination` 분기) 시 호출:

```gdscript
# GameState.launch_tech_session 초기화:
launch_tech_session = {
    "xp": 0,
    "engine_precision_level": 0,
    "telemetry_level": 0,
    "fuel_optimization_level": 0,
    "auto_checklist_level": 0,
    "stress_bypass_level": 0,
}
EventBus.launch_tech_session_reset.emit()
```

> **목적지가 바뀌면 지금까지 투자한 세션 업그레이드가 전부 증발**. 이는 의도된 설계 — 세션 성장이 영구 경제를 흐리지 않게 하는 안전장치.

### 2.7 `TECH_TO_SESSION_KEY` 매핑

Tech ID(`engine_precision`)와 저장 키(`engine_precision_level`) 사이의 규칙:
```gdscript
const TECH_TO_SESSION_KEY: Dictionary = {
    "engine_precision":  "engine_precision_level",
    "telemetry":         "telemetry_level",
    "fuel_optimization": "fuel_optimization_level",
    "auto_checklist":    "auto_checklist_level",
    "stress_bypass":     "stress_bypass_level",
}
```
→ 새 tech 추가 시 이 매핑도 함께 확장 필요.

## 3. 정적 데이터 (Config)

### `data/launch_tech_config.tres` (`LaunchTechConfig` Resource)

```gdscript
class_name LaunchTechConfig
extends Resource

const XP_BASE_GAIN: int = 5

@export var techs: Dictionary = {}            # { tech_id: TechDef }
@export var tech_order: PackedStringArray = []

func get_tech_cost(tech_id: String, level: int) -> int
```

`TechDef` Resource: `id`, `display_name`, `effect_description`, `max_level`, `bonus_per_level`, `cost_base`, `cost_growth`.

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

`launch_tech_session` (하위 필드, GameState에서 보관):

| 필드 | 타입 | 용도 |
|---|---|---|
| `xp` | `int` | XP 잔고 |
| `engine_precision_level` | `int` | 성공률 보정 레벨 |
| `telemetry_level` | `int` | 기본 XP 가산 레벨 |
| `fuel_optimization_level` | `int` | XP 배율 레벨 |
| `auto_checklist_level` | `int` | 쿨다운 감소 레벨 |
| `stress_bypass_level` | `int` | 스트레스 감소 레벨 |

> 영속 저장 이유: 재접속 시에도 목적지가 같으면 세션 지속. 목적지 변경 시점에만 리셋.

## 5. 런타임 상태

없음. `GameState.launch_tech_session` 직접 조회/수정.

## 6. 시그널 (EventBus)

| 시그널 | 인자 | 발행자 | 의미 |
|---|---|---|---|
| `xp_changed` | `(new_balance: int)` | `LaunchTechService` | XP 잔고 변동 |
| `launch_tech_changed` | `(tech_status: Dictionary)` | `LaunchTechService` | 5종 레벨/비용/보너스 갱신 |
| `launch_tech_session_reset` | `()` | `LaunchTechService` | 세션 리셋 발생 |

## 7. 의존성

**의존**: `GameState`, `launch_tech_config.tres`.

**의존받음**:
- `LaunchService.get_upgrade_chance_bonus` / `launch_rocket` (XP 합산) — `get_engine_precision_bonus`, `get_telemetry_bonus`, `get_fuel_optimization_multiplier`, `add_xp`
- `AutoLaunchService.get_launch_cooldown`/`get_auto_launch_rate` — `get_auto_checklist_reduction`
- `StressService.on_launch_attempt` — `get_stress_bypass_bonus`
- `DestinationService.select_destination`/`complete_destination` (advanced 분기) — `reset_session`

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `scripts/services/launch_tech_service.gd` | 5종 구매 로직, XP 지갑, 보너스 getter |
| `data/launch_tech_config.tres` | 5종 튜닝 테이블, XP_BASE_GAIN |
| `scripts/ui/launch_tech_panel.gd` | 5종 업그레이드 UI |
| `scripts/services/launch_service.gd` | XP 합산식, 성공률 합산식의 call site |
| `scripts/autoload/event_bus.gd` | XP/Tech 시그널 정의 |

## 9. 알려진 이슈 / 설계 주의점

1. **세션 리셋 이중 실행 가능**: `select_destination` (명시적) + `complete_destination` advanced 분기 (자동). 같은 목적지 반복 클리어 시에는 advanced=false라 리셋 안 됨 → **TechLevel 부족으로 반복 시 세션 누적**이 가능 (의도된 동선).
2. **XP와 Credit은 완전 별개**: XP는 이 시스템 전용이고 Credit(→ 3-1)은 Facility Upgrades(→ 2-5)에서만 사용. 교환 경로 없음.
3. **max_level이 다름**: `engine_precision` 20레벨, 나머지 4개 10레벨. 레벨 20 기준 비용이 커지면 `cost_growth=1.4^19 ≈ 469x`로 상당히 비싸짐.
4. **`auto_checklist`의 중복 효과**: 쿨다운 감소 + auto-launch rate 증가 2곳에서 사용. 수동 발사자에게는 쿨다운만, auto-launch 사용자에게는 양쪽 모두.
5. **`stress_bypass`는 T3+만 체감**: `StressService`가 `tier < STRESS_MIN_TIER(3)`에서는 스트레스 자체를 스킵하므로, T1/T2에서 이 업그레이드를 구매하면 즉시 효과 없음 → UI에서 가리거나 T3+ 진입 시 추천 표시 필요.
6. **`TECH_TO_SESSION_KEY` 이중 네이밍**: 같은 개념에 두 이름(`engine_precision` vs `engine_precision_level`)이 생겼으나 내부 매핑으로 해결.
