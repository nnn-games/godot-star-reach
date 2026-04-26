# 7-4. Subscription + Battle Pass — V1 정식 구현

> 카테고리: Monetization
> 정본 문서: `docs/bm.md` §5 (Subscription), §6 (Battle Pass)
> 구현: `scripts/services/subscription_service.gd`, `scripts/services/battle_pass_service.gd`, `data/subscription_config.tres`, `data/battle_pass_config.tres`

## 1. 시스템 개요

월 구독형 프리미엄 멤버십과 분기 시즌 Battle Pass 두 채널을 정의한다.

- **Subscription `Orbital Operations Pass`** — Mobile 한정 권장 ($4.99/월). Apple/Google 표준 구독 API 사용. 광고 제거 + 일일/주간/월간 무료 샘플 + QoL 혜택. 기존 영구형/소모형 IAP의 효과를 직접 포함하지 않아 IAP 구매 동기를 보호한다.
- **Battle Pass** — 양 플랫폼 공통. 시즌 3개월, Free + Premium 양 트랙, 50 티어. 시즌 시작 14일 30% 할인.

> Steam 유저는 일반적으로 1회 구매 + Premium 코스메틱 DLC를 선호하므로 Subscription은 Mobile 한정 권장. Battle Pass는 양쪽 모두 정식 지원.

**핵심 설계 원칙** (`docs/bm.md` §5, §13):
- 구독은 "대체"가 아닌 **"촉진"** — 기존 IAP 구매 동기를 보호.
- **XP 상시 배율 금지** (`IAP_VIP` 보호)
- **성공률 상시 보정 금지** (`IAP_GUIDANCE_MODULE` 보호)
- **Abort 무제한 방어 금지** (`IAP_SHIELD_*` 반복 구매 보호)
- **Auto Launch 속도 캡 해제 금지** (`IAP_AUTO_LAUNCH_PASS` 보호)

**책임 경계**
- 구독 영수증 검증 (Apple/Google 자동 갱신 영수증 추적).
- 구독 혜택 클레임 (일일/주간/월간 잔량 관리).
- Battle Pass 시즌 XP 누적, 티어 자동 해금, 보상 클레임.
- Free/Premium 트랙 분리 + 시즌 기간 enforce.

**책임 아닌 것**
- 부스트 효과 적용(→ `IAPService.activate_boost()` 위임 — 7-2의 슬롯 재사용).
- 칭호 부여(→ `TitleService` 위임).
- 광고 제거 자체 로직(→ `AdService.should_show_ad()`가 직접 `is_active()` 조회).

## 2. 코어 로직

### 2.1 Subscription — 상품 정의

| 항목 | 값 |
|---|---|
| 상품 Key | `SUB_ORBITAL_OPS_PASS` |
| 상품명 | Orbital Operations Pass |
| 가격 | **$4.99/월** (Apple/Google 표준 월 구독 가격대) |
| 무료 체험 | 첫 7일 무료 (Apple/Google 표준 정책 활용) |
| 노출 조건 | T3 진입 (`highest_completed_tier >= 3`) |
| 플랫폼 | Mobile (Android Google Play Subscription / iOS StoreKit Auto-Renewable) |

### 2.2 Subscription — 혜택 정의 (`docs/bm.md` §5.2)

| 혜택 | 수량 | 주기 | 연결 시스템 |
|---|---:|---|---|
| 광고 완전 제거 | 상시 | — | `AdService.should_show_ad()` 분기 |
| 일일 2x Boost (15min) | 1회 | 일일 | `IAPService.activate_boost("boost_2x", 900)` |
| 주간 System Purge | 2회 | 주간 (월요일 00:00) | `purge_inventory` 적립 |
| 월간 Trajectory Surge | 4회 | 월간 (1일 00:00) | `IAPService.activate_boost("trajectory_surge", 1800)` |
| 일일 미션 +1 슬롯 | 상시 | — | `DailyMissionService.roll_today()` 분기 |
| 구독 전용 칭호 | 1종 | 상시 | `TitleService.grant("orbital_operator")` |
| 일일 보상 +25% Credit | 상시 | — | `DailyRewardService.claim()` 곱 |

### 2.3 Subscription — 제외 혜택 (다른 IAP 보호)

| 제외 항목 | 보호 대상 IAP |
|---|---|
| XP 상시 배율 | `IAP_VIP` ($2.99) |
| 성공 확률 상시 보정 | `IAP_GUIDANCE_MODULE` ($5.99) |
| Abort 무제한 방어 | `IAP_SHIELD_T3/T4/T5` ($2.99~$9.99) |
| Auto Launch 속도 캡 해제 | `IAP_AUTO_LAUNCH_PASS` ($4.99) |

### 2.4 Subscription — 활성 상태 확인

```gdscript
# scripts/services/subscription_service.gd
func is_active() -> bool:
    if not GameState.subscription.active: return false
    var now: int = Time.get_unix_time_from_system()
    if now > GameState.subscription.expire_at:
        _deactivate()
        return false
    return true

func _deactivate() -> void:
    GameState.subscription.active = false
    SaveSystem.save()
    EventBus.subscription_expired.emit()

# 앱 진입 시 / 24h 주기로 영수증 재검증
func verify_status() -> void:
    var receipt: Dictionary = await _platform_query_subscription("SUB_ORBITAL_OPS_PASS")
    if receipt.is_empty():
        _deactivate()
        return
    GameState.subscription.expire_at = receipt["expires_date_unix"]
    GameState.subscription.next_renewal_at = receipt["next_renewal_unix"]
    GameState.subscription.active = receipt["status"] == "active"
    SaveSystem.save()
```

### 2.5 Subscription — 혜택 클레임

```gdscript
# 일일 2x Boost
func claim_daily_boost() -> bool:
    if not is_active(): return false
    var today: String = Time.get_date_string_from_system()
    if GameState.subscription.daily_boost_claimed_date == today:
        return false
    IAPService.activate_boost("boost_2x", 900)        # 15분
    GameState.subscription.daily_boost_claimed_date = today
    SaveSystem.save()
    EventBus.subscription_benefit_claimed.emit("daily_boost")
    return true

# 주간 System Purge
func claim_weekly_purge() -> bool:
    if not is_active(): return false
    _maybe_reset_weekly()                              # 월요일 00:00 자동 리셋
    if GameState.subscription.weekly_purge_remaining <= 0:
        return false
    GameState.subscription.weekly_purge_remaining -= 1
    GameState.purge_inventory += 1                     # 인벤토리 적립 (즉시 사용 또는 보관)
    SaveSystem.save()
    EventBus.subscription_benefit_claimed.emit("weekly_purge")
    return true

# 월간 Trajectory Surge
func claim_monthly_surge() -> bool:
    if not is_active(): return false
    _maybe_reset_monthly()                             # 매월 1일 00:00 자동 리셋
    if GameState.subscription.monthly_surge_remaining <= 0:
        return false
    GameState.subscription.monthly_surge_remaining -= 1
    IAPService.activate_boost("trajectory_surge", 1800)
    SaveSystem.save()
    EventBus.subscription_benefit_claimed.emit("monthly_surge")
    return true
```

### 2.6 Subscription — 자동 갱신 영수증 추적

| 플랫폼 | 핵심 API |
|---|---|
| Android | Google Play Billing `subscriptionPurchase` + `BillingClient.queryPurchasesAsync(SUBS)` |
| iOS | StoreKit `SKPaymentQueue` + `originalTransactionIdentifier`로 자동 갱신 추적 |

구독 취소 / 일시 정지 / 갱신 실패는 **다음 진입 시 영수증 재검증**으로 감지 → `_deactivate()`.

### 2.7 Battle Pass — 상품 정의

| 항목 | 값 |
|---|---|
| 시즌 길이 | 3개월 (분기) |
| Free 트랙 | 모든 유저 자동 진입 |
| Premium 트랙 (`IAP_BATTLE_PASS_PREMIUM`) | $9.99 (시즌 시작 14일 30% 할인 → $6.99) |
| 노출 조건 | T1 완료 (`highest_completed_tier >= 1`) |
| 시즌 ID 예시 | `S01_LUNAR`, `S02_MARS`, `S03_OUTER` |
| 총 티어 | 50 |

### 2.8 Battle Pass — 보상 구조

총 50 티어 × (Free / Premium 양 트랙).

| 보상 종류 | Free 트랙 | Premium 트랙 |
|---|---|---|
| Credit | 합산 약 1,500 C | 합산 약 6,000 C |
| Booster (2x Boost / Auto Fuel / Trajectory Surge) | 5개 | 25개 |
| 코스메틱 (트레일 / 발사대 스킨) | 2종 | 12종 |
| 시즌 칭호 | 1종 (50 티어 달성 시) | 3종 (10/30/50 티어) |
| 마일스톤 사전 렌더 영상 (한정 컷) | — | 1종 (해당 시즌 테마) |

### 2.9 Battle Pass — 시즌 XP 진행

획득 경로:
- **일일 미션 완료**: +50 XP/미션 (3~4개 → 일일 150~200 XP)
- **주간 미션 완료**: +500 XP/미션 (5개 → 주간 2,500 XP)
- **목적지 완료**: +Tier × 10 XP (T3 목적지 → 30 XP)
- **시즌 챌린지** (시즌당 10개): +1,000 XP/챌린지 (시즌 총 10,000 XP)

티어당 필요 XP: 1,000 (50 티어 × 1,000 = 50,000 XP). 시즌 90일 평균 일일 ~556 XP 필요 → 일일/주간 미션 + 목적지 완료로 도달 가능.

### 2.10 Battle Pass — 핵심 흐름

```gdscript
# scripts/services/battle_pass_service.gd
func add_xp(amount: int) -> void:
    if not _season_active(): return
    GameState.season.season_xp += amount
    var new_tier: int = GameState.season.season_xp / XP_PER_TIER
    new_tier = min(new_tier, MAX_TIER)
    while GameState.season.current_tier < new_tier:
        GameState.season.current_tier += 1
        EventBus.battle_pass_tier_unlocked.emit(GameState.season.current_tier)
    SaveSystem.save()

func claim_tier(tier: int, track: String) -> Dictionary:
    if tier > GameState.season.current_tier: return {}
    if track == "premium" and not GameState.season.premium_owned: return {}

    var claimed_array: Array = (GameState.season.claimed_tiers_premium
        if track == "premium" else GameState.season.claimed_tiers_free)
    if tier in claimed_array: return {}

    var reward: Dictionary = BattlePassConfig.get_reward(GameState.season.current_season_id, tier, track)
    _apply_reward(reward)
    claimed_array.append(tier)
    SaveSystem.save()
    EventBus.battle_pass_reward_claimed.emit(tier, track, reward)
    return reward

func purchase_premium() -> void:
    var price_key: String
    if _within_launch_discount_window():
        price_key = "IAP_BATTLE_PASS_PREMIUM_LAUNCH"   # $6.99 (14일 한정)
    else:
        price_key = "IAP_BATTLE_PASS_PREMIUM"          # $9.99
    IAPService.purchase(price_key)
    # 영수증 검증 후 EventBus.iap_purchased에서 _on_premium_purchased 처리
```

### 2.11 시즌 종료 / 전환

```gdscript
func _check_season_rollover() -> void:
    var now: int = Time.get_unix_time_from_system()
    if now < GameState.season.season_end_at: return

    # 시즌 종료 — 미수령 보상 보관 (30일 그레이스 윈도우)
    EventBus.season_ended.emit(GameState.season.current_season_id)
    _archive_season(GameState.season)

    # 다음 시즌 자동 시작
    var next: Dictionary = BattlePassConfig.next_season_after(GameState.season.current_season_id)
    GameState.season = {
        "current_season_id": next["id"],
        "season_xp": 0,
        "current_tier": 0,
        "premium_owned": false,
        "claimed_tiers_free": [],
        "claimed_tiers_premium": [],
        "season_start_at": now,
        "season_end_at": now + SEASON_DURATION_SEC,    # 90일
    }
    SaveSystem.save()
    EventBus.season_started.emit(next["id"])
```

## 3. 정적 데이터 (Config)

### `data/subscription_config.tres`

```
sub_id = "SUB_ORBITAL_OPS_PASS"
price_usd = 4.99
billing_period = "monthly"
free_trial_days = 7
required_tier = 3
benefits = {
    daily_boost_minutes = 15,
    weekly_purge_count = 2,
    monthly_surge_count = 4,
    extra_daily_mission_slot = 1,
    daily_reward_credit_mult = 1.25,
    title = "orbital_operator",
    ad_free = true,
}
```

### `data/battle_pass_config.tres`

```
season_duration_sec = 7776000          # 90일 (3개월)
xp_per_tier = 1000
max_tier = 50
launch_discount_days = 14
launch_discount_pct = 0.30

seasons = [
    {
        id = "S01_LUNAR",
        title = "Lunar Operations",
        free_track = [...],            # 50 티어 보상 배열
        premium_track = [...],
    },
    { id = "S02_MARS", ... },
    { id = "S03_OUTER", ... },
]

premium_iap = {
    standard = "IAP_BATTLE_PASS_PREMIUM",          # $9.99
    launch_discount = "IAP_BATTLE_PASS_PREMIUM_LAUNCH",  # $6.99 (14일 한정)
}
```

### 효과 상수 (`scripts/services/subscription_service.gd`)

```gdscript
const DAILY_BOOST_DURATION_SEC: int = 900           # 15분
const MONTHLY_SURGE_DURATION_SEC: int = 1800        # 30분
const WEEKLY_PURGE_INITIAL: int = 2
const MONTHLY_SURGE_INITIAL: int = 4
const SUBSCRIBER_DAILY_REWARD_MULT: float = 1.25
```

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

```gdscript
{
    "subscription": {
        "active": false,
        "tier": "orbital_ops",
        "purchase_token": "",                       # Google Play purchase token
        "original_transaction_id": "",              # iOS originalTransactionIdentifier
        "next_renewal_at": 0,
        "expire_at": 0,
        "daily_boost_claimed_date": "",
        "weekly_purge_remaining": 2,
        "weekly_purge_reset_at": 0,
        "monthly_surge_remaining": 4,
        "monthly_surge_reset_at": 0
    },
    "season": {
        "current_season_id": "S01_LUNAR",
        "season_xp": 0,
        "current_tier": 0,
        "premium_owned": false,
        "claimed_tiers_free": [],
        "claimed_tiers_premium": [],
        "season_start_at": 1714000000,
        "season_end_at": 1721776000
    }
}
```

**리셋 주기**:
- `daily_boost_claimed_date` — 매일 디바이스 로컬 자정 (날짜 문자열 비교)
- `weekly_purge_remaining` — 매주 월요일 00:00 → `WEEKLY_PURGE_INITIAL(2)`로 복구
- `monthly_surge_remaining` — 매월 1일 00:00 → `MONTHLY_SURGE_INITIAL(4)`로 복구
- `season_*` — 90일마다 시즌 전환

## 5. 런타임 상태

| 필드 | 용도 |
|---|---|
| `SubscriptionService._verify_in_flight: bool` | 영수증 재검증 중복 호출 가드 |
| `SubscriptionService._last_verify_at: int` | 24h 주기 재검증 타이머 |
| `BattlePassService._xp_pending_save: bool` | 짧은 시간 다발 XP 누적 시 저장 디바운스 |

## 6. 시그널 (EventBus)

| Signal | 인자 | 발화 시점 |
|---|---|---|
| `subscription_renewed` | `(expire_at: int)` | 자동 갱신 영수증 확인 시 |
| `subscription_expired` | `()` | 갱신 실패 / 취소 감지 시 |
| `subscription_benefit_claimed` | `(benefit_kind: String)` | daily_boost / weekly_purge / monthly_surge |
| `battle_pass_tier_unlocked` | `(tier: int)` | 시즌 XP 누적으로 새 티어 도달 |
| `battle_pass_reward_claimed` | `(tier: int, track: String, reward: Dictionary)` | 보상 수령 |
| `battle_pass_premium_purchased` | `(season_id: String)` | Premium 트랙 구매 영수증 검증 후 |
| `season_started` | `(season_id: String)` | 시즌 전환 |
| `season_ended` | `(season_id: String)` | 시즌 종료 |

## 7. 의존성

**의존**:
- `GameState`, `SaveSystem`
- `IAPService` (Premium 트랙 구매, 부스트 무료 활성화)
- `EconomyService` (Credit 보상 지급)
- `TitleService` (구독/시즌 칭호 부여)
- `AdService` (`is_active()` 조회로 광고 제거)
- 플랫폼 어댑터 (`google_play_billing.gd`, `apple_storekit.gd`)

**의존받음**:
- `AdService.should_show_ad()` — `SubscriptionService.is_active()`
- `DailyMissionService.roll_today()` — `is_active()`로 슬롯 +1 판단
- `DailyRewardService.claim()` — 구독자 Credit 1.25배
- `DailyMissionService` / `MissionService` 등 — `BattlePassService.add_xp()` 호출
- `LaunchService.launch_rocket()` — 목적지 완료 시 `add_xp()`
- `scenes/ui/subscription_panel.tscn`
- `scenes/ui/battle_pass_panel.tscn`

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/subscription_service.gd` | 구독 영수증, 일일/주간/월간 혜택 클레임 |
| `scripts/services/battle_pass_service.gd` | 시즌 XP, 티어 해금, 보상 클레임, 시즌 전환 |
| `data/subscription_config.tres` | 가격, 혜택 수량 |
| `data/battle_pass_config.tres` | 시즌 정의, 티어 보상 테이블, Premium 가격 |
| `scenes/ui/subscription_panel.tscn` | 구독 카드 + 혜택 클레임 버튼 |
| `scenes/ui/battle_pass_panel.tscn` | 시즌 진행도 + 50 티어 그리드 |
| `scenes/ui/season_end_summary.tscn` | 시즌 종료 요약 |

## 9. 알려진 이슈 / 설계 주의점

1. **Subscription은 Mobile 한정 권장**: Steam 유저는 1회 구매 후 Subscription을 잘 구매하지 않는 경향. Steam에서는 Subscription 카드 자체를 숨기고, 동일한 가치 제안을 Battle Pass Premium + Cosmetic DLC로 분산. `OS.has_feature("steam")` 체크.
2. **혜택의 "촉진" 원칙 준수 감시**: Subscription 혜택을 추가/조정할 때 `docs/bm.md` §13 "채널 간 역할 분리" 규칙을 반드시 체크. 예: 구독에 "성공률 +1%" 추가 → `IAP_GUIDANCE_MODULE` 가치 훼손.
3. **일일 2x Boost의 슬롯 공유 문제**: `IAP_BOOST_2X` (30분 소모형 IAP)와 구독 일일 보너스(15분)가 같은 `boost_2x_expire_at` 슬롯을 공유한다. 7-2 §2.9의 "스택 누적" 규칙으로 처리 — `max(now, current) + duration` → 손실 없이 시간이 더해진다.
4. **구독 해지 감지 주기**: `verify_status()`는 앱 진입 시 + 24h 주기 호출. 세션 중 구독 해지 시 즉시 반영 안 됨 — 다음 진입 시 비활성화. 일반적으로 허용 가능한 정책.
5. **Free Trial 7일 → 환불 어뷰즈**: Apple/Google 표준 정책상 7일 무료 체험 후 자동 결제 전 취소 가능. 어뷰즈를 100% 차단할 수 없으므로 무료 체험 중 받은 혜택은 회수하지 않음 (UX 우선). 단, Premium Battle Pass는 무료 체험과 분리.
6. **시즌 전환 누락 보상 처리**: 시즌 종료 시 미수령 보상은 30일 그레이스 윈도우 동안 `_archive_season`에 보관. 이후 영구 소실. UI는 시즌 종료 7일 전 / 1일 전 토스트 알림.
7. **Battle Pass Premium 시즌별 별도 구매**: `IAP_BATTLE_PASS_PREMIUM`은 시즌마다 별도 구매. `season.premium_owned`는 현재 시즌만 적용 → 다음 시즌 전환 시 `false`로 리셋.
8. **시즌 시작 14일 30% 할인 → 유효 가격 비교 표시**: UI는 정가 $9.99에 취소선, 할인가 $6.99 강조 + 남은 시간(시:분) 카운트다운. 14일 경과 후 자동으로 정가 $9.99 카드로 전환.
9. **시즌 XP 보존 정책**: 시즌 종료 시 `season_xp`는 0으로 리셋. 단, 미수령 티어 보상은 그레이스 윈도우에서 수령 가능. Premium 미구매로 못 받은 Premium 트랙 보상은 시즌 종료 후 Premium 구매로도 회수 불가 (시즌 마감 시점 기준).
10. **칭호 시스템 의존성**: `TitleService.grant()` API가 선행 구현 필요. Subscription 칭호 `orbital_operator`, Battle Pass 시즌 칭호 (예: `lunar_pioneer`)를 부여할 수 있어야 한다. `PlayerData.titles` 배열 + 활성 표시 칭호 1개 (`active_title`) 구조.
11. **첫 5분 모달 금지 (`docs/bm.md` §11.2)**: Subscription / Battle Pass 자동 팝업 모두 진입 후 300초 게이트 적용. 패널 자체는 Shop 메뉴에서 항상 접근 가능.
12. **Subscription + Battle Pass Premium 동시 보유 시너지 의도적**: 두 채널은 서로 대체재가 아닌 보완재 — 구독은 일일/주간 정기 혜택, Battle Pass는 시즌 단발 컬렉션. 동시 보유 시 ARPU 최상단 유저로 분류 (LTV 추적용 메타).
