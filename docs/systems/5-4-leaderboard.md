# 5-4. Best Records — 로컬 베스트 기록

> 카테고리: Meta / Collection
> 구현: `scripts/services/best_records_service.gd`

## 1. 시스템 개요

플레이어 본인의 **로컬 베스트 기록**(개인 신기록) 추적 시스템. 싱글 오프라인 환경이므로 다른 플레이어와의 비교 없이 "내 최고 기록"만 보여준다. 3종 트랙(`total_wins`, `highest_tech_level`, `best_tier`)을 단조증가로 갱신하고 갱신 시점 타임스탬프를 기록.

**책임 경계**
- 트랙별 베스트 값 갱신(높을 때만).
- 갱신 시점 unix 기록 + "신기록 달성" 시그널 발행.
- 본인 기록 조회 API.

**책임 아닌 것**
- 트랙 값 계산(→ `GameState.total_wins`, `GameState.tech_level`, `LaunchService`가 `update()` 호출).
- UI 렌더링(→ `BestRecordsPanel`).
- 외부 플랫폼 리더보드 송신(→ V2에서 `PlatformService`).

## 2. 코어 로직

### 2.1 트랙 종류 (3종)

```gdscript
const TRACKS: Array[StringName] = [
    &"total_wins",
    &"highest_tech_level",
    &"best_tier",
]
```

| Track | Source | 업데이트 시점 |
|---|---|---|
| `total_wins` | `GameState.total_wins` | 목적지 완료 (`LaunchService`) |
| `highest_tech_level` | `GameState.tech_level` | 목적지 완료 + 미션 Claim |
| `best_tier` | 발사 결과의 stage_tier | 발사 종료 (`LaunchService`) |

### 2.2 갱신 (`update`)

```gdscript
func update(track: StringName, value: int) -> bool:
    if not TRACKS.has(track):
        return false
    var rec: Dictionary = GameState.best_records.get(track, {"value": 0, "achieved_at": 0})
    if value > int(rec.value):
        rec.value = value
        rec.achieved_at = int(Time.get_unix_time_from_system())
        GameState.best_records[track] = rec
        SaveSystem.request_save()
        EventBus.best_record_updated.emit(track, value)
        return true
    return false
```

> **단조증가만 기록**: 더 높을 때만 갱신, 감소는 무시. 3종 모두 본질적으로 단조증가 지표.

### 2.3 호출 사이트

```gdscript
# LaunchService에서 (목적지 완료 시):
BestRecordsService.update(&"total_wins", GameState.total_wins)
BestRecordsService.update(&"highest_tech_level", GameState.tech_level)
BestRecordsService.update(&"best_tier", launch_result.tier)

# MissionService에서 (Claim 시):
BestRecordsService.update(&"highest_tech_level", GameState.tech_level)
```

또는 더 깔끔하게 `BestRecordsService`가 `EventBus.destination_completed` / `EventBus.mission_claimed`를 직접 구독해 `GameState`에서 값을 읽는 방식으로도 가능. 호출자 단순화 vs 결합도 트레이드오프.

### 2.4 조회 (`get_all`, `get_record`)

```gdscript
func get_all() -> Dictionary:
    var result: Dictionary = {}
    for t in TRACKS:
        result[t] = GameState.best_records.get(t, {"value": 0, "achieved_at": 0})
    return result

func get_record(track: StringName) -> Dictionary:
    return GameState.best_records.get(track, {"value": 0, "achieved_at": 0})
```

## 3. 정적 데이터 (Config)

**별도 Config 없음**. 트랙 정의는 서비스 내부 상수(`TRACKS`).

> 트랙 추가 시 enum 확장 + UI 라벨 매핑만 필요. 동적 튜닝 대상이 아니라 코드 상수가 적절.

## 4. 플레이어 영속 데이터 — `user://savegame.json`

```json
{
  "version": 1,
  "best_records": {
    "total_wins": { "value": 137, "achieved_at": 1714003200 },
    "highest_tech_level": { "value": 482, "achieved_at": 1714003200 },
    "best_tier": { "value": 6, "achieved_at": 1713998400 }
  }
}
```

## 5. 런타임 상태

`BestRecordsService` (autoload): 별도 캐시 없음. `GameState.best_records`가 단일 소스.

## 6. 시그널 (EventBus)

```gdscript
# EventBus.gd
signal best_record_updated(track: StringName, value: int)
```

`BestRecordsPanel` 또는 토스트 시스템이 "신기록!" 알림용으로 구독.

## 7. 의존성

**의존**:
- `GameState` (autoload) — `best_records: Dictionary`
- `EventBus` (autoload) — `best_record_updated` 발행
- `SaveSystem` (autoload) — `request_save()`

**의존받음**:
- `LaunchService` — 목적지 완료 시 `update()` 3종 호출
- `MissionService.claim()` — TechLevel 변동 시 `update(&"highest_tech_level", ...)`
- `BestRecordsPanel` UI — `get_all()` + `best_record_updated` 구독

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/best_records_service.gd` | autoload, 갱신/조회 |
| `scripts/autoload/event_bus.gd` | `best_record_updated` 시그널 |
| `scripts/autoload/game_state.gd` | `best_records` 필드 + 직렬화 |
| `scenes/ui/best_records_panel.tscn` | 베스트 기록 UI |

## 9. 알려진 이슈 / 설계 주의점

1. **싱글 오프라인 전제**: 다른 플레이어와의 비교 없음. "내 신기록"이라는 개인 동기 부여 메커니즘에 집중.
2. **단조증가 가정**: 세 트랙 모두 자연스럽게 단조증가. 만약 향후 "현재 활성 streak" 같은 감소 가능 지표를 추가한다면 별도 트랙 타입(현재값 + 베스트값) 필요.
3. **트랙 확장 시 마이그레이션 무료**: `GameState.best_records.get(track, default)` 패턴이라 새 트랙은 첫 갱신 시 자동 생성. 저장 마이그레이션 훅 불필요.
4. **갱신 시점 시간 기록**: `achieved_at`은 단순 표시용 ("3일 전 달성" 등 UI 텍스트 생성). 디바이스 로컬 시계 신뢰.
5. **V2 외부 리더보드 연동 옵션**: Steam Leaderboards / Google Play Games Leaderboards / Apple Game Center Leaderboards에 본인 베스트 값을 자동 송신하는 경로를 `PlatformService` 통해 추가 가능. 트랙별 외부 리더보드 ID 매핑(`leaderboard_id: String` 필드)을 `BestRecordsConfig` Resource로 분리하는 형태가 자연스러움. **현재 V1 범위 외**.
6. **`best_tier` 정의 의존**: 발사 결과의 stage_tier 산식이 변경되면 과거 베스트와 의미 비교가 어긋남. Tier 산식 변경은 마이그레이션 결정(리셋 vs 유지) 필요.
