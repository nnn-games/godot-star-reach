# 7-1. 영구형 IAP — Mobile Non-Consumable + Steam Edition DLC

> 카테고리: Monetization
> 정본 문서: `docs/bm.md` §3.1 (Mobile 영구형 IAP), §7 (Steam Standard / Deluxe)
> 구현: `scripts/services/iap_service.gd` (영구형 분기), `scripts/services/dlc_service.gd` (Steam Edition), `data/iap_config.tres`, `data/dlc_config.tres`

## 1. 시스템 개요

플랫폼별 영구 소유 방식의 BM 상품을 정의한다.

- **Mobile (Android Google Play Billing / iOS Apple StoreKit)**: Non-Consumable IAP 3종. 한 번 구매하면 계정에 영구 귀속, 재설치 시 `restore_purchases()`로 복원.
- **Steam (GodotSteam)**: Standard Edition 1회 구매 + Deluxe Edition (Standard + 코스메틱 + OST + 아트북 PDF). 본편은 Steamworks 등록 시 App ID로 식별, Deluxe는 별도 SKU 또는 Edition Upgrade DLC로 구성.

`IAPService.is_purchased(product_id)`를 세션 캐시로 래핑해 반복 조회를 최적화한다. 효과 적용은 각 활성 시스템(`LaunchService`, `AutoLaunchService` 등)이 `IAPService.has_*()` 호출로 분기한다.

**책임 경계**
- 영구 IAP / DLC 소유 여부 조회 + 세션 캐시.
- 영수증 검증 (Apple StoreKit / Google Play Billing 클라이언트 단독, Steam은 ownership API).
- 각 IAP의 효과 값 제공 (`IAP_VIP_XP_MULT`, `IAP_GUIDANCE_BONUS` 등).
- 진행도(`highest_completed_tier`) 기반 노출 필터링.

**책임 아닌 것**
- 실제 효과 적용(→ 각 시스템이 직접 호출).
- 구매 UI(→ `scenes/ui/shop_panel.tscn`).
- 소모형 IAP(→ 7-2).

## 2. 코어 로직

### 2.1 카탈로그 — 영구형 IAP (Mobile, 3종)

| Key | 상품명 | 가격 (USD) | 효과 | 노출 조건 |
|---|---|---|---|---|
| `IAP_VIP` | VIP | $2.99 | XP 2배 영구 + 광고 제거 | T1 완료 |
| `IAP_AUTO_LAUNCH_PASS` | Auto Launch Pass | $4.99 | +0.35 launches/s 영구 | T1 완료 |
| `IAP_GUIDANCE_MODULE` | Guidance Module | $5.99 | +5%p 기본 성공 확률 영구 | T2 진입 |

### 2.2 카탈로그 — Steam Edition

| Key | 상품명 | 가격 (USD) | 구성 |
|---|---|---|---|
| `STEAM_STANDARD_EDITION` | StarReach Standard | $14.99 | 본편 (광고/가챠 없음) |
| `STEAM_DELUXE_EDITION` | StarReach Deluxe | $24.99 | 본편 + Rocket Skin Pack + Launch Pad Themes + Trail FX Pack + OST + 아트북 PDF |

> Steam의 코스메틱/시즌 확장 DLC는 7-2에서 다룬다. 여기서는 본편(Standard/Deluxe) 구분만 한다.

### 2.3 소유 조회 + 세션 캐시 (`IAPService.is_purchased`)

```gdscript
func is_purchased(product_id: String) -> bool:
    if _session_cache.has(product_id):
        return _session_cache[product_id]
    var owned: bool = product_id in GameState.purchases.non_consumable
    _session_cache[product_id] = owned
    return owned
```

캐시 무효화: `EventBus.iap_purchased` 시그널을 받으면 해당 키만 제거 → 다음 조회 때 재계산. 구매 즉시 반영을 보장한다.

### 2.4 효과 적용 call site

| IAP Key | 호출 위치 | 효과 |
|---|---|---|
| `IAP_VIP` | `IAPService.get_xp_mult()` | `mult *= 2.0` → XP 합산에서 곱 |
| `IAP_VIP` | `AdService.should_show_ad()` | 항상 `false` 반환 → 광고 버튼 숨김 |
| `IAP_GUIDANCE_MODULE` | `IAPService.get_guidance_bonus()` → `LaunchService.get_upgrade_chance_bonus()` | 성공률 +5%p 가산 |
| `IAP_AUTO_LAUNCH_PASS` | `AutoLaunchService.get_rate()` | `rate += 0.35` |
| `STEAM_DELUXE_EDITION` | `DLCService.is_cosmetic_unlocked()` | 코스메틱 4종 자동 활성화 |

### 2.5 `get_xp_mult` (VIP + 시간제 Boost 결합)

```gdscript
func get_xp_mult() -> float:
    var mult: float = 1.0
    if is_purchased("IAP_VIP"):
        mult *= 2.0                               # 영구
    if has_active_boost("boost_2x"):
        mult *= 2.0                               # 30분 소모형 IAP (→ 7-2)
    return mult                                   # 최대 4x
```

> VIP와 2x Boost 동시 활성 → **4x XP**. 이 결합이 설계 의도(`docs/bm.md` §13).

### 2.6 `get_guidance_bonus` (+ Trajectory Surge)

```gdscript
func get_guidance_bonus() -> float:
    var bonus: float = 0.0
    if is_purchased("IAP_GUIDANCE_MODULE"):
        bonus += 0.05                             # 영구
    bonus += get_trajectory_surge_bonus()         # 30분 소모형 IAP (+0.03)
    return bonus                                  # 최대 +8%p
```

### 2.7 진행도 기반 노출 (`required_tier`)

UI(`shop_panel.tscn`)는 `iap_config.tres`의 `required_tier` 필드로 현재 `GameState.highest_completed_tier` 미만이면 카드 자체를 숨긴다.

- T0 (튜토리얼 진행 중): 영구형 IAP 모두 비표시
- T1 완료: VIP, Auto Launch Pass 카드 노출
- T2 진입: Guidance Module 카드 추가 노출

### 2.8 영수증 검증 (클라이언트 단독)

| 플랫폼 | 검증 방법 |
|---|---|
| Android | `BillingClient.acknowledgePurchase(purchaseToken)` (3일 내 acknowledge 미수행 시 자동 환불) |
| iOS | StoreKit `transactionReceipt` 로컬 검증 + 옵션으로 Apple `verifyReceipt` 직접 호출 |
| Steam | `Steam.isSubscribedApp(app_id)` / `Steam.isDLCInstalled(dlc_id)` |

영수증 위변조 가드: `transaction_id`를 `consumable_log` 또는 `non_consumable` 배열에 기록 → 동일 ID 재처리 거부 (멱등성).

### 2.9 복원 (`restore_purchases`)

앱 재설치 / 디바이스 변경 시 호출. 플랫폼 API에서 사용자가 과거 구매한 Non-Consumable 목록을 가져와 `GameState.purchases.non_consumable`에 머지하고 `_session_cache`를 비운다. Steam은 `Steam.isSubscribedApp` 결과로 자동 인식되므로 별도 복원 절차가 불필요하다.

## 3. 정적 데이터 (Config)

### `data/iap_config.tres` (영구형 섹션)

```
products = [
    { key = "IAP_VIP", price_usd = 2.99, kind = "non_consumable",
      effect = "xp_mult_2x_permanent", required_tier = 1, hidden = false },
    { key = "IAP_AUTO_LAUNCH_PASS", price_usd = 4.99, kind = "non_consumable",
      effect = "auto_launch_rate_+0.35", required_tier = 1, hidden = false },
    { key = "IAP_GUIDANCE_MODULE", price_usd = 5.99, kind = "non_consumable",
      effect = "success_chance_+0.05", required_tier = 2, hidden = false },
]
display_order = ["IAP_VIP", "IAP_AUTO_LAUNCH_PASS", "IAP_GUIDANCE_MODULE"]
```

### `data/dlc_config.tres` (Steam Edition 섹션)

```
editions = [
    { key = "STEAM_STANDARD_EDITION", app_id = <Steam App ID>, price_usd = 14.99 },
    { key = "STEAM_DELUXE_EDITION", dlc_id = <Edition Upgrade DLC ID>, price_usd = 24.99,
      includes = ["DLC_ROCKET_SKINS_PACK_1", "DLC_LAUNCHPAD_THEMES",
                  "DLC_TRAIL_FX_PACK", "DLC_OST", "DLC_ARTBOOK"] }
]
```

### 효과 값 상수 (`scripts/services/iap_service.gd`)

```gdscript
const IAP_VIP_XP_MULT: float = 2.0
const IAP_GUIDANCE_BONUS: float = 0.05
const IAP_AUTO_LAUNCH_BONUS: float = 0.35
```

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

```gdscript
{
    "version": 1,
    "purchases": {
        "non_consumable": ["IAP_VIP", "IAP_AUTO_LAUNCH_PASS"],
        "transaction_ids": {
            "IAP_VIP": "GPA.1234-5678-...",
            "IAP_AUTO_LAUNCH_PASS": "GPA.2345-6789-..."
        }
    }
}
```

> Steam Standard/Deluxe 소유는 `Steam.isSubscribedApp` / `Steam.isDLCInstalled`로 매번 조회하므로 저장하지 않는다 (런타임 캐시만).

## 5. 런타임 상태

`IAPService._session_cache`:

```gdscript
{
    "IAP_VIP": true,
    "IAP_AUTO_LAUNCH_PASS": true,
    "IAP_GUIDANCE_MODULE": false
}
```

세션 한정. `EventBus.iap_purchased` 발화 시 해당 키만 무효화.

## 6. 시그널 (EventBus)

| Signal | 인자 | 발화 시점 |
|---|---|---|
| `iap_purchased` | `(product_id: String, transaction_id: String)` | 영수증 검증 통과 후 |
| `iap_restored` | `(product_ids: Array)` | `restore_purchases()` 완료 시 |
| `dlc_installed` | `(dlc_id: String)` | Steam DLC 설치 감지 시 (`Steam.dlc_installed` 콜백) |

## 7. 의존성

**의존**:
- `GameState` (저장 데이터 읽기/쓰기)
- 플랫폼 IAP 어댑터 (`scripts/services/platform/google_play_billing.gd`, `apple_storekit.gd`, `steam_iap.gd`)

**의존받음**:
- `LaunchService.get_upgrade_chance_bonus()` — `get_guidance_bonus()`
- `LaunchService.launch_rocket()` — `get_xp_mult()` (XP 합산)
- `AutoLaunchService.get_rate()` — `is_purchased("IAP_AUTO_LAUNCH_PASS")`
- `AdService.should_show_ad()` — `is_purchased("IAP_VIP")`
- `scenes/ui/shop_panel.tscn` — 카드 표시 + 구매 호출

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/iap_service.gd` | 영구형/소모형 통합 베이스 (소유 판정, 효과 제공) |
| `scripts/services/dlc_service.gd` | Steam Edition / DLC 보유 검증 |
| `scripts/services/platform/google_play_billing.gd` | Android 어댑터 |
| `scripts/services/platform/apple_storekit.gd` | iOS 어댑터 |
| `scripts/services/platform/steam_iap.gd` | GodotSteam 래퍼 |
| `data/iap_config.tres` | 영구형 IAP 정의, 효과 값 |
| `data/dlc_config.tres` | Steam Standard / Deluxe 구성 |
| `scenes/ui/shop_panel.tscn` | IAP 카드 UI |

## 9. 알려진 이슈 / 설계 주의점

1. **Acknowledge 누락 → 자동 환불 (Android)**: Google Play Billing은 구매 후 3일 내 `acknowledgePurchase()` 호출이 없으면 자동 환불 처리한다. `apply_purchase()` 마지막 단계에서 반드시 호출.
2. **iOS Sandbox 영수증 vs Production**: 개발/리뷰 시 sandbox 영수증, 출시 후 production 영수증. 검증 엔드포인트가 다르므로 `Apple.verifyReceipt` 호출 시 두 환경 모두 시도해야 한다.
3. **Steam Deluxe Edition 구성 방식**: Steamworks에서 두 가지 옵션 — (a) 별도 SKU로 발매, (b) Standard + Deluxe Upgrade DLC로 구성. 이 문서는 (b)안 (Edition Upgrade DLC)을 가정. `dlc_config.tres`의 `dlc_id`를 사용.
4. **VIP의 2x XP 배율은 설계 상한**: `docs/bm.md` §13 "구독에 XP 상시 배율 넣지 않음"으로 VIP의 2x 배타성을 보호. Subscription(→ 7-4) 구현 시 절대 위반 금지.
5. **Guidance Module vs LaunchTech Engine Precision**: 둘 다 성공률 보정이지만 성질이 다르다. Engine Precision(세션, 20레벨 최대 +40%p) vs Guidance Module(영구, +5%p). 합산은 `LaunchService.get_upgrade_chance_bonus()`에서 가산.
6. **`required_tier` 기반 노출 논리**: 신규 플레이어에게는 영구형 IAP 카드 자체가 보이지 않음 → 점진적 BM 노출로 초반 압박 방지. 첫 5분 모달 금지 규칙(`docs/bm.md` §11.2)과 일관성 유지.
7. **Steam 트랙은 Subscription / Battle Pass / 소모형 IAP 미적용**: Steam 유저는 Standard/Deluxe 1회 구매 후 코스메틱 DLC만 추가 구매. 영구형 IAP(VIP/Auto Launch Pass/Guidance Module)는 모바일 한정.
