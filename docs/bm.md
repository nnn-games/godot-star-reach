# Star Reach BM 상세 기획서 (Mobile + Steam 듀얼 트랙)

> **작성일**: 2026-04-24
> **상위 문서**: `docs/prd.md`, `docs/design/game_overview.md` §7
> **문서 성격**: 개발 실행용 상세 기획. Mobile (Android/iOS) + Steam (PC) 두 플랫폼의 IAP / 광고 / 구독 / DLC를 실제 코드로 구현하기 위한 사양.

---

# 1. 문서 범위

이 문서는 Mobile 4채널 (IAP / Rewarded Ad / Subscription / Battle Pass) + Steam 3채널 (Standard Edition / DLC / Cosmetic DLC) 를 Godot 4.6 단일 코드베이스에서 구현하기 위한 상세 기획이다.

각 채널마다 아래를 정의한다.

1. 구현 사양 (무엇을 만드는가)
2. 데이터 구조 (무엇을 저장하는가)
3. 클라이언트 로직 (어떻게 동작하는가 — 싱글 클라이언트 단독)
4. 클라이언트 UI (어떻게 보여주는가)
5. 노출 조건 (언제 보여주는가)
6. 선행 작업 (무엇을 먼저 해야 하는가)

---

# 2. Phase 0 — 선결 작업

Phase 1 이전에 반드시 완료해야 하는 기반 정비.

## 2.1 Auto Launch 무료 해금 구조

| 항목 | 설계 |
|---|---|
| 해금 조건 | `T1 첫 클리어` 또는 `누적 10회 발사` |
| 추가 가속 (IAP) | `Auto Launch Pass` 구매 시 +0.35 launches/s 영구 |
| Auto Fuel (소모 IAP) | `+0.5 launches/s` 60분 |

**구현**: `scripts/services/auto_launch_service.gd`
- `is_unlocked()`: `GameState.total_launches >= 10 or GameState.highest_completed_tier >= 1`
- `get_rate()`: `1.0 + auto_pass_bonus + auto_fuel_bonus` (캡 2.5 launches/s)

## 2.2 Auto Fuel 속도 반영

`scripts/services/auto_launch_service.gd::get_rate()`에서 `IAPService.has_active_auto_fuel()` 체크 후 `+0.5` 가산.

## 2.3 메타 보너스 시스템

싱글 오프라인 게임의 리텐션 레이어:

| 행동 | 보상 |
|---|---|
| 일일 로그인 (1~7 스트릭) | 5~25 Credit + 보너스 부스터 (Day 7) |
| 도감 25/50/75/100% 달성 | 칭호 + 누적 Credit 보너스 |
| 시즌 컬렉션 완료 | 한정 코스메틱 + 부스터 |
| 100시간 / 500시간 누적 플레이 | 영구 칭호 |

상세는 §5 Daily Reward / §10 메타 보너스 풀 참조.

---

# 3. Mobile Channel A — IAP (One-Time Purchase, 소비형 + 영구형)

## 3.1 영구형 IAP (One-Time Purchase, Non-Consumable)

| Key | 상품명 | 가격 (USD) | 효과 | 노출 조건 |
|---|---|---|---|---|
| `IAP_VIP` | VIP | $2.99 | XP 2배 영구 + 광고 제거 | T1 완료 |
| `IAP_AUTO_LAUNCH_PASS` | Auto Launch Pass | $4.99 | +0.35 launches/s 영구 | T1 완료 |
| `IAP_GUIDANCE_MODULE` | Guidance Module | $5.99 | +5%p 기본 성공 확률 영구 | T2 진입 |

## 3.2 소모형 IAP (Consumable)

| Key | 상품명 | 가격 (USD) | 효과 | 노출 조건 |
|---|---|---|---|---|
| `IAP_BOOST_2X` | 2x Boost (30min) | $1.49 | 30분 XP 2배 | T1 완료 |
| `IAP_TRAJECTORY_SURGE` | Trajectory Surge (30min) | $1.99 | 30분 +3%p 확률 | T2 진입 |
| `IAP_AUTO_FUEL` | Auto Fuel (60min) | $0.99 | 60분 +0.5/s | T1 완료 |
| `IAP_SHIELD_T3` | Launch Fail-safe T3 | $2.99 | 다음 T3 Abort 수리비 면제 | T3 진입 |
| `IAP_SHIELD_T4` | Launch Fail-safe T4 | $4.99 | 다음 T4 Abort 수리비 면제 | T3 진입 |
| `IAP_SHIELD_T5` | Launch Fail-safe T5 | $9.99 | 다음 T5 Abort 수리비 면제 | T4 진입 |
| `IAP_SYSTEM_PURGE` | System Purge | $0.99 | 스트레스 -30 | T3 진입 (Stress ≥ 50) |

## 3.3 소프트 화폐 팩 (Consumable)

| Key | 상품명 | 가격 (USD) | 효과 | 노출 조건 |
|---|---|---|---|---|
| `IAP_CREDIT_S` | Credit Pack S | $0.99 | +500 Credit | T2 진입 |
| `IAP_CREDIT_M` | Credit Pack M | $4.99 | +3,000 Credit (+20% 보너스) | T3 진입 |
| `IAP_CREDIT_L` | Credit Pack L | $9.99 | +7,500 Credit (+50% 보너스) | T4 진입 |

> **주의**: TechLevel 직접 판매 IAP는 절대 만들지 않는다 (단조 증가축 P2W 방어선).

## 3.4 번들 / 패키지 (One-Time)

| Key | 상품명 | 가격 (USD) | 구성 | 노출 시점 |
|---|---|---|---|---|
| `IAP_STARTER_PACK` | Starter Pack | $4.99 | VIP(7일) + 2x Boost x3 + Auto Fuel x3 | T1 첫 클리어 직후 (24h 한정) |
| `IAP_FIRST_MISSION_PACK` | First Mission Pack | $2.99 | 2x Boost x1 + Auto Fuel x1 + 전용 트레일 코스메틱 | T2 첫 진입 |
| `IAP_RISK_RECOVERY_PACK` | Risk Recovery Pack | $4.99 | Trajectory Surge x1 + System Purge x2 + Shield T3 x1 | T3 첫 Overload 또는 첫 Abort |
| `IAP_INTERSTELLAR_PACK` | Interstellar Operations Pack | $14.99 | Shield T5 x1 + Trajectory Surge x2 + 전용 칭호 | T5 첫 진입 |
| `IAP_WEEKLY_DEAL` | Weekly Deal | $4.99~$9.99 | 매주 자동 회전, 한정 75% 할인 번들 | 매 일요일 갱신 |
| `IAP_ZONE_UNLOCK_PACK` | Zone Unlock Pack | $9.99~$29.99 | 특정 Zone 모든 목적지 +50% 보상 영구 | Zone 첫 진입 |

## 3.5 데이터 구조 (모든 IAP 공통)

```gdscript
# GameState 또는 IAPService 내부
{
    "purchases": {
        "non_consumable": ["IAP_VIP", "IAP_AUTO_LAUNCH_PASS"],   # 영수증 검증된 영구 소유
        "consumable_log": [                                       # 멱등성 가드 (transaction_id 중복 방지)
            { "transaction_id": "...", "product_id": "IAP_BOOST_2X", "purchased_at": 1714000000 }
        ]
    },
    "active_boosts": {                                            # 활성 부스트 만료 시각 (Unix)
        "boost_2x_expire_at": 1714003600,
        "auto_fuel_expire_at": 1714003600,
        "trajectory_surge_expire_at": 0
    },
    "shield_inventory": {                                         # 보유 Shield (소모 시 차감)
        "shield_t3": 1, "shield_t4": 0, "shield_t5": 0
    },
    "purge_inventory": 0
}
```

## 3.6 클라이언트 로직 (`scripts/services/iap_service.gd`)

- `purchase(product_id)`: 플랫폼 IAP API 호출 → 영수증 수령
- `verify_receipt(receipt) -> bool`: 클라이언트 단독 검증 (Apple StoreKit Receipt Validation, Google Play Billing 영수증 검증). 멱등성 가드로 중복 처리 방지.
- `apply_purchase(product_id)`: 검증 통과 시 효과 적용 + `EventBus.iap_purchased` 발화
- `restore_purchases()`: 영구 IAP 복원 (앱 재설치 / 디바이스 변경 대응)

## 3.7 플랫폼 통합 (Godot 4.6)

### Android — Google Play Billing
- 플러그인 (둘 중 택 1):
  - **권장**: `godot-android-plugin-google-play-billing` (커뮤니티 메인테넌스)
  - 또는 직접 GDExtension 작성
- 영수증: `purchase.purchaseToken` + `productId` + `orderId` 저장
- 검증: `BillingClient.acknowledgePurchase()` (3일 내 acknowledge 필수, 미수행 시 자동 환불)

### iOS — Apple StoreKit
- 플러그인: `godot-ios-plugins`의 `inappstore` 모듈
- 영수증: `transactionReceipt` (Base64) 저장
- 검증: 로컬 영수증 검증 + 옵션으로 Apple `verifyReceipt` 엔드포인트 호출 (서버 필요 X, 클라이언트가 직접 가능)

### 공통 가드
- 영수증 위변조 방지: `transaction_id`를 `consumable_log`에 저장 → 동일 ID 재처리 거부
- 오프라인 결제 큐: 영수증 검증 실패 시 로컬 큐에 저장 → 다음 온라인 시 재시도

---

# 4. Mobile Channel B — Rewarded Ads

## 4.1 광고 SDK

| 항목 | 선택 |
|---|---|
| SDK | **AdMob** (Google) — `godot-admob` 플러그인 |
| 광고 형식 | Rewarded Video Ad (선택적, 30초 내외) |
| 미디에이션 | V2에서 Meta Audience Network / AppLovin 추가 검토 |

## 4.2 삽입 지점별 사양

### 4.2.1 Abort 화면 광고

| 항목 | 값 |
|---|---|
| 트리거 | Abort 발생 시 |
| 보상 | 수리비 50% 환불 |
| 일일 한도 | 3회 |
| UI 위치 | Abort 화면 하단, Shield 구매 버튼 옆 |
| 버튼 텍스트 | "광고 시청 → 수리비 50% 환불" |

### 4.2.2 Win 화면 광고

| 항목 | 값 |
|---|---|
| 트리거 | 목적지 완료 시 |
| 보상 | 해당 목적지 보상 +50% (Credit + TechLevel) |
| 일일 한도 | 5회 |
| UI 위치 | Win 화면 보상 요약 아래 |
| 버튼 텍스트 | "광고 시청 → 보상 +50%" |

### 4.2.3 일일 보상 광고

| 항목 | 값 |
|---|---|
| 트리거 | 일일 보상 수령 시 |
| 보상 | 일일 Credit 보상 2배 (부스터 제외) |
| 일일 한도 | 1회 |
| UI 위치 | DailyRewardModal "Claim" 버튼 옆 |

### 4.2.4 Auto-Fuel 충전 광고

| 항목 | 값 |
|---|---|
| 트리거 | Auto Fuel 만료 직후 |
| 보상 | Auto Fuel 5분 추가 |
| 일일 한도 | 4회 |
| UI 위치 | Auto Launch HUD 인라인 버튼 |

## 4.3 데이터 구조

```gdscript
# GameState
{
    "ad_reward_state": {
        "date": "2026-04-24",
        "counts": { "abort": 0, "win": 0, "daily": 0, "auto_fuel": 0 }
    }
}
```

매일 00:00 (로컬 시각) 자동 리셋.

## 4.4 운영 규칙

1. 모든 광고는 **선택적(opt-in)**. 강제 광고 없음.
2. **13세 미만 유저에게는 광고 버튼 미표시** (앱 시작 시 연령 게이트 → COPPA / GDPR-K 준수).
3. 일일 한도 초과 시 버튼 비활성화 (횟수 표시).
4. 광고 로드 실패 시 버튼 숨김 (에러 미표시).
5. **VIP 보유 시 광고 자체 제거** — 광고 버튼 미표시 및 UX 단순화.

---

# 5. Mobile Channel C — Subscription

## 5.1 상품 정의

| 항목 | 값 |
|---|---|
| 상품명 | Orbital Operations Pass |
| 가격 | **$4.99/월** (Apple/Google 표준 월 구독 가격대) |
| 무료 체험 | 첫 7일 무료 (Apple/Google 표준 정책 활용) |
| 노출 조건 | T3 진입 |

## 5.2 혜택 정의

| 혜택 | 수량 | 주기 |
|---|---|---|
| 광고 완전 제거 | 상시 | — |
| 일일 2x Boost (15min) | 1회 | 일일 |
| 주간 System Purge | 2회 | 주간 (월요일 00:00 리셋) |
| 월간 Trajectory Surge | 4회 | 월간 (1일 00:00 리셋) |
| 일일 미션 +1개 슬롯 | 상시 | — |
| 구독 전용 칭호 | 1종 | 상시 |
| 일일 보상 +25% Credit | 상시 | — |

### 혜택에 넣지 않는 것 (다른 IAP 보호)

| 제외 항목 | 이유 |
|---|---|
| XP 상시 배율 | VIP IAP ($2.99) 구매 동기 보호 |
| 성공 확률 상시 보정 | Guidance Module ($5.99) 구매 동기 보호 |
| Abort 무제한 방어 | Shield IAP ($2.99~$9.99) 반복 구매 보호 |
| Auto Launch 속도 캡 해제 | Auto Launch Pass ($4.99) 구매 동기 보호 |

## 5.3 데이터 구조

```gdscript
{
    "subscription": {
        "active": false,
        "tier": "orbital_ops",
        "purchase_token": "",
        "next_renewal_at": 0,
        "expire_at": 0,
        "daily_boost_claimed_date": "",
        "weekly_purge_remaining": 2,
        "weekly_purge_reset_at": 0,
        "monthly_surge_remaining": 4,
        "monthly_surge_reset_at": 0
    }
}
```

## 5.4 클라이언트 로직 (`scripts/services/subscription_service.gd`)

- `is_active() -> bool`: 만료 시각 검증 + 영수증 유효성
- `claim_daily_boost(player)`: 오늘 미수령 시 15분 2x Boost 활성화
- `claim_weekly_purge(player)`: 주간 잔량에서 차감 → Purge 인벤토리 +1
- `claim_monthly_surge(player)`: 월간 잔량에서 차감 → Surge 인벤토리 +1
- `verify_subscription_status()`: 앱 진입 시 / 24시간 주기로 영수증 유효성 검증

## 5.5 플랫폼 통합

- **Android**: Google Play Billing의 `subscriptionPurchase` API. 자동 갱신 영수증 추적.
- **iOS**: StoreKit `SKPaymentQueue` + `originalTransactionIdentifier`로 자동 갱신 추적.
- 구독 취소 / 일시 정지 / 갱신 실패는 **다음 진입 시 영수증 재검증**으로 감지 → 비활성화.

---

# 6. Mobile Channel D — Battle Pass (Season Pass)

## 6.1 상품 정의

| 항목 | 값 |
|---|---|
| 시즌 길이 | 3개월 (분기) |
| 무료 패스 | 모든 유저 자동 진입 |
| 프리미엄 패스 | $9.99 (시즌 시작일 14일간 30% 할인 $6.99) |
| 노출 조건 | T1 완료 |

## 6.2 보상 구조

총 50 티어 × (Free / Premium 양 트랙).

| 보상 종류 | Free 트랙 | Premium 트랙 |
|---|---|---|
| Credit | 합산 약 1,500 C | 합산 약 6,000 C |
| Booster (2x Boost / Auto Fuel / Surge) | 5개 | 25개 |
| 코스메틱 (트레일 / 발사대 스킨) | 2종 | 12종 |
| 시즌 칭호 | 1종 (50 티어 달성 시) | 3종 (티어별) |
| 마일스톤 사전 렌더 영상 (한정 컷) | — | 1종 (해당 시즌 테마) |

## 6.3 티어 진행

- **시즌 XP** (`season_xp`) 누적으로 진행
- 획득 경로: 일일 미션 / 주간 미션 / 목적지 완료 / 시즌 챌린지

## 6.4 데이터 구조

```gdscript
{
    "season": {
        "current_season_id": "S01_LUNAR",
        "season_xp": 0,
        "current_tier": 0,
        "premium_owned": false,
        "claimed_tiers_free": [],
        "claimed_tiers_premium": [],
        "season_start_at": 0,
        "season_end_at": 0
    }
}
```

---

# 7. Steam Channel A — Standard Edition + Deluxe

## 7.1 본편 (Premium 1회 구매)

| 항목 | 값 |
|---|---|
| Steam App ID | (Steamworks 등록 시 발급) |
| Standard Edition | **$14.99 USD** (지역별 권장가 적용) |
| Deluxe Edition | $24.99 USD (스킨팩 + OST + 아트북 PDF) |
| 광고 / 가챠 | **없음** (PC 게이머 문화 대응) |

## 7.2 지역별 권장 가격 (Steam Regional Pricing)

| 지역 | 통화 | Standard | Deluxe |
|---|---|---|---|
| 한국 | KRW | ₩18,000 | ₩30,000 |
| 일본 | JPY | ¥1,980 | ¥3,300 |
| 중국 | CNY | ¥60 | ¥98 |
| EU | EUR | €13.99 | €22.99 |
| 영국 | GBP | £11.99 | £19.99 |
| 러시아 | RUB | ₽799 | ₽1,299 |

## 7.3 Steam Cloud Save

- 자동 동기화 대상: `user://savegame.json`
- Steamworks Build Settings → Cloud → Auto-Cloud 패턴: `*.json` 등록
- 충돌 발생 시 (다중 기기) **최신 timestamp 자동 채택** + 백업 보관

## 7.4 Steam Achievements

100개 목적지 1:1 매핑 + 메타 도전:

| Achievement ID | 설명 | 트리거 |
|---|---|---|
| `KARMAN_LINE` | 카르만 선 돌파 (D_03) | 첫 도달 시 `EventBus.destination_completed` |
| `MOON_LANDING` | 고요의 바다 도달 (D_13) | 첫 도달 |
| `MARS_OLYMPUS` | 올림푸스 산 도달 (D_24) | 첫 도달 |
| `SAGITTARIUS_A` | 궁수자리 A* 도달 (D_103) | 첫 도달 (엔딩) |
| ... (+95개 목적지) | ... | ... |
| `ZERO_FAILURE_T1` | T1 무실패 클리어 | LaunchService 통계 |
| `100K_LAUNCHES` | 누적 10만 발사 | GameState |
| ... (+10개 메타) | ... | ... |

총 100 + 14 = 114개. Steamworks Achievements 페이지에서 등록.

---

# 8. Steam Channel B — DLC

## 8.1 시즌 확장 DLC

| Key | 상품명 | 가격 | 컨텐츠 | 출시 시점 |
|---|---|---|---|---|
| `DLC_INTERSTELLAR_FRONTIER` | Interstellar Frontier | $7.99 | 신규 Zone 5개 (시리우스, 베가, 오리온 성운 등 추가 목적지 25개) | V1 출시 후 6개월 |
| `DLC_DEEP_SPACE_EDGE` | Deep Space Edge | $7.99 | 신규 Zone 5개 (퀘이사, 안드로메다 외곽 등) | V1 출시 후 12개월 |

## 8.2 코스메틱 DLC

| Key | 상품명 | 가격 |
|---|---|---|
| `DLC_ROCKET_SKINS_PACK_1` | Rocket Skin Pack: Cyberpunk | $2.99 |
| `DLC_ROCKET_SKINS_PACK_2` | Rocket Skin Pack: Retro Soviet | $2.99 |
| `DLC_LAUNCHPAD_THEMES` | Launch Pad Themes Pack | $2.99 |
| `DLC_TRAIL_FX_PACK` | Trail FX Pack (Plasma / Rainbow / Wormhole) | $2.99 |

## 8.3 Supporter DLC

| Key | 상품명 | 가격 |
|---|---|---|
| `DLC_OST` | Original Soundtrack | $4.99 |
| `DLC_ARTBOOK` | Digital Artbook (PDF) | $4.99 |
| `DLC_SUPPORTER_PACK` | Supporter Pack (OST + Artbook + 크레딧 등재) | $9.99 |

## 8.4 Steam DLC 통합 (Godot)

- `addons/godotsteam`의 `Steam.isDLCInstalled(app_id)` API 활용
- 게임 시작 시 DLC 보유 체크 → 컨텐츠 활성화
- Standard Edition만 구매한 유저에게도 DLC 컨텐츠는 게임 내에서 미리보기 가능 (구매 CTA 노출)

---

# 9. Daily Reward + Daily Mission (양 플랫폼 공통)

> 일일 복귀 + 세션 시간 연장이 핵심 리텐션 메커니즘. Mobile / Steam 모두에 적용.

## 9.1 Daily Reward

| 항목 | 값 |
|---|---|
| 보상 주기 | 24시간 (디바이스 로컬 자정 기준) |
| 스트릭 리셋 | 48시간 미접속 시 Day 1로 리셋 |
| 수령 조건 | 진입 후 자동 또는 모달 1회 클릭 |

### 일일 보상 테이블

| Day | 보상 | 비고 |
|---|---|---|
| 1 | 5 Credit | 기본 |
| 2 | 8 Credit | |
| 3 | 10 Credit + 15분 2x Boost | 세션 연장 유도 |
| 4 | 12 Credit | |
| 5 | 15 Credit | |
| 6 | 18 Credit + 15분 2x Boost | |
| 7 | 25 Credit + 30분 2x Boost + 칭호 `Weekly Explorer` | 주간 정점 |

### 데이터 구조

```gdscript
{
    "daily_reward": {
        "last_claim_date": "2026-04-23",
        "streak": 3,
        "claimed_today": false
    }
}
```

### 클라이언트 로직 (`scripts/services/daily_reward_service.gd`)

- `can_claim() -> bool`: `last_claim_date != Time.get_date_string_from_system()`
- `claim()`: streak 증가 (7 초과 시 1로 순환), 보상 지급, 날짜 갱신
- `get_streak_info() -> Dictionary`: 현재 streak / 오늘 보상 / 수령 여부

### UI

- `scenes/ui/daily_reward_modal.tscn` — 진입 시 미수령이면 자동 팝업
- 7일 보상 미리보기 (현재 일차 강조)
- "Claim" 버튼 → 보상 수령 애니메이션
- 첫 접속 5분 이내 / T1 미완료 유저에게는 표시 X

## 9.2 Daily Mission

| 항목 | 값 |
|---|---|
| 미션 수 | 3개/일 (구독자 +1 = 4개) |
| 리셋 주기 | 매일 00:00 디바이스 로컬 |
| 보상 | TechLevel (주간 캡과 별도 일일 캡 50) |

### 일일 미션 풀

| 미션 ID | 조건 | 보상 |
|---|---|---|
| `DM_LAUNCH_20` | 20회 발사 | 10 TechLevel |
| `DM_SUCCESS_3` | 3회 목적지 완료 | 15 TechLevel |
| `DM_STAGE_5_STREAK` | 5연속 단계 클리어 | 10 TechLevel |
| `DM_FACILITY_UPGRADE_1` | Facility 1회 업그레이드 | 10 TechLevel |
| `DM_PLAY_10M` | 10분 이상 플레이 | 15 TechLevel |
| `DM_AUTO_LAUNCH_5M` | Auto Launch 5분 사용 | 10 TechLevel |
| `DM_NEW_DESTINATION` | 신규 목적지 1개 도달 | 20 TechLevel |

매일 위 풀에서 **3개 랜덤 선택** (중복 없음).

### 데이터 구조

```gdscript
{
    "daily_mission": {
        "date": "2026-04-23",
        "missions": [
            { "id": "DM_LAUNCH_20", "progress": 12, "claimed": false },
            { "id": "DM_SUCCESS_3", "progress": 1, "claimed": false },
            { "id": "DM_STAGE_5_STREAK", "progress": 0, "claimed": false }
        ],
        "daily_tech_level_earned": 0
    }
}
```

---

# 10. 메타 보너스 풀 (싱글 메커니즘)

소셜 의존이 없는 싱글 게임에서 같은 "지속 동기" 효과를 위한 메커니즘.

| 메커니즘 | 보상 | 세부 |
|---|---|---|
| **로그인 스트릭** | Day 1~7 누적 보상 | §9.1 |
| **누적 플레이타임** | 100시간 / 500시간 / 1000시간 영구 칭호 | `total_play_time_sec` 기준 |
| **도감 진행도** | Codex 25% / 50% / 75% / 100% 보너스 (Credit + 코스메틱) | `DiscoveryService.completion_ratio` |
| **시즌 컬렉션** | 시즌 한정 트레일 / 발사대 / 칭호 (분기별) | Battle Pass와 별도 |
| **첫도달 마일스톤** | 마일스톤 영상 (10/25/50/75/100) + Credit 대량 보너스 | `EventBus.destination_completed` 카운트 |
| **Region Mastery** | 지역 모든 목적지 클리어 시 칭호 + Credit 대량 보너스 | `RegionMasteryConfig.tres` |

---

# 11. 노출 조건 총정리

## 11.1 진행도 기반 노출 매트릭스

| 상품/기능 | 조건 | 검사 필드 |
|---|---|---|
| VIP / Auto Launch Pass | T1 완료 | `highest_completed_tier >= 1` |
| Guidance Module | T2 진입 | `highest_completed_tier >= 2` |
| 2x Boost / Auto Fuel | T1 완료 | `highest_completed_tier >= 1` |
| Trajectory Surge | T2 진입 | `highest_completed_tier >= 2` |
| Shield T3 / Purge | T3 진입 | `highest_completed_tier >= 3` |
| Shield T4 | T3 진입 | `highest_completed_tier >= 3` |
| Shield T5 | T4 진입 | `highest_completed_tier >= 4` |
| Subscription (Orbital Ops Pass) | T3 진입 | `highest_completed_tier >= 3` |
| Battle Pass | T1 완료 | `highest_completed_tier >= 1` |
| Daily Reward / Mission | T1 완료 | `highest_completed_tier >= 1` |
| Credit Pack S | T2 진입 | `highest_completed_tier >= 2` |
| Credit Pack M | T3 진입 | `highest_completed_tier >= 3` |
| Credit Pack L | T4 진입 | `highest_completed_tier >= 4` |
| Abort 광고 | T3+ Abort 발생 시 | (자동) |
| Win 광고 | 목적지 완료 시 | (자동) |

## 11.2 UI 노출 빈도 규칙

| 규칙 | 적용 대상 |
|---|---|
| 첫 접속 5분 내 BM 모달 금지 | 전체 |
| 같은 상품 2회 연속 닫으면 7일 재노출 금지 | 모달형 BM |
| 세션당 강한 BM 모달 최대 2회 | 모달형 BM |
| Stress 관련 상품은 Stress > 0일 때만 | Purge, Shield |
| 광고 버튼은 일일 한도 초과 시 숨김 | 광고 전체 |
| **VIP 보유 시 광고 / VIP CTA 완전 비표시** | 광고, VIP IAP CTA |

---

# 12. 개발 순서 총정리

## Phase 0 — 기반 정비 (Foundation)

| # | 작업 | 파일 | 우선도 |
|---|---|---|---|
| 0-1 | Auto Launch 무료 해금 | `auto_launch_service.gd` | P0 |
| 0-2 | Auto Fuel 속도 반영 | `auto_launch_service.gd` | P0 |
| 0-3 | IAP 영수증 검증 인프라 | `iap_service.gd` (공통 베이스) | P0 |

## Phase 1 — Mobile 핵심 IAP

| # | 작업 | 신규/수정 | 우선도 |
|---|---|---|---|
| 1-1 | Google Play Billing 플러그인 통합 | Godot Android 플러그인 | P0 |
| 1-2 | StoreKit 플러그인 통합 | Godot iOS 플러그인 | P0 |
| 1-3 | IAP 상품 정의 (`IAP_*` 13개) | `data/iap_config.tres` | P0 |
| 1-4 | DailyRewardService + Modal | 신규 서비스 + UI | P1 |
| 1-5 | DailyMissionService 확장 | 수정 | P1 |
| 1-6 | Mission Panel 일일 미션 섹션 | 수정 | P1 |

## Phase 2 — Mobile 보조 채널

| # | 작업 | 신규/수정 | 우선도 |
|---|---|---|---|
| 2-1 | AdMob 플러그인 통합 + 광고 단위 등록 | Godot Android/iOS 플러그인 | P1 |
| 2-2 | Abort 광고 버튼 | 수정 | P1 |
| 2-3 | Win 광고 버튼 | 수정 | P1 |
| 2-4 | SubscriptionService 구현 | 신규 서비스 | P2 |
| 2-5 | Subscription UI | 신규 UI | P2 |
| 2-6 | Battle Pass 시스템 (시즌 XP / 트랙 / 보상) | 신규 시스템 | P2 |

## Phase 3 — Steam

| # | 작업 | 신규/수정 | 우선도 |
|---|---|---|---|
| 3-1 | GodotSteam 통합 (이미 `addons/godotsteam` 설치됨) | 검증 | P0 |
| 3-2 | Steam Cloud Save 설정 | Steamworks 백오피스 | P0 |
| 3-3 | Steam Achievements 114개 등록 + 트리거 | Steamworks + 코드 | P1 |
| 3-4 | Steam Microtransactions (DLC) 등록 | Steamworks 백오피스 | P1 |
| 3-5 | DLC 보유 검증 + 컨텐츠 활성화 | `dlc_service.gd` (신규) | P1 |
| 3-6 | Steam Deck 호환 인증 | 빌드 검증 | P2 |

## Phase 4 — 메타 보너스 / 컬렉션

| # | 작업 | 신규/수정 | 우선도 |
|---|---|---|---|
| 4-1 | 누적 플레이타임 칭호 | `meta_bonus_service.gd` | P2 |
| 4-2 | 도감 진행도 보너스 | 수정 (`discovery_service.gd`) | P2 |
| 4-3 | 시즌 컬렉션 | 신규 시즌 시스템 | P3 |

## Phase 5 — 확장

| # | 작업 | 신규/수정 | 우선도 |
|---|---|---|---|
| 5-1 | Steam Workshop (V2) | 신규 | P3 |
| 5-2 | Battle Pass 시즌 2 / 3 콘텐츠 | 콘텐츠 | P3 |
| 5-3 | Expansion DLC (Interstellar Frontier) | 콘텐츠 + DLC 등록 | P3 |

---

# 13. 채널 간 역할 분리 (개발 시 참조)

개발 중 기능 추가 시 아래 규칙을 위반하지 않도록 확인:

| 규칙 | 보호 대상 |
|---|---|
| 구독에 XP 상시 배율 넣지 않음 | VIP IAP ($2.99) |
| 구독에 확률 보정 넣지 않음 | Guidance Module ($5.99) |
| 구독에 Abort 무제한 방어 넣지 않음 | Shield IAP ($2.99~$9.99) |
| 구독에 속도 캡 해제 넣지 않음 | Auto Launch Pass ($4.99) |
| TechLevel 직접 판매 IAP 만들지 않음 | 단조 증가축 P2W 방어선 |
| Steam에 광고 / 가챠 넣지 않음 | PC 게이머 문화 |
| 모바일에 $30 이상 단일 IAP 만들지 않음 | 결제 심리 저항선 |

**구독의 역할**: 기존 IAP의 소형 무료 샘플을 매일/매주 제공 → 추가 구매 유도. 대체가 아닌 촉진.

---

# 14. 관련 문서

- `docs/prd.md` — 핵심 게임 사양 (PRD)
- `docs/design/game_overview.md` §7 — 수익 모델 개요
- `docs/post_landing_bm_plan.md` — Stage A~D 단계별 BM 노출 전략
- `docs/launch_balance_design.md` — 확률 / 보상 곡선 (Shield / Purge / Surge 효과 계산 근거)
- `docs/systems/7-1-gamepass.md`, `7-2-developer-product.md` — 시스템 카탈로그 상세 (Godot 매핑)
