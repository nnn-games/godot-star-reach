# 8-1. Player Data — SaveSystem (`user://savegame.json`)

> 카테고리: Shell / Platform
> 구현: `scripts/autoload/save_system.gd`, `scripts/autoload/game_state.gd`

## 1. 시스템 개요

로컬 JSON 영속 저장의 **단일 진실의 원천**. 메모리 상의 게임 상태(`GameState`)와 디스크 파일(`user://savegame.json`)을 동기화한다. 모든 시스템은 `GameState` 필드를 읽고/쓰고, `SaveSystem`이 주기적으로 디스크에 직렬화한다.

**책임 경계**
- `GameState` 메모리 상태의 디스크 직렬화/역직렬화.
- 스키마 버전 필드(`"version": 1`) 관리 + 마이그레이션 훅.
- 자동 저장 트리거 (10초 주기 + 종료 시 + 수동 저장).
- 신규 저장 파일에 대한 기본값 시드.

**책임 아닌 것**
- 게임 로직 (각 도메인 시스템이 담당).
- UI 상태 스냅샷 (8-4 `MainScreen`이 `GameState` 직접 구독).
- 클라우드 동기화 (V2: Steam Cloud / Google Play Games Saved Games).

## 2. 코어 로직

### 2.1 SaveSystem 부팅 시퀀스

```gdscript
# scripts/autoload/save_system.gd
extends Node

const SAVE_PATH: String = "user://savegame.json"
const CURRENT_VERSION: int = 1
const AUTOSAVE_INTERVAL_SEC: float = 10.0

signal profile_loaded
signal profile_saved

var _autosave_accum: float = 0.0

func _ready() -> void:
    _load_or_seed()
    profile_loaded.emit()

func _process(delta: float) -> void:
    _autosave_accum += delta
    if _autosave_accum >= AUTOSAVE_INTERVAL_SEC:
        _autosave_accum = 0.0
        save_now()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        save_now()
```

### 2.2 저장 / 로드 / 마이그레이션

```gdscript
func save_now() -> void:
    var payload: Dictionary = GameState.serialize()
    payload["version"] = CURRENT_VERSION
    payload["saved_at_unix"] = Time.get_unix_time_from_system()
    var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        push_error("SaveSystem: open failed err=%d" % FileAccess.get_open_error())
        return
    f.store_string(JSON.stringify(payload))
    f.close()
    profile_saved.emit()

func _load_or_seed() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        GameState.seed_defaults()
        return
    var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    var raw: String = f.get_as_text()
    f.close()
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("SaveSystem: corrupt save, reseeding")
        GameState.seed_defaults()
        return
    var data: Dictionary = _migrate(parsed)
    GameState.deserialize(data)

func _migrate(data: Dictionary) -> Dictionary:
    var v: int = int(data.get("version", 0))
    # 마이그레이션 훅 — 버전 증가마다 if/elif 추가
    if v < 1:
        # v0 → v1: 신규 필드 시드
        v = 1
    data["version"] = v
    return data
```

### 2.3 GameState — 메모리 상태 + 시리얼라이저

```gdscript
# scripts/autoload/game_state.gd
extends Node

# 코어 진행
var total_wins: int = 0
var credit: int = 0
var tech_level: int = 0
var current_destination_id: String = "D_01"
var highest_completed_tier: int = 0

# 영구 업그레이드
var infrastructure_levels: Dictionary = {
    "engine_tech": 0,
    "data_collection": 0,
    "mission_reward": 0,
    "tech_reputation": 0,
    "ai_navigation": 0,
}

# 발사 세션 (목적지 변경 시 리셋)
var launch_tech_session: Dictionary = {
    "xp": 0,
    "engine_precision_level": 0,
    "telemetry_level": 0,
    "fuel_optimization_level": 0,
    "auto_checklist_level": 0,
    "stress_bypass_level": 0,
}

# 통계
var total_launches: int = 0
var current_streak: int = 0
var session_flips: int = 0
var auto_launch_enabled: bool = false

# Stress 세션 (목적지/Abort 시 리셋)
var risk_session: Dictionary = {
    "gauge": 0.0,
    "is_overload_locked": false,
    "last_abort_fine": 0,
    "last_flip_time": 0,
}

# Weekly Mission
var mission_data: Dictionary = {
    "week_start": 0,
    "progress": { "launches": 0, "successes": 0, "max_stage_pass": 0 },
    "claimed": {},
    "weekly_tech_level": 0,
}

# Region / Codex
var visited_regions: Dictionary = {}        # { region_id: true }
var completed_destinations: Dictionary = {} # { dest_id: true }
var codex_unlocked: Dictionary = {}         # { entry_id: true }

# IAP 멱등성
var processed_transactions: Dictionary = {} # { transaction_id: unix_ts }

# 오프라인 진행
var last_session_unix: int = 0


func seed_defaults() -> void:
    # 기본값은 변수 초기값에 위임. 신규 저장 시 호출.
    last_session_unix = int(Time.get_unix_time_from_system())


func serialize() -> Dictionary:
    return {
        "total_wins": total_wins,
        "credit": credit,
        "tech_level": tech_level,
        "current_destination_id": current_destination_id,
        "highest_completed_tier": highest_completed_tier,
        "infrastructure_levels": infrastructure_levels,
        "launch_tech_session": launch_tech_session,
        "total_launches": total_launches,
        "current_streak": current_streak,
        "session_flips": session_flips,
        "auto_launch_enabled": auto_launch_enabled,
        "risk_session": risk_session,
        "mission_data": mission_data,
        "visited_regions": visited_regions,
        "completed_destinations": completed_destinations,
        "codex_unlocked": codex_unlocked,
        "processed_transactions": processed_transactions,
        "last_session_unix": last_session_unix,
    }


func deserialize(d: Dictionary) -> void:
    total_wins = int(d.get("total_wins", 0))
    credit = int(d.get("credit", 0))
    tech_level = int(d.get("tech_level", 0))
    current_destination_id = String(d.get("current_destination_id", "D_01"))
    highest_completed_tier = int(d.get("highest_completed_tier", 0))
    infrastructure_levels = d.get("infrastructure_levels", infrastructure_levels)
    launch_tech_session = d.get("launch_tech_session", launch_tech_session)
    total_launches = int(d.get("total_launches", 0))
    current_streak = int(d.get("current_streak", 0))
    session_flips = int(d.get("session_flips", 0))
    auto_launch_enabled = bool(d.get("auto_launch_enabled", false))
    risk_session = d.get("risk_session", risk_session)
    mission_data = d.get("mission_data", mission_data)
    visited_regions = d.get("visited_regions", {})
    completed_destinations = d.get("completed_destinations", {})
    codex_unlocked = d.get("codex_unlocked", {})
    processed_transactions = d.get("processed_transactions", {})
    last_session_unix = int(d.get("last_session_unix", Time.get_unix_time_from_system()))
```

### 2.4 오프라인 진행 계산

저장 시 `last_session_unix`를 기록, 로드 시 델타를 계산해 누적 보상을 산출한다. **캡 필수**: 최대 8시간(`28800`초)을 넘기면 잘라낸다.

```gdscript
const MAX_OFFLINE_SEC: int = 28800   # 8h

func compute_offline_progress() -> Dictionary:
    var now: int = int(Time.get_unix_time_from_system())
    var delta_sec: int = clampi(now - GameState.last_session_unix, 0, MAX_OFFLINE_SEC)
    GameState.last_session_unix = now
    # 호출부(예: Idle Income System)가 delta_sec * rate로 보상 산출
    return { "elapsed_sec": delta_sec, "capped": delta_sec >= MAX_OFFLINE_SEC }
```

UI(`MainScreen`)는 `profile_loaded` 직후 `compute_offline_progress()` 결과를 받아 "오프라인 중 획득" 요약 팝업을 표시.

### 2.5 IAP 영수증 트림

`processed_transactions`가 무한 누적되지 않도록 로드 시 200개 초과면 최신 100개만 유지.

```gdscript
const RECEIPT_TRIM_THRESHOLD: int = 200
const RECEIPT_TRIM_KEEP: int = 100

func _trim_receipts() -> void:
    if GameState.processed_transactions.size() <= RECEIPT_TRIM_THRESHOLD:
        return
    var entries: Array = []
    for k in GameState.processed_transactions.keys():
        entries.append([int(GameState.processed_transactions[k]), k])
    entries.sort()  # ts 오름차순
    var trimmed: Dictionary = {}
    var start: int = entries.size() - RECEIPT_TRIM_KEEP
    for i in range(start, entries.size()):
        var pair: Array = entries[i]
        trimmed[pair[1]] = pair[0]
    GameState.processed_transactions = trimmed
```

### 2.6 V2: 클라우드 동기화 (별도 검토)

| 플랫폼 | 메커니즘 | 비고 |
|---|---|---|
| Steam | Steam Cloud (자동 파일 업로드) | `steam_appid.txt` + ACF 등록 |
| Google Play | Saved Games API + Google Play Games Sign-In | GodotGooglePlayGameServices plugin |
| iOS | iCloud Key-Value Store | ~1MB 제한 |

V2 진입 시 `SaveSystem`은 동일한 JSON을 클라우드에도 업로드. 충돌 해결은 `saved_at_unix` 비교 우선.

## 3. 정적 데이터 (Config)

**없음** — 기본값은 `GameState` 변수 초기값. 정적 밸런싱 데이터는 각 도메인 시스템의 `data/*.tres`가 소유.

## 4. 플레이어 영속 데이터

`user://savegame.json` 전체. 위 §2.3 `serialize()`가 출력하는 모든 필드.

## 5. 런타임 상태

| 위치 | 필드 | 용도 |
|---|---|---|
| `SaveSystem` | `_autosave_accum: float` | 10초 주기 누적기 |
| `GameState` | 위 §2.3 모든 필드 | 메모리 상의 현재 상태 |

## 6. 시그널 (EventBus)

`SaveSystem`이 직접 노출하는 시그널:

| 시그널 | 페이로드 | 용도 |
|---|---|---|
| `profile_loaded` | — | 부팅 시 1회. UI/시스템 초기화 트리거 |
| `profile_saved` | — | 매 저장 후. 디버그/QA 인디케이터 |

`EventBus`(8-2)와 별개로 `SaveSystem`에서 직접 발행. 다른 시스템은 두 곳 중 적절한 곳을 구독.

## 7. 의존성

**의존**: 없음 (leaf 오토로드).

**의존받음**: 모든 도메인 시스템(`GameState` 경유) + `MainScreen`/`GlobalHUD`(UI 상태 표시).

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/autoload/save_system.gd` | 직렬화/역직렬화 + 자동 저장 루프 |
| `scripts/autoload/game_state.gd` | 메모리 상태 + 시리얼라이저 |
| `user://savegame.json` | 영속 저장 파일 (런타임 생성) |
| `project.godot` `[autoload]` | `SaveSystem`, `GameState` 등록 |
