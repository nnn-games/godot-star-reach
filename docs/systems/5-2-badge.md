# 5-2. Badge / Achievement — 도전과제 시스템 (19종)

> 카테고리: Meta / Collection
> 구현: `scripts/services/badge_service.gd`, `data/badge_config.tres`

## 1. 시스템 개요

19종 뱃지(Win 카운트 5종 + Region 첫도달 14종)를 두 가지 조건(`total_wins` 임계, `region_first_arrival`)으로 자동 부여. 로컬 진행 상태는 `user://savegame.json`에 저장하고, 동일 ID를 **Steam Achievements** / **Google Play Games Achievements** / **Apple Game Center**에 1:1 매핑해 외부 플랫폼에 동기화.

**책임 경계**
- 조건 판정 + 뱃지 획득 처리 (로컬).
- 외부 플랫폼(SteamWorks / GPGS / GameCenter) 도전과제 동시 부여.
- 중복 획득 방지 (영속 플래그 + 세션 캐시).
- 시그널 발행 (`badge_unlocked`).

**책임 아닌 것**
- 조건 데이터 원천(→ `GameState.total_wins`, `GameState.visited_regions`).
- 첫도달 토스트 UI (→ `BadgePanel` / `WinSummary`가 시그널 구독).
- Steam/Play 플랫폼 SDK 초기화 (→ `PlatformService` autoload, GodotSteam / Godot Android Plugin 래핑).

## 2. 코어 로직

### 2.1 뱃지 조건 2종

| condition | 판정 | 임계 방식 |
|---|---|---|
| `total_wins` | `GameState.total_wins >= badge.threshold` | 누적 카운터 |
| `region_first_arrival` | `GameState.visited_regions.has(badge.region_id)` | 집합 존재 |

### 2.2 뱃지 카탈로그 (19종)

**Win 카운트 5종**:

| Key | Name | threshold |
|---|---|---:|
| FIRST_VICTORY | First Victory | 1 |
| TEN_VICTORIES | Ten Victories | 10 |
| CENTURY | Century | 100 |
| THOUSAND_WINS | Thousand Wins | 1,000 |
| TEN_THOUSAND_WINS | Ten Thousand Wins | 10,000 |

**Region 첫도달 14종** (Region과 1:1):

| Key | Name | region_id |
|---|---|---|
| REGION_NEAR_EARTH | Near-Earth Pioneer | REGION_NEAR_EARTH |
| REGION_MOON | Lunar Pathfinder | REGION_MOON |
| REGION_MARS | Mars Pathfinder | REGION_MARS |
| REGION_VENUS | Venus Observer | REGION_VENUS |
| REGION_MERCURY_SOLAR | Solar Frontier Scout | REGION_MERCURY_SOLAR |
| REGION_ASTEROID_BELT | Asteroid Belt Surveyor | REGION_ASTEROID_BELT |
| REGION_JUPITER | Jovian Observer | REGION_JUPITER |
| REGION_JUPITER_MOONS | Jovian Moonrunner | REGION_JUPITER_MOONS |
| REGION_SATURN | Saturn Ring Witness | REGION_SATURN |
| REGION_SATURN_MOONS | Saturn Moon Explorer | REGION_SATURN_MOONS |
| REGION_ICE_GIANTS | Ice Giant Surveyor | REGION_ICE_GIANTS |
| REGION_PLUTO_KUIPER | Kuiper Trailblazer | REGION_PLUTO_KUIPER |
| REGION_HELIOSPHERE_FRONTIER | Frontier Signal Keeper | REGION_HELIOSPHERE_FRONTIER |
| REGION_INTERSTELLAR | Interstellar Witness | REGION_INTERSTELLAR |

### 2.3 부여 흐름 (`check_and_award`)

`BadgeService`는 부팅 시 `EventBus`의 두 시그널을 구독:

```gdscript
EventBus.destination_completed.connect(_on_destination_completed)   # total_wins 증가 케이스
EventBus.region_first_arrival.connect(_on_region_first_arrival)
```

```gdscript
func _on_destination_completed(_destination_id: StringName) -> void:
    var wins: int = GameState.total_wins
    for badge in _config.badges:
        if badge.condition == "total_wins" and wins >= badge.threshold:
            _award(badge)

func _on_region_first_arrival(region_id: StringName) -> void:
    for badge in _config.badges:
        if badge.condition == "region_first_arrival" and badge.region_id == region_id:
            _award(badge)
```

### 2.4 중복 방지 (`_award`)

```gdscript
func _award(badge: BadgeDef) -> bool:
    if GameState.unlocked_badges.has(badge.key):     # 영속 플래그
        return true
    if _session_awarded.has(badge.key):              # 세션 가드 (이중 방어)
        return true

    GameState.unlocked_badges[badge.key] = true
    _session_awarded[badge.key] = true
    SaveSystem.request_save()                        # 다음 틱에 직렬화

    EventBus.badge_unlocked.emit(badge.key, badge.name)

    # 외부 플랫폼 동기화 (실패해도 로컬 플래그는 유지)
    if badge.achievement_id != "":
        PlatformService.set_achievement(badge.achievement_id)
    return true
```

> 외부 플랫폼 SDK는 자체적으로 중복 부여를 무시하므로 재시도 안전. 미부팅 환경(Steam 미실행 등)은 `PlatformService`가 no-op.

### 2.5 `get_status` — UI 조회

```gdscript
func get_status() -> Dictionary:
    var result: Dictionary = {}
    var wins: int = GameState.total_wins
    for badge in _config.badges:
        var achieved: bool = GameState.unlocked_badges.get(badge.key, false)
        var progress: int = 0
        if badge.condition == "total_wins":
            progress = mini(wins, badge.threshold)
        elif badge.condition == "region_first_arrival":
            progress = 1 if GameState.visited_regions.has(badge.region_id) else 0
        result[badge.key] = {
            "name": badge.name,
            "achieved": achieved,
            "progress": progress,
            "target": badge.threshold if badge.condition == "total_wins" else 1,
        }
    return result
```

`BadgePanel`이 표시 시 사용. 외부 SDK 왕복 없이 즉시 반환.

## 3. 정적 데이터 (Config)

### `data/badge_config.tres` (`BadgeConfig` Resource)

```gdscript
class_name BadgeConfig extends Resource

@export var badges: Array[BadgeDef] = []           # 19개
@export var display_order: PackedStringArray = []  # UI 표시 순서
```

### `BadgeDef` Resource

```gdscript
class_name BadgeDef extends Resource

@export var key: StringName                                # "FIRST_VICTORY"
@export var name: String                                   # "First Victory"
@export_multiline var description: String
@export_enum("total_wins", "region_first_arrival") var condition: String
@export var threshold: int = 0                             # total_wins 전용
@export var region_id: StringName                          # region_first_arrival 전용
@export var achievement_id: String = ""                    # Steam/GPGS/GameCenter 공용 ID
@export var icon: Texture2D
```

> `achievement_id`는 빌드 전 SteamWorks 파트너 사이트와 Google Play Console에서 미리 등록한 외부 ID. 동일한 문자열을 두 플랫폼에서 사용하면 매핑 표가 단순.

## 4. 플레이어 영속 데이터 — `user://savegame.json`

```json
{
  "version": 1,
  "unlocked_badges": {
    "FIRST_VICTORY": true,
    "REGION_MARS": true
  }
}
```

소스 파생 필드(`total_wins`, `visited_regions`)는 다른 시스템이 소유 — 본 시스템은 `unlocked_badges`만 책임.

## 5. 런타임 상태

`BadgeService` (autoload):

| 필드 | 용도 |
|---|---|
| `_config: BadgeConfig` | 부팅 시 `data/badge_config.tres` 로드 |
| `_session_awarded: Dictionary[StringName, bool]` | 세션 내 중복 부여 가드 (영속 플래그와 별개의 빠른 체크) |

## 6. 시그널 (EventBus)

```gdscript
# EventBus.gd
signal badge_unlocked(key: StringName, display_name: String)
signal region_first_arrival(region_id: StringName)        # BadgeService가 소비
```

`badge_unlocked`는 UI 토스트, `WinSummary` 화면 등이 구독.

## 7. 의존성

**의존**:
- `GameState` (autoload) — `total_wins`, `visited_regions`, `unlocked_badges`
- `EventBus` (autoload) — `destination_completed`, `region_first_arrival`
- `SaveSystem` (autoload) — `request_save()`
- `PlatformService` (autoload) — `set_achievement(id: String)` (Steam/GPGS/GameCenter 통합 래퍼)

**의존받음**:
- `LaunchService` 또는 `DestinationService` — `EventBus.destination_completed`, `EventBus.region_first_arrival` 발행
- `BadgePanel` UI — `get_status()` + `badge_unlocked` 구독

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/badge_service.gd` | autoload, 부여 로직 + 외부 동기화 |
| `scripts/data/badge_def.gd` | `BadgeDef` Resource 클래스 |
| `scripts/data/badge_config.gd` | `BadgeConfig` Resource 클래스 |
| `data/badge_config.tres` | 19개 뱃지 정의 |
| `scripts/services/platform_service.gd` | Steam/GPGS/GameCenter 통합 래퍼 |
| `scripts/autoload/event_bus.gd` | `badge_unlocked`, `region_first_arrival` |
| `scenes/ui/badge_panel.tscn` | 뱃지 진행 UI |

## 9. 알려진 이슈 / 설계 주의점

1. **`achievement_id` 미등록 시 외부 동기화 skip**: 빌드 전 SteamWorks / Play Console에서 ID를 등록하고 `data/badge_config.tres`의 `achievement_id` 필드를 채워야 외부 표시. 누락 시 로컬 부여만 진행 (경고 로그).
2. **로컬 우선 영속화**: 외부 플랫폼이 미부팅이거나 네트워크 오프라인이어도 로컬 플래그는 즉시 저장. 다음 부팅 시 `_reconcile_external()`(선택 구현)으로 미동기화 분을 다시 푸시 가능.
3. **`total_wins` 뱃지 매번 5개 순회**: 매 승리마다 5개 뱃지 전부 체크 — 이미 받은 뱃지는 `_award` 첫 줄에서 즉시 return, 비용 무시 가능.
4. **Win 임계 스케일 10배**: `1 → 10 → 100 → 1,000 → 10,000`. 초반은 빠르게, 후반은 장기 목표.
5. **Region Mastery 뱃지 별개**: 기획상 Mastery 완성 보상(칭호/프레임)은 별도 시스템(→ 2-2). 본 카탈로그는 첫도달 + Win 카운트만.
6. **Discovery 완성 뱃지 없음**: 12개 도감 엔트리 완성에 대한 뱃지는 현재 카탈로그에 미포함. 추후 추가 시 `condition` enum 확장 필요.
