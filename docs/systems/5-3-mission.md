# 5-3. Mission — 일일 미션 + 주간 TechLevel 캡

> 카테고리: Meta / Collection
> 구현: `scripts/services/mission_service.gd`, `data/mission_config.tres`

## 1. 시스템 개요

**일일 단위로 갱신되는 단기 성취 시스템**. 매일 풀에서 3개(구독자는 +1로 4개)를 무작위 추첨, 완료 후 수동 Claim 시 TechLevel 보상. 일일 캡(`DAILY_TECH_LEVEL_CAP = 50`)과 주간 캡(`WEEKLY_TECH_LEVEL_CAP = 500`)으로 미션이 TechLevel의 주 공급원이 되지 않도록 이중 보호.

**책임 경계**
- 일일 경계 계산 (디바이스 로컬 시간 00:00 기준).
- 풀에서 일일 미션 추첨(3 또는 4개).
- 진행도 누적 (이벤트 구독 기반).
- Claim 처리 + TechLevel 지급 + 일일/주간 캡 체크.
- 시그널 발행.

**책임 아닌 것**
- 미션 풀 정의(→ `MissionConfig`).
- 진행 이벤트 발행(→ `LaunchService` / `FacilityService` / `PlaytimeTracker`가 `EventBus`에 발행).
- TechLevel 잔고 소유(→ 3-1).
- 구독 상태 조회(→ `EntitlementService`).

## 2. 코어 로직

### 2.1 미션 풀 (`MissionConfig.pool`)

| mission_id | name | type | target | tech_level_reward |
|---|---|---|---:|---:|
| `DM_LAUNCH_20` | Daily Launch Cadet | launches | 20 | 5 |
| `DM_SUCCESS_3` | Triple Success | successes | 3 | 10 |
| `DM_STAGE_5_STREAK` | Five-Stage Streak | max_stage_pass | 5 | 10 |
| `DM_FACILITY_UPGRADE_1` | Facility Upgrade | facility_upgrade | 1 | 5 |
| `DM_PLAY_10M` | Active Today | play_seconds | 600 | 5 |
| `DM_AUTO_LAUNCH_5M` | Auto-Launch Steady | auto_launch_seconds | 300 | 5 |
| `DM_NEW_DESTINATION` | New Horizon | new_destination | 1 | 15 |

**풀 합계 보상**: 5+10+10+5+5+5+15 = **55 TechLevel**. 일일 캡 50이라 어느 조합이든 캡 안에 들어감(15+10+10+5+5+5 = 50 정확히, 또는 부분 지급으로 잘림).

### 2.2 일일 추첨 (`_roll_today`)

```gdscript
func _roll_today() -> Array[StringName]:
    var rng := RandomNumberGenerator.new()
    var seed_str: String = "%s|%d" % [GameState.profile_id, _today_local_unix()]
    rng.seed = seed_str.hash()                       # 결정적 추첨

    var pool_ids: Array[StringName] = []
    for m in _config.pool:
        pool_ids.append(m.mission_id)

    var pick_count: int = 3
    if EntitlementService.is_subscriber():
        pick_count = 4

    pool_ids.shuffle()                                # rng.shuffle 사용
    return pool_ids.slice(0, mini(pick_count, pool_ids.size()))
```

**결정적 시드**: `(profile_id, 오늘 로컬 자정 unix)`. 같은 날 여러 번 호출해도 동일한 3(또는 4)개 미션이 추첨되어 데이터 손실 시 복구 가능.

### 2.3 일일 / 주간 경계 (`_today_local_unix`, `_week_start_local_unix`)

```gdscript
# 디바이스 로컬 자정 (00:00) 기준
func _today_local_unix() -> int:
    var now: int = int(Time.get_unix_time_from_system())
    var d: Dictionary = Time.get_date_dict_from_unix_time(now)   # 로컬
    var midnight: Dictionary = { "year": d.year, "month": d.month, "day": d.day,
                                  "hour": 0, "minute": 0, "second": 0 }
    return int(Time.get_unix_time_from_datetime_dict(midnight))

# 주간은 일요일 00:00 로컬
func _week_start_local_unix() -> int:
    var today: int = _today_local_unix()
    var d: Dictionary = Time.get_date_dict_from_unix_time(today)
    var dow: int = d.weekday                                     # SUNDAY = 0
    return today - dow * 86400
```

### 2.4 일일/주간 리셋 (`_ensure_today`)

```gdscript
func _ensure_today() -> void:
    var today: int = _today_local_unix()
    if GameState.mission_data.day_start != today:
        GameState.mission_data.day_start = today
        GameState.mission_data.daily_ids = _roll_today()
        GameState.mission_data.progress = {
            "launches": 0, "successes": 0, "max_stage_pass": 0,
            "facility_upgrade": 0, "play_seconds": 0,
            "auto_launch_seconds": 0, "new_destination": 0,
        }
        GameState.mission_data.claimed = {}
        GameState.mission_data.daily_tech_level = 0

    var week: int = _week_start_local_unix()
    if GameState.mission_data.week_start != week:
        GameState.mission_data.week_start = week
        GameState.mission_data.weekly_tech_level = 0

    SaveSystem.request_save()
```

**리셋 시점**: 부팅, 매 진행도 증가, Claim, `get_status` 호출 등 모든 진입점에서 자동 체크. 디바이스 시계 변경/오프라인 복귀에도 즉시 반영.

### 2.5 진행도 누적 (`_on_*`)

`MissionService`는 부팅 시 `EventBus`의 진행 이벤트를 구독:

```gdscript
EventBus.launch_started.connect(func(_dest_id): _increment("launches", 1))
EventBus.destination_completed.connect(func(_dest_id): _increment("successes", 1))
EventBus.stages_cleared.connect(func(stages): _increment_max("max_stage_pass", stages))
EventBus.facility_upgraded.connect(func(_kind): _increment("facility_upgrade", 1))
EventBus.first_destination_reached.connect(func(_dest_id): _increment("new_destination", 1))
EventBus.playtime_tick.connect(func(seconds): _increment("play_seconds", seconds))
EventBus.auto_launch_tick.connect(func(seconds): _increment("auto_launch_seconds", seconds))
```

**타입별 누적 방식**:

| type | 방식 |
|---|---|
| `launches` / `successes` / `facility_upgrade` / `new_destination` / `play_seconds` / `auto_launch_seconds` | 단순 증가 (`+= amount`) |
| `max_stage_pass` | **최댓값 갱신** (`if amount > current: current = amount`) |

`max_stage_pass`는 단일 발사의 스테이지 통과 수 — 한 번에 5스테이지를 깨야 `DM_STAGE_5_STREAK` 완료.

### 2.6 Claim 흐름 (`claim`)

```
1. _ensure_today()
2. mission = config.get_by_id(mission_id)
   └─ null → return Result.error("Mission not found")
3. if mission_id not in mission_data.daily_ids → "Not today's mission"
4. if mission_data.claimed.has(mission_id) → "Already claimed"
5. progress = mission_data.progress[mission.type]
6. if progress < mission.target → "Not completed"

7. gain = mission.tech_level_reward
8. 일일 캡:
   if mission_data.daily_tech_level + gain > DAILY_TECH_LEVEL_CAP:
     gain = DAILY_TECH_LEVEL_CAP - mission_data.daily_tech_level
     if gain <= 0 → "Daily cap reached"
9. 주간 캡:
   if mission_data.weekly_tech_level + gain > WEEKLY_TECH_LEVEL_CAP:
     gain = WEEKLY_TECH_LEVEL_CAP - mission_data.weekly_tech_level
     if gain <= 0 → "Weekly cap reached"

10. mission_data.claimed[mission_id] = true
    mission_data.daily_tech_level += gain
    mission_data.weekly_tech_level += gain

11. GameState.add_tech_level(gain)              # → 3-1
12. SaveSystem.request_save()

13. EventBus.mission_claimed.emit(mission_id, gain)
14. return Result.ok({ gain, total = GameState.tech_level,
                        daily = mission_data.daily_tech_level,
                        weekly = mission_data.weekly_tech_level })
```

> **캡 도달 시 부분 지급**: 일일/주간 캡 중 더 빡빡한 쪽으로 잘림. 정확히 캡에 도달하면 다음 클레임은 `gain <= 0`으로 거부.

### 2.7 상태 조회 (`get_status`)

```gdscript
func get_status() -> Dictionary:
    _ensure_today()
    var data := GameState.mission_data
    var missions: Array = []
    for mid in data.daily_ids:
        var m: MissionDef = _config.get_by_id(mid)
        var p: int = data.progress.get(m.type, 0)
        missions.append({
            "id": m.mission_id, "name": m.name, "description": m.description,
            "target": m.target, "progress": mini(p, m.target),
            "completed": p >= m.target,
            "claimed": data.claimed.get(m.mission_id, false),
            "reward": m.tech_level_reward,
        })
    return {
        "missions": missions,
        "daily_tech_level": data.daily_tech_level,
        "daily_cap": _config.daily_tech_level_cap,
        "weekly_tech_level": data.weekly_tech_level,
        "weekly_cap": _config.weekly_tech_level_cap,
        "next_reset_unix": data.day_start + 86400,
    }
```

## 3. 정적 데이터 (Config)

### `data/mission_config.tres` (`MissionConfig` Resource)

```gdscript
class_name MissionConfig extends Resource

@export var pool: Array[MissionDef] = []          # 7개
@export var daily_tech_level_cap: int = 50
@export var weekly_tech_level_cap: int = 500
@export var base_pick_count: int = 3
@export var subscriber_pick_bonus: int = 1
```

### `MissionDef` Resource

```gdscript
class_name MissionDef extends Resource

@export var mission_id: StringName                # "DM_LAUNCH_20"
@export var name: String
@export_multiline var description: String
@export_enum("launches", "successes", "max_stage_pass", "facility_upgrade",
              "play_seconds", "auto_launch_seconds", "new_destination") var type: String
@export var target: int
@export var tech_level_reward: int
```

## 4. 플레이어 영속 데이터 — `user://savegame.json`

```json
{
  "version": 1,
  "mission_data": {
    "day_start": 1714003200,
    "week_start": 1713744000,
    "daily_ids": ["DM_LAUNCH_20", "DM_SUCCESS_3", "DM_PLAY_10M"],
    "progress": {
      "launches": 12, "successes": 1, "max_stage_pass": 3,
      "facility_upgrade": 0, "play_seconds": 420,
      "auto_launch_seconds": 0, "new_destination": 0
    },
    "claimed": { "DM_LAUNCH_20": false },
    "daily_tech_level": 0,
    "weekly_tech_level": 35
  }
}
```

## 5. 런타임 상태

`MissionService` (autoload):

| 필드 | 용도 |
|---|---|
| `_config: MissionConfig` | 부팅 시 `data/mission_config.tres` 로드 |

상태 캐시 없음 — `GameState.mission_data`가 단일 소스.

## 6. 시그널 (EventBus)

```gdscript
# EventBus.gd — MissionService가 발행
signal mission_progress(mission_id: StringName, current: int, target: int)
signal mission_completed(mission_id: StringName)
signal mission_claimed(mission_id: StringName, tech_level_gain: int)
signal daily_missions_rolled(mission_ids: Array)

# EventBus.gd — MissionService가 구독 (다른 시스템이 발행)
signal launch_started(destination_id: StringName)
signal destination_completed(destination_id: StringName)
signal stages_cleared(stages: int)
signal facility_upgraded(kind: StringName)
signal first_destination_reached(destination_id: StringName)
signal playtime_tick(seconds: int)
signal auto_launch_tick(seconds: int)
```

## 7. 의존성

**의존**:
- `GameState` (autoload) — `mission_data`, `add_tech_level()`, `profile_id`
- `EventBus` (autoload) — 진행 이벤트 구독
- `SaveSystem` (autoload) — `request_save()`
- `EntitlementService` (autoload) — `is_subscriber()` (없으면 항상 false)

**의존받음**:
- `LaunchService` — `launch_started` / `destination_completed` / `stages_cleared` 발행
- `FacilityService` — `facility_upgraded` 발행
- `PlaytimeTracker` (autoload) — `playtime_tick` / `auto_launch_tick` 발행
- `MissionPanel` UI — `get_status()` + 시그널 구독

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/mission_service.gd` | autoload, 일일 추첨/진행/Claim |
| `scripts/data/mission_def.gd` | `MissionDef` Resource 클래스 |
| `scripts/data/mission_config.gd` | `MissionConfig` Resource 클래스 |
| `data/mission_config.tres` | 7개 풀 + 캡 튜닝 |
| `scripts/autoload/event_bus.gd` | mission_* 시그널 |
| `scripts/autoload/playtime_tracker.gd` | `playtime_tick` / `auto_launch_tick` 발행 |
| `scenes/ui/mission_panel.tscn` | 미션 진행 UI |

## 9. 알려진 이슈 / 설계 주의점

1. **결정적 시드의 장점**: `(profile_id, 오늘)` 기반 추첨이라 저장 손실/충돌 시에도 같은 날의 미션 세트를 복구 가능.
2. **이중 캡(일일 50 / 주간 500)**: 일일이 더 빡빡한 게이트. 매일 풀 클리어해도 50 캡에 막힘 → 주간 500은 10일치(미션 외 TechLevel 흐름까지 합산해 사실상 안 닿음).
3. **`max_stage_pass` 특수 로직**: 최댓값 갱신 방식이라 한 일 내 "5스테이지 한번이라도 연속 통과" 달성. 동일 미션이 여러 번 가능한지 — 현재는 `claimed` 플래그로 1회 제한.
4. **구독자 +1**: 구독 시 일일 미션이 4개 추첨. 풀이 7개라 4개 추첨도 안전. 구독 해지 시 다음 일일 리셋부터 3개로 복귀.
5. **디바이스 시계 조작 방어 없음**: 로컬 자정 기준이라 시계를 앞당기면 일일 리셋이 일찍 발생할 수 있음 — 싱글 오프라인 게임이라 정책상 허용. V2에서 NTP 기반 옵션 검토 가능.
6. **이벤트 발행 타이밍**: `LaunchService`가 발사 단위로 `stages_cleared`를 한 번 발행. 스테이지 진행 중 스트리밍 아니라 발사 종료 시 1회.
7. **풀 합계가 캡과 가까움**: 일일 풀 7개 합계 55 vs 캡 50. 거의 모든 미션을 클리어해도 캡에 5만큼 잘림 → 의도된 빡빡함. 풀 확장 시 캡 재조정 필요.
