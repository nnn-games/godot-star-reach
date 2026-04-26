# 7-2. 소모형 IAP — Mobile Consumable + Steam Cosmetic DLC

> 카테고리: Monetization
> 정본 문서: `docs/bm.md` §3.2~§3.4 (Mobile 소모형 / 화폐 팩 / 번들), §8 (Steam Cosmetic DLC)
> 구현: `scripts/services/iap_service.gd:_apply_consumable()`, `scripts/services/dlc_service.gd`, `data/iap_config.tres`, `data/dlc_config.tres`

## 1. 시스템 개요

1회성 구매로 즉시 효과를 받는 소모형 상품군과 Steam 코스메틱 DLC를 정의한다.

- **Mobile (Consumable)**: 30분~60분 시간제 부스트, Shield (Abort 환불), Stress Purge, Credit 팩, 진행도 기반 번들.
- **Steam Cosmetic DLC**: 로켓 스킨, 발사대 테마, 트레일 FX, OST 등 영구 소유 코스메틱.

영수증 처리는 플랫폼별 콜백을 단일 진입점 `IAPService.verify_receipt(receipt) -> bool`로 라우팅하며, **`transaction_id` 멱등성 가드**로 재전달 시 중복 지급을 방지한다.

**4개 카테고리** (Mobile):

| 카테고리 | 상품 | 효과 타입 |
|---|---|---|
| **Boost** | 2x Boost, Trajectory Surge, Auto Fuel | 시간제 (30~60분) |
| **Shield** | Launch Fail-safe T3/T4/T5 | 인벤토리 적립 → Abort 시 자동 소비 (수리비 면제) |
| **Purge** | System Purge | 즉시 Stress -30 |
| **Currency / Bundle** | Credit Pack S/M/L, Starter Pack 등 | Credit 즉시 지급 / 패키지 일괄 지급 |

**책임 경계**
- 플랫폼 영수증 → `verify_receipt` → `_apply_consumable` 단일 라우팅.
- `transaction_id` 멱등성 가드 (`consumable_log` 최대 200개 트림).
- 시간제 부스트 만료 추적 (Unix timestamp 기반, 영속).
- Steam DLC 보유 검증 후 코스메틱 활성화.

**책임 아닌 것**
- 구매 프롬프트 호출(→ UI 측에서 `IAPService.purchase()` 호출).
- 실제 잔고 증감(→ `EconomyService` 위임).

## 2. 코어 로직

### 2.1 카탈로그 — 시간제 Boost (3종)

| Key | 상품명 | 가격 (USD) | 효과 | 지속 | 노출 조건 |
|---|---|---|---|---|---|
| `IAP_BOOST_2X` | 2x Boost (30min) | $1.49 | XP 2배 | 1800s | T1 완료 |
| `IAP_TRAJECTORY_SURGE` | Trajectory Surge (30min) | $1.99 | +3%p 성공 확률 | 1800s | T2 진입 |
| `IAP_AUTO_FUEL` | Auto Fuel (60min) | $0.99 | +0.5 launches/s | 3600s | T1 완료 |

### 2.2 카탈로그 — Shield (3종, Abort 면제)

| Key | 상품명 | 가격 (USD) | 효과 | 노출 조건 |
|---|---|---|---|---|
| `IAP_SHIELD_T3` | Launch Fail-safe T3 | $2.99 | 다음 T3 Abort 수리비 면제 1회 | T3 진입 |
| `IAP_SHIELD_T4` | Launch Fail-safe T4 | $4.99 | 다음 T4 Abort 수리비 면제 1회 | T3 진입 |
| `IAP_SHIELD_T5` | Launch Fail-safe T5 | $9.99 | 다음 T5 Abort 수리비 면제 1회 | T4 진입 |

### 2.3 카탈로그 — Stress Purge

| Key | 상품명 | 가격 (USD) | 효과 | 노출 조건 |
|---|---|---|---|---|
| `IAP_SYSTEM_PURGE` | System Purge | $0.99 | Stress -30 즉시 | T3 진입 (Stress ≥ 50) |

### 2.4 카탈로그 — Credit 팩

| Key | 상품명 | 가격 (USD) | 지급량 | 노출 조건 |
|---|---|---|---|---|
| `IAP_CREDIT_S` | Credit Pack S | $0.99 | +500 Credit | T2 진입 |
| `IAP_CREDIT_M` | Credit Pack M | $4.99 | +3,000 Credit (+20% 보너스) | T3 진입 |
| `IAP_CREDIT_L` | Credit Pack L | $9.99 | +7,500 Credit (+50% 보너스) | T4 진입 |

> TechLevel 직접 판매 IAP는 절대 만들지 않는다 (단조 증가축 P2W 방어선, `docs/bm.md` §13).

### 2.5 카탈로그 — 번들 / 패키지

| Key | 상품명 | 가격 (USD) | 구성 | 노출 시점 |
|---|---|---|---|---|
| `IAP_STARTER_PACK` | Starter Pack | $4.99 | VIP(7일 한정) + 2x Boost x3 + Auto Fuel x3 | T1 첫 클리어 직후 (24h 한정) |
| `IAP_FIRST_MISSION_PACK` | First Mission Pack | $2.99 | 2x Boost x1 + Auto Fuel x1 + 트레일 코스메틱 1종 | T2 첫 진입 |
| `IAP_RISK_RECOVERY_PACK` | Risk Recovery Pack | $4.99 | Trajectory Surge x1 + System Purge x2 + Shield T3 x1 | T3 첫 Overload 또는 첫 Abort |
| `IAP_INTERSTELLAR_PACK` | Interstellar Operations Pack | $14.99 | Shield T5 x1 + Trajectory Surge x2 + 전용 칭호 | T5 첫 진입 |
| `IAP_WEEKLY_DEAL` | Weekly Deal | $4.99~$9.99 | 매주 자동 회전, 한정 75% 할인 번들 | 매 일요일 갱신 |
| `IAP_ZONE_UNLOCK_PACK` | Zone Unlock Pack | $9.99~$29.99 | 특정 Zone 모든 목적지 +50% 보상 영구 | Zone 첫 진입 |

### 2.6 Steam Cosmetic DLC

| Key | 상품명 | 가격 (USD) |
|---|---|---|
| `DLC_ROCKET_SKINS_PACK_1` | Rocket Skin Pack: Cyberpunk | $2.99 |
| `DLC_ROCKET_SKINS_PACK_2` | Rocket Skin Pack: Retro Soviet | $2.99 |
| `DLC_LAUNCHPAD_THEMES` | Launch Pad Themes Pack | $2.99 |
| `DLC_TRAIL_FX_PACK` | Trail FX Pack (Plasma / Rainbow / Wormhole) | $2.99 |
| `DLC_OST` | Original Soundtrack | $4.99 |

> 시즌 확장 DLC(`DLC_INTERSTELLAR_FRONTIER` $7.99 등)는 컨텐츠 추가형으로 별도 일정에 따라 출시 (`docs/bm.md` §8.1).

### 2.7 멱등성 가드 (`verify_receipt`)

```gdscript
func verify_receipt(receipt: Dictionary) -> bool:
    var tx_id: String = receipt["transaction_id"]
    for entry in GameState.purchases.consumable_log:
        if entry["transaction_id"] == tx_id:
            return true                                # 이미 처리됨 → 성공으로 응답
    if not _platform_verify(receipt):
        _enqueue_retry(receipt)                        # 오프라인 큐에 적립
        return false
    _apply_consumable(receipt["product_id"])
    GameState.purchases.consumable_log.append({
        "transaction_id": tx_id,
        "product_id": receipt["product_id"],
        "purchased_at": Time.get_unix_time_from_system(),
    })
    _trim_log_to(200)
    SaveSystem.save()
    EventBus.iap_consumed.emit(receipt["product_id"], tx_id)
    return true
```

**재전달 시나리오**: 네트워크 단절 시 플랫폼이 영수증을 재전송한다. 멱등성 가드 없이는 중복 지급. 마지막 단계에서 반드시 `consumable_log`에 기록.

**저장 관리**: `consumable_log`는 SaveSystem 로드 시 최대 200개로 트림 (가장 최근 100개만 유지). 무한 증가 방지.

### 2.8 효과 분기 (`_apply_consumable`)

```gdscript
const TIME_BOOSTS := {
    "IAP_BOOST_2X": { "slot": "boost_2x", "duration": 1800 },
    "IAP_TRAJECTORY_SURGE": { "slot": "trajectory_surge", "duration": 1800 },
    "IAP_AUTO_FUEL": { "slot": "auto_fuel", "duration": 3600 },
}

func _apply_consumable(product_id: String) -> void:
    if TIME_BOOSTS.has(product_id):
        var spec := TIME_BOOSTS[product_id]
        var now: int = Time.get_unix_time_from_system()
        var slot: String = spec["slot"] + "_expire_at"
        var current: int = GameState.active_boosts.get(slot, 0)
        # 활성 중 재구매 → 남은 시간 + duration (스택 누적)
        GameState.active_boosts[slot] = max(now, current) + spec["duration"]

    elif product_id in ["IAP_SHIELD_T3", "IAP_SHIELD_T4", "IAP_SHIELD_T5"]:
        var tier: String = product_id.to_lower().replace("iap_", "")
        GameState.shield_inventory[tier] += 1

    elif product_id == "IAP_SYSTEM_PURGE":
        StressService.reduce(SYSTEM_PURGE_AMOUNT)      # -30

    elif product_id.begins_with("IAP_CREDIT_"):
        EconomyService.add_credit(_credit_amount(product_id))

    elif product_id.begins_with("IAP_") and _is_bundle(product_id):
        for item in _bundle_contents(product_id):
            _apply_consumable(item)                    # 재귀 적용
```

### 2.9 시간제 부스트 추적 (영속)

```gdscript
# GameState.active_boosts (savegame.json에 영속)
{
    "boost_2x_expire_at": 1714003600,                  # Unix timestamp
    "trajectory_surge_expire_at": 0,
    "auto_fuel_expire_at": 1714003600,
}

func has_active_boost(slot: String) -> bool:
    var expire_at: int = GameState.active_boosts.get(slot + "_expire_at", 0)
    return Time.get_unix_time_from_system() < expire_at

func get_boost_remaining(slot: String) -> int:
    var expire_at: int = GameState.active_boosts.get(slot + "_expire_at", 0)
    return max(0, expire_at - Time.get_unix_time_from_system())
```

> Unix timestamp 기반이므로 앱 재시작 / 디바이스 재부팅에 영향받지 않는다. 단, 시스템 시계 변조에 취약 → V2에서 `OS.get_unix_time` + 첫 실행 시 NTP 서버 동기화 옵션 검토.

### 2.10 Shield 자동 소비 흐름

`LaunchService.abort_launch()`에서 Abort가 발생하면 다음 우선순위로 처리:

1. 현재 Tier에 맞는 Shield 인벤토리 조회 (`GameState.shield_inventory["shield_t3"]` 등)
2. 보유 시 → 인벤토리 -1, 수리비 면제, `EventBus.shield_consumed` 발화
3. 미보유 시 → 정상 수리비 차감 + AbortScreen에서 Shield 구매 CTA 노출

### 2.11 Steam Cosmetic DLC 활성화

```gdscript
# DLCService._on_dlc_installed callback
func _on_dlc_installed(dlc_id: int) -> void:
    var key: String = _resolve_dlc_key(dlc_id)
    EventBus.dlc_installed.emit(key)
    # 코스메틱 시스템이 자동으로 옵션 슬롯 추가
```

게임 시작 시 `Steam.isDLCInstalled(app_id)`를 모든 등록 DLC에 대해 순회 → `DLCService._installed` 캐시 구성. 코스메틱 셀렉터 UI는 이 캐시를 구독.

## 3. 정적 데이터 (Config)

### `data/iap_config.tres` (소모형 섹션)

```
products = [
    { key = "IAP_BOOST_2X", price_usd = 1.49, kind = "consumable",
      effect = "boost_2x", duration_sec = 1800, required_tier = 1 },
    { key = "IAP_TRAJECTORY_SURGE", price_usd = 1.99, kind = "consumable",
      effect = "trajectory_surge", duration_sec = 1800, required_tier = 2 },
    { key = "IAP_AUTO_FUEL", price_usd = 0.99, kind = "consumable",
      effect = "auto_fuel", duration_sec = 3600, required_tier = 1 },
    { key = "IAP_SHIELD_T3", price_usd = 2.99, kind = "consumable",
      effect = "shield", shield_tier = 3, required_tier = 3 },
    # ... T4, T5
    { key = "IAP_SYSTEM_PURGE", price_usd = 0.99, kind = "consumable",
      effect = "stress_purge", amount = 30, required_tier = 3 },
    { key = "IAP_CREDIT_S", price_usd = 0.99, kind = "consumable",
      effect = "credit", amount = 500, required_tier = 2 },
    # ... M, L
    { key = "IAP_STARTER_PACK", price_usd = 4.99, kind = "consumable_bundle",
      contents = ["IAP_VIP_7DAY_TRIAL", "IAP_BOOST_2X", "IAP_BOOST_2X",
                  "IAP_BOOST_2X", "IAP_AUTO_FUEL", "IAP_AUTO_FUEL", "IAP_AUTO_FUEL"],
      window_hours = 24, required_tier = 1 },
    # ... 나머지 번들
]
```

### `data/dlc_config.tres` (코스메틱 섹션)

```
cosmetic_dlcs = [
    { key = "DLC_ROCKET_SKINS_PACK_1", dlc_id = <Steam DLC ID>, price_usd = 2.99,
      grants = ["skin_cyberpunk_1", "skin_cyberpunk_2", "skin_cyberpunk_3"] },
    { key = "DLC_LAUNCHPAD_THEMES", dlc_id = <...>, price_usd = 2.99,
      grants = ["pad_neon", "pad_volcanic", "pad_arctic"] },
    { key = "DLC_TRAIL_FX_PACK", dlc_id = <...>, price_usd = 2.99,
      grants = ["trail_plasma", "trail_rainbow", "trail_wormhole"] },
    { key = "DLC_OST", dlc_id = <...>, price_usd = 4.99,
      grants = ["ost_unlock"] },
]
```

### 효과 상수 (`scripts/services/iap_service.gd`)

```gdscript
const BOOST_XP_MULT: float = 2.0
const TRAJECTORY_SURGE_BONUS: float = 0.03
const AUTO_FUEL_RATE_BONUS: float = 0.5
const SYSTEM_PURGE_AMOUNT: int = 30
const CONSUMABLE_LOG_MAX: int = 200
const CONSUMABLE_LOG_KEEP: int = 100   # 트림 후 유지 개수
```

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

```gdscript
{
    "purchases": {
        "consumable_log": [
            { "transaction_id": "GPA.3344-...", "product_id": "IAP_BOOST_2X",
              "purchased_at": 1714000000 }
        ]
    },
    "active_boosts": {
        "boost_2x_expire_at": 1714003600,
        "trajectory_surge_expire_at": 0,
        "auto_fuel_expire_at": 0
    },
    "shield_inventory": {
        "shield_t3": 1, "shield_t4": 0, "shield_t5": 0
    },
    "purge_inventory": 0,
    "bundle_window": {
        "IAP_STARTER_PACK_expire_at": 1714086400        # 24h 한정 표시 종료
    }
}
```

## 5. 런타임 상태

| 필드 | 용도 |
|---|---|
| `IAPService._pending_retry: Array[Dictionary]` | 영수증 검증 실패 시 재시도 큐 |
| `IAPService._session_cache: Dictionary` | 영구형 IAP 세션 캐시 (7-1과 공유) |
| `DLCService._installed: Dictionary[String, bool]` | Steam DLC 설치 여부 |
| `DLCService._dlc_id_to_key: Dictionary[int, String]` | Steam DLC ID → Config Key 역참조 |

## 6. 시그널 (EventBus)

| Signal | 인자 | 발화 시점 |
|---|---|---|
| `iap_purchased` | `(product_id, transaction_id)` | 영구형 (7-1) — 여기서는 재선언 X |
| `iap_consumed` | `(product_id, transaction_id)` | 소모형 영수증 처리 완료 |
| `boost_activated` | `(slot: String, expire_at: int)` | 시간제 부스트 활성화 |
| `shield_consumed` | `(tier: int, refunded_cost: int)` | Abort 시 Shield 자동 소비 |
| `dlc_installed` | `(dlc_key: String)` | Steam DLC 설치 감지 |
| `iap_purchase_failed` | `(product_id, reason: String)` | 검증 실패 / 사용자 취소 / 네트워크 오류 |

## 7. 의존성

**의존**:
- `GameState`, `SaveSystem`
- `StressService` (System Purge 적용)
- `EconomyService` (Credit 지급)
- 플랫폼 어댑터 (`google_play_billing.gd`, `apple_storekit.gd`, `steam_iap.gd`)

**의존받음**:
- `LaunchService.launch_rocket()` — `IAPService.get_xp_mult()` (Boost 합산)
- `LaunchService.get_upgrade_chance_bonus()` — `IAPService.get_trajectory_surge_bonus()`
- `LaunchService.abort_launch()` — Shield 인벤토리 소비
- `AutoLaunchService.get_rate()` — `IAPService.has_active_boost("auto_fuel")`
- `scenes/ui/abort_screen.tscn` — Shield 구매 + 광고 버튼
- `scenes/ui/cosmetic_selector.tscn` — DLC 코스메틱 옵션 표시

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `scripts/services/iap_service.gd` | `verify_receipt`, `_apply_consumable`, 시간제 추적 |
| `scripts/services/dlc_service.gd` | Steam DLC 보유 검증, 코스메틱 활성화 |
| `scripts/services/platform/google_play_billing.gd` | Android 영수증 수령 / acknowledge |
| `scripts/services/platform/apple_storekit.gd` | iOS 영수증 수령 / 검증 |
| `scripts/services/platform/steam_iap.gd` | Steam DLC 콜백 |
| `data/iap_config.tres` | 소모형/번들 정의 |
| `data/dlc_config.tres` | 코스메틱 DLC 정의 |
| `scenes/ui/shop_panel.tscn` | 카드 UI |
| `scenes/ui/abort_screen.tscn` | Shield 구매 (Abort 시점) |

## 9. 알려진 이슈 / 설계 주의점

1. **시간제 부스트 영속화 (필수)**: `active_boosts.*_expire_at`을 SaveSystem에 포함시켜 앱 재시작 후에도 남은 시간 유지. Unix timestamp 기반이므로 별도 보정 로직 불필요.
2. **시스템 시계 변조 가드 (V2)**: 시계를 미래로 돌려 부스트를 즉시 만료시키는 것은 불이익이라 무방, 과거로 돌려 무한 연장하는 케이스만 차단하면 된다. 마지막 저장 시각보다 현재 시각이 과거인 경우 → `expire_at`을 현재 시각 기준으로 재정렬.
3. **Shield는 인벤토리형 (Abort 환불 아님)**: 구매 즉시 인벤토리에 적립되고, 다음 Abort 발생 시 자동으로 소비된다. 이미 발생한 Abort를 사후 환불하지 않는다 — 사용자 기대 관리 필요 (UI 문구 "다음 Abort에서 자동 사용").
4. **System Purge 30 차감**: `MAX_GAUGE(100)`에서 30 감소. 완전 리셋이 아니므로 Overload 도달 직후 1회 구매로 unlock 안 될 수 있다 (잔여가 0 이하로 내려가야 unlock).
5. **번들 24h 한정 (Starter Pack)**: T1 첫 클리어 시점에 `bundle_window.IAP_STARTER_PACK_expire_at = now + 86400` 기록 → UI는 이 값과 현재 시각 비교로 카드 노출 결정. 만료 후에는 영구 비표시.
6. **Weekly Deal 회전 로직**: 매주 일요일 00:00 (디바이스 로컬) `WeeklyDealService`가 미리 정의된 4~6종 풀에서 1종을 결정적 시드로 선택. `seed = year * 53 + week_of_year` → 같은 주에 들어온 모든 유저는 같은 딜.
7. **Auto Fuel 정식 노출**: V1 출시 정식 상품. UI는 `iap_config.tres.required_tier = 1`을 참고.
8. **오프라인 결제 큐**: 영수증 검증이 네트워크 오류로 실패한 경우 `_pending_retry`에 적립 → 다음 온라인 진입 시 자동 재시도. 영구형 IAP는 `restore_purchases()`로도 복구 가능하므로 큐가 영구 유지될 필요는 없다 (앱 종료 시 비휘발 저장은 선택).
9. **Steam에서 소모형 IAP 미적용**: Steam 트랙은 코스메틱 DLC만 판매. 시간제 부스트 / Shield / Credit 팩 / 번들은 모바일 전용. `IAPService` 초기화 시 플랫폼 분기로 카탈로그 필터링.
10. **첫 5분 IAP 모달 금지**: `docs/bm.md` §11.2 규칙. 진입 후 300초 이내에는 모달형 BM 노출 금지. 카드 UI는 상점 진입 시에만 노출되므로 영향 없으나, 자동 팝업(Starter Pack 한정 알림 등)은 게이트 적용.
