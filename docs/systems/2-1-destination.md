# 2-1. Destination — 100개 목적지 진행 시스템

> 카테고리: Progression
> 구현: `scripts/services/destination_service.gd`, `data/destination_config.tres`

## 1. 시스템 개요

플레이어의 **현재 목적지**를 관리하고, 완료 시 보상을 계산/지급/다음 목적지 자동 진행까지 오케스트레이션하는 허브 오토로드. 100개 목적지(`D_01~D_100`)가 5티어에 걸쳐 단일 선형 경로로 구성됨.

**책임 경계**
- 현재 목적지 조회/선택.
- 목적지 완료 시 보상 계산 (Facility Upgrades 보정).
- 완료 이벤트의 **허브 역할**: Region 첫도달 체크, Mastery 레벨업 계산, Discovery 갱신, 통계 누적.
- TechLevel 기반 자동 진행 (다음 목적지 조건 만족 시 `current_target_id` 자동 변경).

**책임 아닌 것**
- 확률 판정(→ 1-2), 시네마틱 재생(→ 4-1).
- Region 마스터리 데이터 소유(→ 2-2, 계산만 위임).
- Discovery/Codex 로직(→ 5-1, 이벤트 전달만).

## 2. 코어 로직

### 2.1 목적지 스키마 (`DestinationDef` Resource)

```gdscript
class_name DestinationDef
extends Resource

@export var id: String                      # "D_36"
@export var display_name: String            # "Mars Flyby Probe"
@export var tier: int                       # 1~5
@export var region_id: String               # "REGION_MARS"
@export var required_stages: int            # 7 (확률 판정 반복 횟수)
@export var reward_credit: int              # 50
@export var reward_tech_level: int          # 25
@export var required_tech_level: int        # 200 (선택/자동진행 해금 조건)
```

### 2.2 티어-스테이지-밸런스 관계

| Tier | 스테이지 범위 | D_## 범위 | 대표 Region |
|---|---:|---|---|
| 1 | 3~4 | D_01~D_20 | REGION_NEAR_EARTH |
| 2 | 5~6 | D_21~D_35 | REGION_MOON |
| 3 | 7~8 | D_36~D_55 | REGION_MARS/VENUS/MERCURY_SOLAR/ASTEROID_BELT |
| 4 | 9 | D_56~D_75 | REGION_JUPITER/JUPITER_MOONS/SATURN/SATURN_MOONS/ICE_GIANTS |
| 5 | 10 | D_76~D_100 | REGION_PLUTO_KUIPER/HELIOSPHERE_FRONTIER/INTERSTELLAR |

> **티어 = 확률 구간 (→ 1-2)**이면서 동시에 **해금 밴드**. 티어 내부에서는 지역이 세분화되지만 확률 구간 계산에는 영향 없음.

### 2.3 선택 흐름 (`select_destination`)

```
1. dest = destination_config.get_destination(destination_id)
   └─ null → { success=false, message="Destination not found" }
2. player_tech_level = GameState.tech_level
3. if player_tech_level < dest.required_tech_level:
     return { success=false, message="Need %d Tech Level (have %d)" }
4. GameState.current_target_id = destination_id
5. LaunchTechService.reset_session()    # 세션형 업그레이드/XP 초기화
6. StressService.reset_session()        # 스트레스 게이지 리셋
7. EventBus.destination_selected.emit(destination_id)
8. return { success=true, current_destination_id, target={...} }
```

### 2.4 완료 흐름 (`complete_destination`)

`LaunchService`가 `stages_cleared == required_stages`일 때 호출. 이 게임에서 가장 중요한 "승리 이벤트"의 허브.

```
1. dest = get_player_destination()

2. 보상 계산:
   credit_bonus     = FacilityUpgradeService.get_credit_gain_bonus()      # missionReward: max +100%
   tech_level_bonus = FacilityUpgradeService.get_tech_level_gain_bonus()  # techReputation: max +50%
   credit_gain      = round(reward_credit * (1.0 + credit_bonus))
   tech_level_gain  = round(reward_tech_level * (1.0 + tech_level_bonus))

3. 즉시 반영 (GameState):
   GameState.add_credit(credit_gain)
   GameState.add_tech_level(tech_level_gain)
   GameState.total_wins += 1
   GameState.highest_completed_tier = max(highest_completed_tier, dest.tier)
   GameState.completed_destinations[dest.id] = true

4. Region 첫도달 판정:
   if dest.region_id and not GameState.visited_regions.has(region_id):
     GameState.visited_regions[region_id] = true
     region_first_arrival_badge = RegionConfig.get_region(region_id).badge_name
     EventBus.region_first_arrival.emit(region_id)

5. Mastery 레벨업 판정 (현재 완료 포함):
   current_level = RegionMasteryConfig.compute_mastery(region_id, completed_dests)
   prev_level    = RegionMasteryConfig.compute_mastery(region_id, completed_dests - {current})
   if current_level > prev_level:
     mastery_level_up = RegionMasteryConfig.get_level_info(current_level).name

6. 자동 진행 판정:
   next_destination_id = destination_config.get_next_destination(dest.id)
   if next_destination_id:
     next_dest = destination_config.get_destination(next_destination_id)
     if GameState.tech_level >= next_dest.required_tech_level:
       GameState.current_target_id = next_destination_id
       advanced = true
     else:
       # 현재 목적지에 머물러 반복 가능 (TechLevel이 충족될 때까지)

7. 자동 진행 시에만 세션 리셋:
   if advanced:
     LaunchTechService.reset_session()
     StressService.reset_session()

8. Discovery 갱신:
   discovery_change = DiscoveryService.on_destination_complete(dest.id)

9. EventBus.destination_completed.emit(completion_data)
   # UI(WinScreen)는 이 시그널을 구독하여 보상/뱃지/마스터리 표시.
```

### 2.5 자동 진행 규칙의 미묘함

완료 후 `next_dest.required_tech_level`을 충족하지 못하면 `current_target_id`를 **변경하지 않는다** → 현재 목적지를 반복 가능. 이는 설계 의도:
- 플레이어가 TechLevel이 부족할 때 현재 목적지를 반복해 TechLevel을 수급
- 자동 이동만이 아니라 **반복 도전**도 허용되는 구조

### 2.6 정렬/조회 함수 (`destination_config`)

```gdscript
const DESTINATION_ORDER: PackedStringArray = ["D_01", ..., "D_100"]
const DEFAULT_DESTINATION_ID: String = "D_01"

func get_next_destination(current_id: String) -> String
func get_order() -> PackedStringArray
func get_destination(id: String) -> DestinationDef
```

## 3. 정적 데이터 (Config)

### `data/destination_config.tres` (`DestinationConfig` Resource)

100개 `DestinationDef` 배열 + 순서 배열 + `get_next_destination`. 출시 시 100개 모두 가동, 데이터는 확장 가능하게 유지.

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

| 필드 | 타입 | 용도 |
|---|---|---|
| `current_target_id` | `String` | 현재 도전 중 목적지 ID (e.g. `"D_36"`). 기본값 `"D_01"` |
| `highest_completed_tier` | `int` | 정복한 최고 티어 (확률 구간 상한 적용, → 1-2) |
| `total_wins` | `int` | 누적 완료 수 (통계 표시용) |
| `completed_destinations` | `Dictionary` | `{ dest_id: true }` 완료 집합 (Region Mastery 계산용) |
| `visited_regions` | `Dictionary` | `{ region_id: true }` 방문 집합 (첫도달 판정 중복 방지) |

> 저장 스키마는 `"version": 1` 필드를 통해 마이그레이션 훅을 통과한다 (→ SaveSystem).

## 5. 런타임 상태

**없음.** 모든 상태는 `GameState` 오토로드 + `SaveSystem`이 소유. `DestinationService`는 순수 함수형.

## 6. 시그널 (EventBus)

| 시그널 | 인자 | 발행자 | 의미 |
|---|---|---|---|
| `destination_selected` | `(destination_id: String)` | `DestinationService` | 플레이어가 목적지를 선택함 |
| `destination_completed` | `(completion_data: Dictionary)` | `DestinationService` | 목적지 완료 (credit_gain/tech_level_gain/region_first_arrival_badge/mastery_level_up/discovery_change 포함) |
| `region_first_arrival` | `(region_id: String)` | `DestinationService` | 지역 첫 방문 |

## 7. 의존성

**의존**: `GameState`, `LaunchTechService`, `FacilityUpgradeService`, `StressService`, `DiscoveryService`, `destination_config.tres`, `region_config.tres`, `region_mastery_config.tres`

**의존받음**:
- `LaunchService.launch_rocket` — `get_player_destination`, `complete_destination` 호출
- `DestinationPanel` UI — 목적지 선택 / 상태 표시
- `WinScreen` UI — `destination_completed` 시그널 구독

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `scripts/services/destination_service.gd` | 보상 계산, 자동 진행, 허브 오케스트레이션 |
| `data/destination_config.tres` | 100개 목적지 데이터 |
| `data/region_config.tres` | 지역 첫도달 연결 |
| `data/region_mastery_config.tres` | 마스터리 계산 |
| `scripts/ui/destination_panel.gd` | 목적지 선택 UI |
| `scripts/ui/win_screen.gd` | 승리 화면 (보상/뱃지/마스터리 표시) |
| `scripts/autoload/event_bus.gd` | 시그널 정의 |

## 9. 알려진 이슈 / 설계 주의점

1. **자동 진행 실패 시 반복 가능**: TechLevel 부족 → 현재 목적지 반복 → TechLevel 축적 → 자동 진행. 이를 이용한 "파밍 루프"가 설계상 허용됨.
2. **`destination_order`와 `region_id`의 비선형 매핑**: T3 내부에서 `D_52`(MERCURY), `D_53/D_54`(MARS), `D_55`(MERCURY)가 섞여 있음. 순차 진행 순서와 지역 그룹이 **일치하지 않으므로** 지역 마스터리는 순서와 무관하게 해당 지역 고유 목적지만 집계.
3. **Discovery 연동**: `DiscoveryService.on_destination_complete` 호출 → `discovery_change` 반환 → `destination_completed` 시그널에 포함 (→ 5-1).
4. **T6 성간 우주는 데이터 풀에만 존재**: 현재 `LaunchBalanceConfig`는 T1~T5만 정의. T6는 향후 확장 후보로만 보관.
5. **`reset_session` 이중 호출 주의**: `select_destination`과 `complete_destination`(advanced 분기) 모두 LaunchTech/Stress 세션을 리셋. 같은 목적지 반복 클리어 시 advanced=false라 리셋 안 되어 세션 누적이 가능 (의도된 파밍 동선).
