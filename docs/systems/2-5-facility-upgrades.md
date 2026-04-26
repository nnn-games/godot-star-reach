# 2-5. Facility Upgrades — 영구형 5종 업그레이드

> 카테고리: Progression
> 구현: `scripts/services/facility_upgrade_service.gd`, `data/facility_upgrade_config.tres`

## 1. 시스템 개요

**Credit** 화폐를 소비해 5종 영구 업그레이드를 구매하는 오토로드 서비스. `DestinationService`의 Credit/TechLevel 보상 배율, `LaunchService`의 성공률/XP 공식에 지속적으로 영향. Launch Tech(→ 2-4)와 달리 **리셋 없음**.

**책임 경계**
- 5종 영구 업그레이드의 레벨 관리 및 구매 처리.
- 각 업그레이드의 보너스 값 계산 getter 제공.
- Credit 잔고 검증/차감 요청 (`GameState.spend_credit`).

**책임 아닌 것**
- Credit 자체의 소유권(→ 3-1, `GameState`).
- 보상 지급 자체(→ 3-2, `DestinationService`가 보너스 적용해 지급).

## 2. 코어 로직

### 2.1 5종 업그레이드 테이블 (`facility_upgrade_config.tres`)

| upgrade_id | 이름 | 효과 | max_level | bonus_per_level | 최대 보너스 |
|---|---|---|---:|---:|---|
| `engine_tech` | Engine Tech | 기본 성공률 | 10 | +0.01 | +10%p |
| `data_collection` | Data Collection | XP 획득량 | 20 | +0.10 | +200% (3x) |
| `mission_reward` | Mission Reward | Credit 획득량 | 20 | +0.05 | +100% (2x) |
| `tech_reputation` | Tech Reputation | TechLevel 획득량 | 10 | +0.05 | +50% (1.5x) |
| `ai_navigation` | AI Navigation | 오프라인 진행 효율 | 10 | +0.02 | +20% |

> `ai_navigation`은 오프라인 진행 효율 보정으로 **할당 예정** (현재 placeholder, getter/call site 미구현).

### 2.2 비용 공식 (모든 업그레이드 공통)

```gdscript
const COST_BASE: int = 8
const COST_GROWTH: float = 1.20

func get_cost(next_level: int) -> int:
    return roundi(COST_BASE * pow(COST_GROWTH, next_level - 1))
```

**비용 예시**:

| level (next) | Credit 비용 | 누적 (1~N) |
|---:|---:|---:|
| 1 | 8 | 8 |
| 2 | 10 | 18 |
| 3 | 12 | 30 |
| 5 | 17 | 58 |
| 10 | 41 | 207 |
| 20 | 254 | 1,585 |

> 단일 공식이라 모든 업그레이드가 같은 Credit 비용 곡선을 공유. 효과가 큰 업그레이드일수록 유리. (LaunchTechConfig는 tech별 cost_base/cost_growth가 다름.)

### 2.3 구매 흐름 (`purchase_facility_upgrade`)

```
1. upgrade = facility_upgrade_config.upgrades.get(upgrade_id)
   └─ null → "Upgrade not found"
2. current_level = GameState.facility_upgrade_levels.get(upgrade_id, 0)
3. if current_level >= upgrade.max_level → "Max level"
4. next_level = current_level + 1
5. cost = get_cost(next_level)
6. if not GameState.spend_credit(cost) → "Not enough credits"
7. GameState.facility_upgrade_levels[upgrade_id] = next_level
8. EventBus.facility_upgrade_changed.emit(upgrade_id, next_level)
9. return { success=true, facility_upgrade_levels, credit_balance }
```

### 2.4 보너스 getter

| 메서드 | 내부 매핑 | 호출자 | 공식 |
|---|---|---|---|
| `get_engine_tech_bonus()` | `engine_tech` | `LaunchService.get_upgrade_chance_bonus` | `level * 0.01` |
| `get_xp_gain_bonus()` | `data_collection` | `LaunchService.launch_rocket` (XP 합산) | `level * 0.10` |
| `get_credit_gain_bonus()` | `mission_reward` | `DestinationService.complete_destination` | `level * 0.05` |
| `get_tech_level_gain_bonus()` | `tech_reputation` | `DestinationService.complete_destination` | `level * 0.05` |
| *(`ai_navigation` getter 미구현)* | — | — | — |

### 2.5 효과 적용 공식 참조

**성공률 합산** (→ 1-2):
```
chance_bonus = LaunchTech.engine_precision + Facility.engine_tech
             = (0~40%p) + (0~10%p)
```

**XP 합산** (→ 2-4 §2.5):
```
xp_gain = (BASE_GAIN + telemetry) * fuel_opt_mult * (1.0 + data_collection)
                                                    ^^^^^^^^^^^^^^^^^^^^^^
                                                    Facility 보정
```

**보상 배율** (→ 3-2):
```
credit_gain     = reward_credit     * (1.0 + mission_reward)
tech_level_gain = reward_tech_level * (1.0 + tech_reputation)
```

## 3. 정적 데이터 (Config)

### `data/facility_upgrade_config.tres` (`FacilityUpgradeConfig` Resource)

```gdscript
class_name FacilityUpgradeConfig
extends Resource

const COST_BASE: int = 8
const COST_GROWTH: float = 1.20

@export var upgrades: Dictionary = {}             # { upgrade_id: FacilityUpgradeDef }
@export var upgrade_order: PackedStringArray = []

func get_cost(next_level: int) -> int
```

`FacilityUpgradeDef` Resource: `id`, `display_name`, `effect_description`, `max_level`, `bonus_per_level`.

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

`facility_upgrade_levels` (GameState 보관):

```gdscript
facility_upgrade_levels = {
    "engine_tech": 0,
    "data_collection": 0,
    "mission_reward": 0,
    "tech_reputation": 0,
    "ai_navigation": 0,
}
```

## 5. 런타임 상태

없음.

## 6. 시그널 (EventBus)

| 시그널 | 인자 | 발행자 | 의미 |
|---|---|---|---|
| `facility_upgrade_changed` | `(upgrade_id: String, new_level: int)` | `FacilityUpgradeService` | 영구 업그레이드 레벨 변경 (UI/공식 갱신) |
| `credit_changed` | `(new_balance: int)` | `GameState` | Credit 차감 발생 시 동시 발행 |

## 7. 의존성

**의존**: `GameState`, `facility_upgrade_config.tres`.

**의존받음**:
- `LaunchService.get_upgrade_chance_bonus` — `get_engine_tech_bonus`
- `LaunchService.launch_rocket` (XP 합산) — `get_xp_gain_bonus`
- `DestinationService.complete_destination` — `get_credit_gain_bonus`, `get_tech_level_gain_bonus`

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `scripts/services/facility_upgrade_service.gd` | 구매/getter 로직 |
| `data/facility_upgrade_config.tres` | 5종 정의, 단일 비용 공식 |
| `scripts/ui/facility_upgrade_panel.gd` | 영구 업그레이드 UI |
| `scripts/services/destination_service.gd` | 보상 배율 적용 call site |
| `scripts/services/launch_service.gd` | 성공률/XP 합산 call site |
| `scripts/autoload/event_bus.gd` | `facility_upgrade_changed` 시그널 정의 |

## 9. 알려진 이슈 / 설계 주의점

1. **`ai_navigation` 효과 미연결**: Config에는 있고 저장도 되지만 **getter와 call site가 미구현** → 구매해도 효과 0. 오프라인 진행 효율 보정으로 연결 필요.
2. **영구 성장 인플레이션 리스크**: `data_collection` 만렙 시 XP 3배 + `mission_reward` 만렙 시 Credit 2배. 두 축을 모두 올리면 목적지 반복 효율이 크게 상승 → Credit 직접 판매 금지로 경제를 보호하는 이유.
3. **비용 공식 단순화**: 모든 업그레이드가 같은 비용 곡선 → 우선순위는 "효과 / 레벨" 효율에 좌우. 일반적으로 플레이어는 `data_collection` 먼저 투자하는 패턴이 유리.
4. **max_level 전체 투자 총액**:
   - `engine_tech` Lv.10: 207 Credit
   - `data_collection` Lv.20: 1,585 Credit
   - `mission_reward` Lv.20: 1,585 Credit
   - `tech_reputation` Lv.10: 207 Credit
   - `ai_navigation` Lv.10: 207 Credit
   - **전체 3,791 Credit** — T3 목적지 완료 보상 (50~110 Credit) 기준 수십 회 수준.
5. **XP와 Credit의 역할 분리 유지**: Launch Tech(세션, XP) ↔ Facility Upgrades(영구, Credit). 이 축이 흐트러지면 "영구 투자로 세션이 쉬워지는" 밸런스 붕괴 위험.
6. **`engine_tech` 효과는 가산 합성**: `LaunchService` 성공률 합산은 곱이 아닌 가산이므로, `engine_precision`(세션) + `engine_tech`(영구) 두 보정은 단순 합쳐 `+50%p`까지 상승 가능. 기본 성공률 50% 목적지에서는 100%에 근접할 수 있어 캡 처리 필요 (→ 1-2).
