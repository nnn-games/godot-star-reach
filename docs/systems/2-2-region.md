# 2-2. Region — 지역 단위 첫도달 & 마스터리

> 카테고리: Progression
> 구현: `data/region_config.tres`, `data/region_mastery_config.tres`

## 1. 시스템 개요

100개 목적지를 **11개 지역(`REGION_*`)** 으로 그룹핑하여 "첫도달 기념"과 "반복 탐사 성취"를 분리하는 메타 시스템. 코어 로직은 `DestinationService.complete_destination` 안에 임베드되어 있으며, **별도 서비스 파일이 없는 순수 데이터 + 계산 함수** 구성.

**책임 경계**
- 목적지 → 지역 매핑 제공 (단일 소스 of truth).
- 첫도달 표식 이름 소유 (`badge_name` 필드).
- 마스터리 레벨(M1~M5) 임계값 계산 (지역 크기 기반 동적).
- `DestinationService`, `DiscoveryService`가 읽기 전용으로 참조.

**책임 아닌 것**
- 마스터리 보상 지급 (현재 코드에서 `mastery_level_up`은 이름만 시그널로 전달; 보상 지급 로직은 1.1차 확장으로 분리 예정).

## 2. 코어 로직

### 2.1 지역 정의 (11개)

```gdscript
class_name RegionDef
extends Resource

@export var id: String                          # "REGION_MARS"
@export var display_name: String                # "Mars System"
@export var badge_name: String                  # "Mars Pathfinder"
@export var exploration_difficulty: int         # 1~5, 마스터리 무게 조절용 (현 로직 미사용)
@export var destination_ids: PackedStringArray  # ["D_36", "D_37", ...]
```

**11개 지역 목록**:

| Region ID | 이름 | 난이도 | 목적지 수 | 표식 이름 |
|---|---|---:|---:|---|
| REGION_NEAR_EARTH | Near-Earth Space | 1 | 20 | Near-Earth Pioneer |
| REGION_MOON | Lunar Region | 2 | 15 | Lunar Pathfinder |
| REGION_MARS | Mars System | 3 | 7 | Mars Pathfinder |
| REGION_VENUS | Venus | 3 | 3 | Venus Observer |
| REGION_MERCURY_SOLAR | Mercury & Solar Approach | 3 | 4 | Solar Frontier Scout |
| REGION_ASTEROID_BELT | Asteroid Belt | 3 | 6 | Asteroid Belt Surveyor |
| REGION_JUPITER_SYSTEM | Jupiter System & Moons | 4 | 8 | Jovian Explorer |
| REGION_SATURN_SYSTEM | Saturn System & Moons | 4 | 7 | Saturn Ring Witness |
| REGION_ICE_GIANTS | Ice Giants | 4 | 5 | Ice Giant Surveyor |
| REGION_PLUTO_KUIPER | Pluto & Kuiper Belt | 5 | 8 | Kuiper Trailblazer |
| REGION_INTERSTELLAR | Interstellar Frontier | 5 | 17 | Interstellar Witness |

### 2.2 역방향 매핑 (`get_region_for_destination`)

```gdscript
var _dest_to_region_cache: Dictionary = {}    # lazy 초기화 캐시

func get_region_for_destination(destination_id: String) -> String:
    if _dest_to_region_cache.is_empty():
        for region in regions:
            for d_id in region.destination_ids:
                _dest_to_region_cache[d_id] = region.id
    return _dest_to_region_cache.get(destination_id, "")
```
목적지 → 지역 조회 O(1) 캐시. 첫 호출 시 빌드.

### 2.3 첫도달 판정 (`DestinationService`에서 호출)

```
completion 시점:
  region_id = dest.region_id
  if region_id and not GameState.visited_regions.has(region_id):
    GameState.visited_regions[region_id] = true
    region_first_arrival_badge = RegionConfig.get_region(region_id).badge_name
    EventBus.region_first_arrival.emit(region_id)
```

- `visited_regions`는 `{ region_id: true }` 집합 → 1회성 판정 자동 보장.

### 2.4 마스터리 계산 (`RegionMasteryConfig.compute_mastery`)

**M1~M5 5단계**, 각 지역의 **크기에 따른 동적 임계값**.

```gdscript
const LEVELS: Array[Dictionary] = [
    { key="M1", name="Surveyed" },
    { key="M2", name="Explorer" },
    { key="M3", name="Specialist" },
    { key="M4", name="Veteran" },
    { key="M5", name="Master" },
]
const LEVEL_FRACTIONS: Array[float] = [0.15, 0.35, 0.55, 0.80, 1.00]

func get_thresholds(region_id: String) -> Dictionary:
    var region := get_region(region_id)
    var region_size := region.destination_ids.size()
    var thresholds := {}
    var prev := 0
    for i in LEVELS.size():
        var raw: int = max(1, ceil(LEVEL_FRACTIONS[i] * region_size))
        var threshold: int = min(region_size, max(raw, prev + 1))    # 엄격 증가 보장
        thresholds[LEVELS[i].key] = threshold
        prev = threshold
    return thresholds

func compute_mastery(region_id: String, completed_destinations: Dictionary) -> Dictionary:
    var region := get_region(region_id)
    var total_in_region := region.destination_ids.size()
    var unique := 0
    for d_id in region.destination_ids:
        if completed_destinations.get(d_id, false):
            unique += 1
    var thresholds := get_thresholds(region_id)
    var level := 0
    for i in LEVELS.size():
        if unique >= thresholds[LEVELS[i].key]:
            level = i + 1
        else:
            break
    return { level=level, unique=unique, total=total_in_region }
```

**임계값 예시** (크기별):

| 지역 크기 | M1 (15%) | M2 (35%) | M3 (55%) | M4 (80%) | M5 (100%) |
|---:|---:|---:|---:|---:|---:|
| 20 (NEAR_EARTH) | 3 | 7 | 11 | 16 | 20 |
| 17 (INTERSTELLAR) | 3 | 6 | 10 | 14 | 17 |
| 15 (MOON) | 3 | 6 | 9 | 12 | 15 |
| 7 (MARS) | 2 | 3 | 4 | 6 | 7 |
| 3 (VENUS) | 1 | 2 | 2→3 | 3 | 3 |

> 엄격 증가 보장 (`max(raw, prev + 1)`)으로 작은 지역에서 레벨이 겹치지 않게 조정됨. `VENUS(3개)`는 결국 `{1, 2, 3, 3-capped, 3-capped}` → 실질 3단계.

### 2.5 레벨업 판정 (`DestinationService`에서 호출)

```gdscript
# 현재 완료 포함 상태로 계산
var completed_dests: Dictionary = GameState.completed_destinations
var current = RegionMasteryConfig.compute_mastery(region_id, completed_dests)

# 이번 완료를 뺀 이전 상태로 계산
var prev_completed: Dictionary = completed_dests.duplicate()
prev_completed.erase(dest.id)
var prev = RegionMasteryConfig.compute_mastery(region_id, prev_completed)

if current.level > prev.level:
    var mastery_info := RegionMasteryConfig.get_level_info(current.level)
    completion_data["mastery_level_up"] = mastery_info.name    # e.g. "Specialist"
```

> **"이번 completion이 레벨업을 만들었는가"**를 정확히 판정하기 위해 현재/이전 상태를 각각 계산. 레벨업한 경우에만 `destination_completed` 시그널 페이로드에 `mastery_level_up` 필드 포함.

## 3. 정적 데이터 (Config)

### `data/region_config.tres` (`RegionConfig` Resource)
- `regions` (11개 `RegionDef` 배열)
- `region_order` (표시 순서)
- `get_region(region_id)`, `get_region_for_destination(dest_id)` (lazy cache)

### `data/region_mastery_config.tres` (`RegionMasteryConfig` Resource)
- `LEVELS` (5단계 이름/설명)
- `LEVEL_FRACTIONS = [0.15, 0.35, 0.55, 0.80, 1.0]`
- `get_thresholds(region_id)`, `compute_mastery(region_id, completed_dests)`, `get_level_info(level)`

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

| 필드 | 타입 | 용도 |
|---|---|---|
| `visited_regions` | `Dictionary` | `{ region_id: true }` 첫도달 판정용 |
| `completed_destinations` | `Dictionary` | `{ dest_id: true }` 마스터리 계산용 (→ 2-1과 공유) |

> **마스터리 레벨은 저장하지 않음**. `completed_destinations`에서 매번 계산. "파생 가능한 상태 중복 저장 금지" 원칙.

## 5. 런타임 상태

- `_dest_to_region_cache` (Resource 인스턴스 스코프 캐시, 첫 호출 시 빌드)

## 6. 시그널 (EventBus)

**이 시스템 전용 시그널 없음.** 결과는 다음 시그널 페이로드에 포함:
- `destination_completed.region_first_arrival_badge` (옵션 키)
- `destination_completed.mastery_level_up` (옵션 키)
- `region_first_arrival(region_id: String)` (DestinationService 발행)

## 7. 의존성

**이 모듈 자체의 의존**: 없음 (Config Resource).

**의존받음**:
- `DestinationService.complete_destination` — 첫도달 체크, 마스터리 레벨업 판정
- `DestinationService.get_destination_status` — `targets[].region_id` 응답에 포함
- `DiscoveryService` — 지역별 엔트리 묶음 기준으로 사용 (→ 5-1)

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `data/region_config.tres` | 지역 정의, 표식 이름, 목적지 매핑 |
| `data/region_mastery_config.tres` | 마스터리 레벨/임계값 공식 |
| `scripts/services/destination_service.gd` | 첫도달/레벨업 판정 호출부 |
| `scripts/ui/win_screen.gd` | `region_first_arrival_badge`, `mastery_level_up` 표시 |
| `scripts/ui/region_panel.gd` | 지역별 진행/마스터리 게이지 |

## 9. 알려진 이슈 / 설계 주의점

1. **마스터리 보상 미구현**: `mastery_level_up` 텍스트만 시그널로 전달. 칭호/프레임/코스메틱 지급 로직은 1.1차 확장으로 분리 예정.
2. **재계산 트리거 없음**: 마스터리는 순수 계산 함수이므로 캐시나 invalidation 걱정이 없음. `completed_destinations`가 진실의 원천.
3. **작은 지역(VENUS 3개)은 레벨이 겹침**: M3~M5가 모두 3으로 수렴. 의도이지만 UI에서 M3 달성 시 "3/5레벨 도달"이 부자연스러울 수 있음 → 지역별 레벨 한계 표시 고려.
4. **`exploration_difficulty` 필드 미사용**: 현재 `compute_mastery`는 `exploration_difficulty`를 참조하지 않음. 향후 마스터리 무게 조절 아이디어로만 보유.
5. **지역 추가/제거 시 캐시 무효화**: `_dest_to_region_cache`는 Resource 인스턴스 전역. 핫 리로드 시 Regions 배열을 런타임 수정하면 캐시 초기화 필요.
6. **Discovery와 지역 매핑 관계**: `DiscoveryConfig` 엔트리는 지역보다 더 세분될 수 있음 (예: `BODY_EUROPA`는 `REGION_JUPITER_SYSTEM` 내 1개 목적지만 대표). Region ≠ Discovery Entry. (→ 5-1)
