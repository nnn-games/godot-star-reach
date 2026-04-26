# 7-3. Daily Reward + Daily Mission — V1 정식 구현

> 카테고리: Monetization / Retention
> 정본 문서: `docs/bm.md` §9 (Daily Reward + Daily Mission)
> 구현: `scripts/services/daily_reward_service.gd`, `scripts/services/daily_mission_service.gd`, `scripts/services/ad_service.gd`, `data/daily_reward_config.tres`, `data/daily_mission_config.tres`, `data/ad_reward_config.tres`

## 1. 시스템 개요

일일 복귀 + 세션 시간 연장을 위한 V1 정식 시스템. 양 플랫폼(Mobile + Steam)에서 동작한다. Steam 트랙도 일일 복귀 보상은 의미가 있어 모두 활성화한다 (Rewarded Ads는 Mobile 한정).

**3종 하위 시스템**:
- **Daily Reward** — 7일 스트릭 접속 보상 (Credit + 시간제 Boost + 칭호)
- **Daily Mission** — 일일 미션 3개 (구독자 +1 = 4개), 일일 TechLevel 캡 50
- **Rewarded Ads** — Mobile 한정, 4개 삽입 지점 (Abort/Win/Daily/Auto-Fuel)

**책임 경계**
- Daily Reward 스트릭 누적, 7일 순환, 48시간 미접속 리셋.
- Daily Mission 일일 풀에서 3개 결정적 랜덤 선택, 진행 추적, 일일 TechLevel 캡 50 enforce.
- Rewarded Ads 일일 한도 카운터, 광고 SDK 호출, 보상 지급.
- 디바이스 로컬 자정 리셋 (각 시스템 독립 추적).

**책임 아닌 것**
- 칭호 시스템 자체 (`PlayerData.titles` 관리는 별도 `TitleService`).
- 광고 SDK 초기화 (`AdMob` 플러그인이 담당, `AdService`는 래퍼).
- 시간제 Boost 효과 적용 (`IAPService` 위임 — 7-2의 `boost_2x` 슬롯 재사용).

## 2. 코어 로직

### 2.1 Daily Reward — 7일 에스컬레이션

**보상 테이블** (`docs/bm.md` §9.1):

| Day | 보상 | 비고 |
|---|---|---|
| 1 | 5 Credit | 기본 |
| 2 | 8 Credit | |
| 3 | 10 Credit + 15분 2x Boost | 세션 연장 유도 |
| 4 | 12 Credit | |
| 5 | 15 Credit | |
| 6 | 18 Credit + 15분 2x Boost | |
| 7 | 25 Credit + 30분 2x Boost + 칭호 `Weekly Explorer` | 주간 정점 |

**규칙**:
- 보상 주기: 24시간 (디바이스 로컬 자정 기준 — `Time.get_date_string_from_system()` 비교)
- 스트릭 리셋: 48시간 미접속 시 Day 1로 복귀
- 수령 조건: 진입 후 자동 또는 모달 1회 클릭
- **첫 접속 5분 이내는 모달 억제** (온보딩 방해 방지)
- T1 미완료 (`highest_completed_tier < 1`) 유저에게 표시 X

**핵심 흐름**:

```gdscript
# scripts/services/daily_reward_service.gd
func can_claim() -> bool:
    var today: String = Time.get_date_string_from_system()
    return GameState.daily_reward.last_claim_date != today

func claim() -> Dictionary:
    var today: String = Time.get_date_string_from_system()
    var last_claim: String = GameState.daily_reward.last_claim_date
    var hours_since: float = _hours_between(last_claim, today)

    var new_streak: int
    if last_claim == "":
        new_streak = 1                          # 최초 수령
    elif hours_since > 48.0:
        new_streak = 1                          # 48h 미접속 → 리셋
    else:
        new_streak = (GameState.daily_reward.streak % 7) + 1

    var reward: Dictionary = DailyRewardConfig.get_reward(new_streak)
    EconomyService.add_credit(reward["credit"])
    if reward.has("boost_minutes"):
        IAPService.activate_boost("boost_2x", reward["boost_minutes"] * 60)
    if reward.has("title"):
        TitleService.grant(reward["title"])

    GameState.daily_reward.streak = new_streak
    GameState.daily_reward.last_claim_date = today
    SaveSystem.save()
    EventBus.daily_reward_claimed.emit(new_streak, reward)
    return reward
```

> Daily Reward의 Boost 활성화는 `IAPService.activate_boost("boost_2x", ...)` 무료 진입점을 사용한다 (영수증 우회). 이 메서드는 7-2의 `boost_2x_expire_at` 슬롯에 시간을 더한다.

### 2.2 Daily Reward 광고 보상 2배 (Mobile 한정)

`DailyRewardModal` 내 "광고 시청 → Credit 2배" 버튼:
- 일일 한도 1회 (`ad_reward_state.counts.daily`)
- VIP 보유 시 버튼 자체 미표시 (광고 제거 효과)
- Steam에서는 항상 미표시
- 부스트는 2배 대상 외 (Credit만)

### 2.3 Daily Mission — 3개 일일 과제

**미션 풀** (`docs/bm.md` §9.2):

| 미션 ID | 조건 | 보상 |
|---|---|---|
| `DM_LAUNCH_20` | 20회 발사 | 10 TechLevel |
| `DM_SUCCESS_3` | 3회 목적지 완료 | 15 TechLevel |
| `DM_STAGE_5_STREAK` | 5연속 단계 클리어 | 10 TechLevel |
| `DM_FACILITY_UPGRADE_1` | Facility 1회 업그레이드 | 10 TechLevel |
| `DM_PLAY_10M` | 10분 이상 플레이 | 15 TechLevel |
| `DM_AUTO_LAUNCH_5M` | Auto Launch 5분 사용 | 10 TechLevel |
| `DM_NEW_DESTINATION` | 신규 목적지 1개 도달 | 20 TechLevel |

**규칙**:
- 매일 디바이스 로컬 00:00 리셋
- 위 풀에서 **3개 랜덤 선택** (중복 없음, 결정적 시드)
- 구독(`Orbital Operations Pass`) 활성 시 +1 슬롯 (총 4개)
- **일일 TechLevel 캡 = 50** (주간 캡 500과 별도)
- Weekly와 **독립** (같은 행위가 양쪽에 동시 계상 가능 — `MissionService`에서 별도 카운터 증가)

**일일 선택 (결정적 시드)**:

```gdscript
func roll_today() -> Array:
    var today: String = Time.get_date_string_from_system()
    if GameState.daily_mission.date == today:
        return GameState.daily_mission.missions   # 이미 오늘 굴림

    var seed_hash: int = ("%s::%d" % [today, GameState.player_seed]).hash()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_hash

    var pool: Array = DailyMissionConfig.pool.duplicate()
    pool.shuffle()                                # rng 상태 사용
    var slot_count: int = 4 if SubscriptionService.is_active() else 3
    var picked: Array = pool.slice(0, slot_count)

    GameState.daily_mission = {
        "date": today,
        "missions": picked.map(_to_mission_state),
        "daily_tech_level_earned": 0,
    }
    SaveSystem.save()
    return GameState.daily_mission.missions
```

**진행 갱신 (이벤트 구독)**:

```gdscript
func _ready() -> void:
    EventBus.rocket_launched.connect(_on_rocket_launched)
    EventBus.destination_completed.connect(_on_destination_completed)
    EventBus.facility_upgraded.connect(_on_facility_upgraded)
    # ...

func _on_rocket_launched() -> void:
    _increment_progress("DM_LAUNCH_20", 1)

func _increment_progress(mission_id: String, amount: int) -> void:
    for m in GameState.daily_mission.missions:
        if m.id == mission_id and not m.claimed:
            m.progress = min(m.progress + amount, _required(mission_id))
            EventBus.daily_mission_progress.emit(mission_id, m.progress)
```

**클레임 (캡 enforce)**:

```gdscript
func claim(mission_id: String) -> Dictionary:
    var mission: Dictionary = _find(mission_id)
    if mission == null or mission.claimed: return {}
    if mission.progress < _required(mission_id): return {}

    var reward_tech: int = DailyMissionConfig.get_reward(mission_id)
    var remaining_cap: int = DAILY_TECH_LEVEL_CAP - GameState.daily_mission.daily_tech_level_earned
    var actual_gain: int = min(reward_tech, remaining_cap)

    if actual_gain > 0:
        TechLevelService.add(actual_gain)
        GameState.daily_mission.daily_tech_level_earned += actual_gain

    mission.claimed = true
    SaveSystem.save()
    EventBus.daily_mission_claimed.emit(mission_id, actual_gain)
    return { "tech_level_gained": actual_gain, "capped": actual_gain < reward_tech }
```

### 2.4 Rewarded Ads (Mobile 4 지점)

| 삽입 지점 | 카운터 키 | 보상 | 일일 한도 | UI 위치 |
|---|---|---|---|---|
| Abort 화면 | `abort` | 수리비 50% 환불 | 3회 | Abort 화면, Shield 버튼 옆 |
| Win 화면 | `win` | 해당 목적지 보상 +50% (Credit + TechLevel) | 5회 | Win 화면 보상 요약 아래 |
| Daily Reward | `daily` | 일일 Credit 보상 2배 | 1회 | DailyRewardModal Claim 버튼 옆 |
| Auto-Fuel 만료 | `auto_fuel` | Auto Fuel 5분 추가 | 4회 | Auto Launch HUD 인라인 버튼 |

**핵심 흐름**:

```gdscript
# scripts/services/ad_service.gd
func should_show_ad() -> bool:
    if OS.has_feature("steam"): return false      # Steam은 광고 없음
    if IAPService.is_purchased("IAP_VIP"): return false
    return true

func can_show(slot: String) -> bool:
    if not should_show_ad(): return false
    _maybe_reset_daily()
    var limit: int = AdRewardConfig.daily_limit(slot)
    return GameState.ad_reward_state.counts.get(slot, 0) < limit

func show(slot: String, on_reward: Callable) -> void:
    if not can_show(slot): return
    AdMob.show_rewarded_ad(func():
        GameState.ad_reward_state.counts[slot] += 1
        SaveSystem.save()
        on_reward.call()
        EventBus.ad_reward_granted.emit(slot)
    )
```

**운영 규칙**:
- 모든 광고 **선택적** (opt-in). 강제 광고 없음.
- **13세 미만 유저에게는 광고 버튼 미표시** (앱 시작 연령 게이트 → COPPA / GDPR-K 준수).
- 일일 한도 초과 시 버튼 비활성화 + 횟수 표시 ("3/3 사용").
- 광고 로드 실패 시 버튼 숨김 (에러 토스트 미표시).
- **VIP 보유 시 광고 자체 제거** — 모든 광고 버튼 미표시.

### 2.5 자동 팝업 정책 (Daily Reward Modal)

```gdscript
# 진입 5분 후 한 번만 자동 노출
func _check_auto_popup() -> void:
    if GameState.session_start_time + 300 > Time.get_unix_time_from_system():
        get_tree().create_timer(60.0).timeout.connect(_check_auto_popup)
        return
    if GameState.highest_completed_tier < 1: return
    if can_claim() and not _shown_this_session:
        _shown_this_session = true
        EventBus.daily_reward_modal_request.emit()
```

## 3. 정적 데이터 (Config)

### `data/daily_reward_config.tres`

```
table = [
    { day = 1, credit = 5 },
    { day = 2, credit = 8 },
    { day = 3, credit = 10, boost_minutes = 15 },
    { day = 4, credit = 12 },
    { day = 5, credit = 15 },
    { day = 6, credit = 18, boost_minutes = 15 },
    { day = 7, credit = 25, boost_minutes = 30, title = "Weekly Explorer" },
]
auto_popup_delay_sec = 300                       # 첫 5분 모달 억제
```

### `data/daily_mission_config.tres`

```
pool = [
    { id = "DM_LAUNCH_20", required = 20, reward_tech = 10, event = "rocket_launched" },
    { id = "DM_SUCCESS_3", required = 3, reward_tech = 15, event = "destination_completed" },
    { id = "DM_STAGE_5_STREAK", required = 5, reward_tech = 10, event = "stage_streak" },
    { id = "DM_FACILITY_UPGRADE_1", required = 1, reward_tech = 10, event = "facility_upgraded" },
    { id = "DM_PLAY_10M", required = 600, reward_tech = 15, event = "play_time_sec" },
    { id = "DM_AUTO_LAUNCH_5M", required = 300, reward_tech = 10, event = "auto_launch_active_sec" },
    { id = "DM_NEW_DESTINATION", required = 1, reward_tech = 20, event = "new_destination" },
]
daily_slot_base = 3
daily_slot_subscription_bonus = 1
daily_tech_level_cap = 50
```

### `data/ad_reward_config.tres`

```
slots = [
    { key = "abort", daily_limit = 3, reward_kind = "repair_refund_50pct" },
    { key = "win", daily_limit = 5, reward_kind = "destination_reward_+50pct" },
    { key = "daily", daily_limit = 1, reward_kind = "daily_credit_2x" },
    { key = "auto_fuel", daily_limit = 4, reward_kind = "auto_fuel_extend_5min" },
]
```

### 효과 상수 (`scripts/services/daily_mission_service.gd`)

```gdscript
const DAILY_TECH_LEVEL_CAP: int = 50
```

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

```gdscript
{
    "daily_reward": {
        "last_claim_date": "2026-04-23",          # ISO date "YYYY-MM-DD"
        "streak": 3
    },
    "daily_mission": {
        "date": "2026-04-23",
        "missions": [
            { "id": "DM_LAUNCH_20", "progress": 12, "claimed": false },
            { "id": "DM_SUCCESS_3", "progress": 1, "claimed": false },
            { "id": "DM_STAGE_5_STREAK", "progress": 0, "claimed": false }
        ],
        "daily_tech_level_earned": 0
    },
    "ad_reward_state": {
        "date": "2026-04-23",
        "counts": { "abort": 0, "win": 0, "daily": 0, "auto_fuel": 0 }
    }
}
```

## 5. 런타임 상태

| 필드 | 용도 |
|---|---|
| `DailyRewardService._shown_this_session: bool` | 자동 팝업 1회만 표시 |
| `DailyMissionService._progress_listeners: Array` | 시그널 연결 핸들 (cleanup용) |
| `AdService._ad_loaded: Dictionary[String, bool]` | 광고 슬롯별 사전 로드 상태 |

## 6. 시그널 (EventBus)

| Signal | 인자 | 발화 시점 |
|---|---|---|
| `daily_reward_claimed` | `(new_streak: int, reward: Dictionary)` | 일일 보상 수령 완료 |
| `daily_reward_modal_request` | `()` | 자동 팝업 트리거 |
| `daily_mission_rolled` | `(missions: Array)` | 자정 리셋 후 새 미션 결정 |
| `daily_mission_progress` | `(mission_id: String, progress: int)` | 미션 진행도 갱신 |
| `daily_mission_claimed` | `(mission_id: String, tech_gained: int)` | 미션 보상 수령 |
| `ad_reward_granted` | `(slot: String)` | 광고 시청 완료 + 보상 지급 |

## 7. 의존성

**의존**:
- `GameState`, `SaveSystem`
- `EconomyService` (Credit 지급)
- `IAPService.activate_boost()` (Daily Reward 보너스 부스트)
- `TechLevelService` (Daily Mission 보상)
- `TitleService` (Day 7 칭호)
- `SubscriptionService.is_active()` (미션 슬롯 +1 판단)
- `AdMob` 플러그인 (Mobile 한정)

**의존받음**:
- `LaunchService` — `EventBus.rocket_launched` 시그널 (DM_LAUNCH_20)
- `DestinationService` — `EventBus.destination_completed` 시그널 (DM_SUCCESS_3, DM_NEW_DESTINATION, Win 광고)
- `FacilityService` — `EventBus.facility_upgraded` 시그널 (DM_FACILITY_UPGRADE_1)
- `LaunchService.abort_launch()` — Abort 광고 보상
- `scenes/ui/daily_reward_modal.tscn`
- `scenes/ui/mission_panel.tscn`
- `scenes/ui/abort_screen.tscn`
- `scenes/ui/win_screen.tscn`
- `scenes/ui/auto_launch_hud.tscn`

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/daily_reward_service.gd` | 7일 스트릭, 보상 지급, 자동 팝업 |
| `scripts/services/daily_mission_service.gd` | 일일 미션 선택/진행/캡 enforce |
| `scripts/services/ad_service.gd` | AdMob 래퍼, 일일 한도 카운터 |
| `data/daily_reward_config.tres` | 7일 보상 테이블 |
| `data/daily_mission_config.tres` | 미션 풀, 캡 |
| `data/ad_reward_config.tres` | 4개 광고 슬롯 |
| `scenes/ui/daily_reward_modal.tscn` | 7일 보상 미리보기 + Claim 버튼 |
| `scenes/ui/mission_panel.tscn` | Daily/Weekly 미션 통합 표시 |
| `scenes/ui/abort_screen.tscn` | Abort 광고 버튼 + Shield CTA |
| `scenes/ui/win_screen.tscn` | Win 광고 버튼 |
| `scenes/ui/auto_launch_hud.tscn` | Auto Fuel 광고 버튼 |

## 9. 알려진 이슈 / 설계 주의점

1. **디바이스 로컬 자정 vs UTC**: `Time.get_date_string_from_system()`는 디바이스 로컬 시각 기준. 사용자가 다른 시간대로 여행하면 같은 24시간 내 두 번 수령이 가능해 보일 수 있다 → 실제로는 `last_claim_date` 비교가 문자열 비교라 정확히 1일 1회만 허용.
2. **시계 변조**: 시계를 미래로 돌려 매일 보상을 즉시 수령 가능. V2에서 마지막 저장 시각 vs 현재 시각 sanity check 추가 검토. V1에서는 P0 결제 인증의 정합성에 영향 없으므로 미차단.
3. **Daily TechLevel 캡 50 + Weekly 캡 500 동시 적용**: 같은 발사 행위가 Daily/Weekly 양쪽 카운터에 동시 가산된다. 캡은 각각 독립 — 일일 50 채워도 주간 500 카운터는 계속 증가. UI에서 두 카운터를 명확히 구분 표시.
4. **자동 팝업과 IAP 모달 충돌 가드**: `daily_reward_modal_request` 발화 시 다른 모달이 열려 있으면 큐잉. `UIStackManager`가 모달 우선순위 관리. 첫 5분 게이트는 두 시스템 모두 적용.
5. **VIP 광고 제거 vs Daily Reward 2배 광고 버튼**: VIP 보유 시 Daily Reward Credit 2배 광고 버튼 자체가 사라진다. 사용자가 보너스를 못 받는다는 인지가 생기지 않도록 Day 7 보상량 자체를 매력적으로 유지(`docs/bm.md` §9.1 25 Credit + 30분 Boost + 칭호).
6. **결정적 미션 선택 시드**: `(today + player_seed).hash()`로 시드 고정. 같은 디바이스/날짜는 항상 같은 미션. 사용자가 미션을 보고 앱을 끄고 다시 켜도 미션이 바뀌지 않는다 (탐욕적 reroll 방지).
7. **Steam 트랙의 광고 처리**: `OS.has_feature("steam")` 체크로 모든 광고 진입점이 비활성화. Daily Reward의 광고 2배 버튼도 Steam에서는 미표시 → Day 7 정점 보상이 전부.
8. **Subscription 미션 슬롯 +1 동기화**: 구독 활성/만료 시점에 즉시 슬롯 수가 변경되면 진행 중 미션이 사라지는 문제 → 슬롯 변경은 다음 자정 리셋부터 적용. 구독 만료 후 24시간 동안은 4번째 슬롯이 잔존하지만 보상 수령만 가능, 신규 굴림은 3개로 복귀.
9. **Auto-Fuel 광고 5분 추가**: `IAPService.activate_boost("auto_fuel", 300)`을 호출. 활성 중이면 남은 시간 + 5분 누적 (7-2 §2.9 스택 누적 규칙).
10. **AdMob 광고 단위 등록**: `data/ad_reward_config.tres`에는 광고 단위 ID를 직접 두지 않는다. `scripts/services/ad_service.gd` 내부에 빌드 환경별 ID 분기 (debug/release). 키스토어와 동일한 보안 수준으로 관리.
