# 6-2. Season Collection — 분기 시즌 코스메틱 컬렉션

> 카테고리: Meta Retention
> 구현: `scripts/services/season_collection_service.gd`

## 1. 시스템 개요

3개월(분기) 단위로 교체되는 **시즌 한정 코스메틱 컬렉션**. "지금 플레이해야 하는 이유"를 분기 단위 FOMO로 제공합니다.

**시즌 라인업 (4개 분기)**

| ID | 테마 | 컨셉 |
|---|---|---|
| `S01_LUNAR` | Lunar Apollo 50주년 | 달 착륙선 발사대, Apollo 패치 트레일 |
| `S02_MARS` | Mars Era | 화성 탐사선 스킨, Olympus Mons 칭호 |
| `S03_VOYAGER` | Voyager Grand Tour | 외행성 그랜드 투어, Golden Record 트레일 |
| `S04_JWST` | James Webb 적외선 | JWST 발사대, 적외선 코스믹 트레일 |

**책임 경계**
- 활성 시즌 판정 (`start_at <= now < end_at`).
- 시즌 진행률(스테이지 클리어/도감 등록 등) → 시즌 포인트 누산.
- 시즌 포인트 임계 도달 시 코스메틱 자동 해제 (영구 인벤토리에 추가).
- 시즌 종료 시점 자동 정산 (미해제 항목은 `permanently_missed`로 마킹).

**책임 아닌 것**
- 코스메틱 적용/장착 (→ `CosmeticInventoryService`, `LoadoutService`).
- Battle Pass / IAP 시즌 패스 (→ 7-1, 7-2). 본 시스템은 **무료 시즌 트랙**만 다룸.
- 스테이지 클리어 판정 (→ `StageService`가 시그널만 송출).

**FOMO 정책**: 시즌 종료 후 미수집 코스메틱은 **영구 미획득**. `permanently_missed` 인벤토리에 ID만 기록되며 향후 재판매/리런 없음.

## 2. 코어 로직

### 2.1 활성 시즌 판정 (`get_active_season`)

```gdscript
func get_active_season() -> Season:
	var now: int = Time.get_unix_time_from_system()
	for season in config.seasons:
		if season.start_at <= now and now < season.end_at:
			return season
	return null  # 시즌 간 공백기 가능
```

### 2.2 시즌 포인트 누산 (`add_season_points`)

```gdscript
func add_season_points(amount: int, source: StringName) -> void:
	var season: Season = get_active_season()
	if season == null:
		return
	var slot: Dictionary = _ensure_season_slot(season.id)
	slot.points += amount
	EventBus.season_points_changed.emit(season.id, slot.points, amount, source)
	_evaluate_unlocks(season, slot)
```

**포인트 소스 (예시)**
| 소스 | 포인트 |
|---|---|
| 일반 스테이지 클리어 (T1~T3) | +5 |
| 보스 스테이지 클리어 | +25 |
| 신규 도감 등록 | +15 |
| 일일 로그인 (Day 7) | +50 |

### 2.3 코스메틱 해제 평가 (`_evaluate_unlocks`)

```gdscript
func _evaluate_unlocks(season: Season, slot: Dictionary) -> void:
	for item in season.cosmetic_items:
		if slot.points >= item.required_points \
		and not slot.unlocked_ids.has(item.id):
			slot.unlocked_ids.append(item.id)
			CosmeticInventoryService.grant(item.id, item.kind)
			EventBus.season_cosmetic_unlocked.emit(season.id, item)
```

### 2.4 시즌 종료 정산 (`_settle_ended_seasons`)

```gdscript
func _settle_ended_seasons() -> void:
	var now: int = Time.get_unix_time_from_system()
	for season in config.seasons:
		if now < season.end_at:
			continue
		var slot: Dictionary = save_data.season_slots.get(season.id, {})
		if slot.is_empty() or slot.get("settled", false):
			continue
		for item in season.cosmetic_items:
			if not slot.unlocked_ids.has(item.id):
				save_data.permanently_missed.append({
					"season_id": season.id,
					"item_id": item.id,
				})
		slot.settled = true
		EventBus.season_ended.emit(season.id, slot.unlocked_ids.size(), \
			season.cosmetic_items.size())
```

호출 시점: 게임 진입 시 1회, 그리고 `_process`에서 1시간 throttle로 재검사 (장기 세션 대응).

### 2.5 오프라인 시즌 전환 처리

저장 시각이 시즌 종료 이전이고 로드 시각이 종료 이후라도 정산은 동일하게 수행됩니다 (시간 비교만 사용 — 활성 세션 필요 없음). 이 점이 본 시스템이 오프라인-친화적인 이유.

## 3. 정적 데이터 (Config)

### `data/season_collection_config.tres` (`SeasonCollectionConfig`)

```gdscript
class_name SeasonCollectionConfig extends Resource

@export var seasons: Array[Season] = []


class_name Season extends Resource
@export var id: StringName = &""              # "S01_LUNAR"
@export var theme: String = ""                # "Lunar Apollo 50주년"
@export var start_at: int = 0                 # Unix
@export var end_at: int = 0                   # Unix (start + ~90d)
@export var cosmetic_items: Array[SeasonItem] = []


class_name SeasonItem extends Resource
@export var id: StringName = &""              # "lunar_trail_apollo"
@export var kind: StringName = &"trail"       # "trail" | "launchpad_skin" | "title"
@export var display_name: String = ""
@export var required_points: int = 0          # 누적 포인트 임계
@export var icon: Texture2D
```

### 기본 시즌 트랙 (각 시즌 6 항목 예시)

```
S01_LUNAR (Lunar Apollo)
   100 pt: launchpad_skin "Saturn V Pad"
   250 pt: trail "Apollo Patch"
   500 pt: title "Moonshot Veteran"
  1000 pt: launchpad_skin "Lunar Module"
  2000 pt: trail "Eagle Has Landed"
  3500 pt: title "Tranquility Base"
```

## 4. 플레이어 영속 데이터 — `user://savegame.json`

```gdscript
"season_collection": {
	"version": 1,
	"season_slots": {
		"S01_LUNAR": {
			"points": 0,
			"unlocked_ids": [],         # ["lunar_trail_apollo", ...]
			"settled": false             # 종료 정산 완료 플래그
		}
	},
	"permanently_missed": [             # 시즌 종료 후 영구 미획득
		{ "season_id": "S01_LUNAR", "item_id": "lunar_module_pad" }
	]
}
```

## 5. 런타임 상태

| 필드 | 용도 |
|---|---|
| `_active_season_cache: Season` | 매 프레임 재계산 회피용 (1초 TTL) |
| `_active_season_cache_at: int` | 캐시 갱신 시각 |
| `_last_settle_check_at: int` | 종료 정산 throttle (1h 간격) |

## 6. 시그널 (EventBus)

```gdscript
# scripts/autoload/event_bus.gd
signal season_started(season_id: StringName)
signal season_points_changed(season_id: StringName, total: int, delta: int, source: StringName)
signal season_cosmetic_unlocked(season_id: StringName, item: SeasonItem)
signal season_ended(season_id: StringName, unlocked_count: int, total_count: int)
```

## 7. 의존성

**의존**:
- `SaveSystem` — `season_collection` 슬라이스 read/write.
- `CosmeticInventoryService.grant` — 해제된 항목 영구 인벤토리 등록.
- `Time.get_unix_time_from_system` — 시즌 활성/종료 판정.

**의존받음**:
- `StageService.stage_cleared` 시그널 → `add_season_points` 호출.
- `CodexService.entry_unlocked` 시그널 → `add_season_points` 호출.
- `MetaBonusService.daily_login_claimed` (Day 7) → `add_season_points(50)`.
- 클라이언트 `SeasonTrackPanel` — 시즌 진척/잔여 시간 표시.

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/season_collection_service.gd` | 본 서비스 (오토로드) |
| `scripts/resources/season_collection_config.gd` | `SeasonCollectionConfig` + `Season` + `SeasonItem` |
| `data/season_collection_config.tres` | 시즌 4개 정의 |
| `scripts/services/cosmetic_inventory_service.gd` | 해제 항목 인벤토리 |
| `scripts/autoload/event_bus.gd` | 본 카테고리 시그널 4종 |
| `scenes/ui/season_track_panel.tscn` | 진척/카운트다운 UI |
| `assets/cosmetics/seasons/` | 시즌별 트레일/스킨/아이콘 리소스 |
