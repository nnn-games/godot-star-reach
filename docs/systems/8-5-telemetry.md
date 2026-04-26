# 8-5. Telemetry — 로컬 로깅 + 외부 SDK 어댑터

> 카테고리: Shell / Platform
> 구현: `scripts/autoload/telemetry_service.gd`

## 0. 왜 필요한가

**Telemetry**(원격 측정)는 실행 중인 게임에서 플레이어 행동과 주요 이벤트를 수집·기록하는 파이프라인이다. 싱글 오프라인 게임이라도 분석·밸런싱·BM 최적화의 근간이 된다.

### 필요 이유

1. **데이터 기반 의사결정** — "어느 목적지에서 이탈률이 높은가", "어떤 티어가 너무 어려운가" 같은 질문은 로그 없이는 답할 수 없다. 기획자의 감이 아니라 **실제 플레이어 데이터**로 밸런스를 조정하기 위한 기반.
2. **퍼널 / 리텐션 분석** — 발사 → 목적지 도달 → 미션 수령 → IAP 구매로 이어지는 핵심 루프의 각 단계 전환율을 측정해야 ARPDAU, D1/D7/D30 리텐션 같은 지표를 추적할 수 있다.
3. **버그·어뷰즈 추적** — `region_first_visited`가 같은 사용자에게 두 번 발행되었다면 중복 보상 버그. 로그가 있어야 사후 추적이 가능하다.
4. **운영 가시성** — 출시 후 사용자 환경에서 무슨 일이 일어나는지 알 수 있는 유일한 창구.

### 호출부 보호

각 도메인 시스템(`LaunchService`, `DestinationService` 등)은 `TelemetryService.log_event()`만 호출한다. 백엔드가 `print` → 로컬 파일 → Steam User Stats → Firebase Analytics로 바뀌어도 **호출부는 그대로**. 즉 이 파일은 "분석 인프라 교체용 어댑터" 역할.

### 개인정보 최소화 원칙

- **익명 통계만** 수집. 사용자 식별자는 필요 시 익명 UUID(설치 시 생성, 로컬 저장).
- GDPR / CCPA / COPPA 준수: 출시 시 옵트인 동의 + 옵트아웃 옵션 제공.
- IP, 이메일, 디바이스 시리얼 등 직접 식별자 절대 수집 금지.

## 1. 시스템 개요

`TelemetryService`는 Autoload 노드. 도메인 시스템이 직접 메서드를 호출하거나 `EventBus.telemetry_event` 시그널로 위임한다. 내부적으로:

1. `print()`로 콘솔 출력 (개발용).
2. (옵션) `user://telemetry.log`에 파일 추가 (디버그/QA).
3. (V2) Steam User Stats / Google Play Games Events / Firebase Analytics로 전송.

**책임 경계**
- 이벤트를 구조화된 포맷(`event_name | k=v, ...`)으로 출력.
- 외부 SDK 호출 어댑터.
- 옵트아웃 플래그 체크.

**책임 아닌 것**
- 메트릭 집계 / 대시보드 (외부 서비스가 담당).
- 게임 로직.

## 2. 코어 로직

### 2.1 단일 진입점

```gdscript
# scripts/autoload/telemetry_service.gd
extends Node

const LOG_FILE_PATH: String = "user://telemetry.log"
const ENABLE_FILE_LOG: bool = true   # QA 빌드는 true, 출시 빌드는 false 옵션

var _opted_in: bool = true   # GameState.settings.telemetry_opt_in과 동기화
var _file: FileAccess = null

func _ready() -> void:
    if ENABLE_FILE_LOG:
        _file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE_READ)
    EventBus.telemetry_event.connect(_on_event)

func log_event(event_name: String, payload: Dictionary = {}) -> void:
    if not _opted_in:
        return
    var line: String = _format(event_name, payload)
    print("[Telemetry] %s" % line)
    if _file != null:
        _file.seek_end()
        _file.store_line(line)
    _forward_external(event_name, payload)

func _on_event(event_name: String, payload: Dictionary) -> void:
    log_event(event_name, payload)

func _format(event_name: String, payload: Dictionary) -> String:
    var ts: int = int(Time.get_unix_time_from_system())
    var parts: Array[String] = []
    for k in payload.keys():
        parts.append("%s=%s" % [k, str(payload[k])])
    var detail: String = ""
    if not parts.is_empty():
        detail = " | " + ", ".join(parts)
    return "%d | %s%s" % [ts, event_name, detail]

func set_opt_in(enabled: bool) -> void:
    _opted_in = enabled
    GameState.settings = GameState.get("settings", {})
    GameState.settings["telemetry_opt_in"] = enabled
```

### 2.2 외부 SDK 어댑터 (옵션)

플랫폼별로 분기. 빌드 시점에 활성화된 백엔드만 컴파일/링크 (godotsteam, GodotGooglePlayGameServices 등 GDExtension).

```gdscript
func _forward_external(event_name: String, payload: Dictionary) -> void:
    # Steam User Stats — 누적 stat 또는 achievement
    if Engine.has_singleton("Steam"):
        _forward_steam(event_name, payload)
    # Google Play Games / Firebase Analytics — Android 모바일
    if OS.get_name() == "Android" and Engine.has_singleton("GodotFirebase"):
        _forward_firebase(event_name, payload)
    # iOS Game Center — 제한적, achievements만

func _forward_steam(event_name: String, payload: Dictionary) -> void:
    var Steam: Object = Engine.get_singleton("Steam")
    match event_name:
        "destination_completed":
            Steam.setStatInt("total_destinations", GameState.completed_destinations.size())
            Steam.storeStats()
        "launch_completed":
            Steam.setStatInt("total_launches", GameState.total_launches)
            Steam.storeStats()
        "codex_unlocked":
            var entry: String = payload.get("entry_id", "")
            if entry == "first_region":
                Steam.setAchievement("FIRST_REGION")
                Steam.storeStats()

func _forward_firebase(event_name: String, payload: Dictionary) -> void:
    var Firebase: Object = Engine.get_singleton("GodotFirebase")
    Firebase.Analytics.log_event(event_name, payload)
```

### 2.3 표준 이벤트 카탈로그

| event_name | 발행 시점 | payload |
|---|---|---|
| `launch_attempted` | LAUNCH 버튼 누름 | `{ destination_id, current_chance }` |
| `launch_completed` | 모든 스테이지 통과 | `{ destination_id, stages_cleared, total_stages, xp_gain }` |
| `launch_failed` | 스테이지 실패 | `{ destination_id, failed_at_stage, total_stages }` |
| `destination_completed` | 목적지 첫 정복 | `{ destination_id, tier, region_id, credit_gain, tech_level_gain, total_wins, region_first_arrival }` |
| `region_first_visited` | 지역 첫 방문 | `{ region_id }` |
| `stress_overload` | Stress 게이지 100% | `{ session_flips }` |
| `abort_triggered` | Abort 결정 | `{ repair_cost, session_flips }` |
| `upgrade_purchased` | 업그레이드 구매 | `{ category, item_id, level, cost }` |
| `iap_purchased` | IAP 구매 완료 | `{ product_id, transaction_id, price_local }` |
| `mission_claimed` | 미션 보상 수령 | `{ mission_id, tech_level_gain }` |
| `codex_unlocked` | 코덱스 항목 해금 | `{ entry_id }` |
| `daily_login` | 부팅 시 (날짜 변경 감지) | `{ streak_days }` |
| `offline_progress` | 오프라인 보상 산출 | `{ elapsed_sec, capped }` |
| `session_start` | 부팅 | `{ build_version, platform }` |
| `session_end` | 종료 | `{ play_duration_sec }` |

### 2.4 호출 패턴

도메인 시스템은 두 방식 중 선택:

**A. 직접 호출** (가장 흔함):
```gdscript
TelemetryService.log_event("destination_completed", {
    "destination_id": dest_id,
    "tier": tier,
    "region_id": region_id,
    "credit_gain": credit_gain,
})
```

**B. EventBus 시그널 위임** (이미 다른 시스템도 구독 중인 도메인 이벤트):
```gdscript
EventBus.telemetry_event.emit("upgrade_purchased", {
    "category": "facility",
    "item_id": "engine_tech",
    "level": new_level,
})
```

### 2.5 옵트아웃 / 동의

설정 메뉴에 토글 1개 — `Settings → Privacy → Send anonymous analytics`. 기본값은 지역에 따라:
- EU (GDPR): 옵트인 (기본 false, 사용자가 켜야 전송).
- 그 외: 옵트아웃 (기본 true, 사용자가 끌 수 있음).

```gdscript
# scripts/ui/panels/settings_panel.gd
func _on_telemetry_toggle(enabled: bool) -> void:
    TelemetryService.set_opt_in(enabled)
    SaveSystem.save_now()
```

### 2.6 출시 빌드 vs 개발 빌드

```gdscript
# 빌드 프로파일 분기
const ENABLE_FILE_LOG: bool = OS.is_debug_build()  # 디버그 빌드만 파일 기록
```

출시 빌드는 콘솔 `print` + 외부 SDK만, 디버그 빌드는 추가로 `user://telemetry.log` 보존.

## 3. 정적 데이터 (Config)

**없음** — 이벤트 카탈로그는 §2.3 코드 + 도큐먼트.

## 4. 플레이어 영속 데이터

| 필드 | 위치 | 용도 |
|---|---|---|
| `settings.telemetry_opt_in: bool` | `GameState.settings` | 사용자 동의 상태 |
| `settings.anon_user_uuid: String` | `GameState.settings` | (옵션) 익명 사용자 UUID, 첫 부팅 시 생성 |

## 5. 런타임 상태

| 위치 | 필드 | 용도 |
|---|---|---|
| `TelemetryService` | `_opted_in: bool` | 전송 게이트 |
| `TelemetryService` | `_file: FileAccess` | 로컬 로그 파일 핸들 |

## 6. 시그널 (EventBus)

**구독**: `EventBus.telemetry_event(event_name: String, payload: Dictionary)` — 다른 시스템의 위임 입구.

**발행**: 없음.

## 7. 의존성

**의존**:
- `EventBus` (시그널 구독)
- `GameState` (설정 읽기/쓰기)
- (옵션) `Steam` GDExtension (godotsteam)
- (옵션) `GodotFirebase` GDExtension

**의존받음**: 모든 도메인 시스템이 이벤트 발행 시 사용.

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/autoload/telemetry_service.gd` | 본체 + SDK 어댑터 |
| `user://telemetry.log` | 디버그 빌드의 로컬 로그 파일 (런타임 생성) |
| `scripts/ui/panels/settings_panel.gd` | 옵트아웃 토글 UI |
| `project.godot` `[autoload]` | `TelemetryService` 등록 |
