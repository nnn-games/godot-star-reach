# Godot 4 결제 연동 — Android / iOS / Steam

**핵심 구조**: 세 플랫폼이 완전히 다른 SDK를 쓰므로 **공통 추상 인터페이스 위에 플랫폼별 Backend**를 두는 것이 Godot 관용. StarReach는 Android·iOS·Steam 순으로 타깃 예상이므로 이 순서로 정리.

각 플랫폼은 **공식 SDK 플러그인 + (선택) 영수증 검증 서버**의 2계층 구성이 정석입니다.

---

## 0. 전체 그림

```
                ┌─────────────────────────────────────┐
                │  IAPService (Autoload, GDScript)    │
                │   · get_products()                  │
                │   · purchase(sku)                   │
                │   · restore_purchases()             │
                │   · signal purchase_completed(...)  │
                └──────────────┬──────────────────────┘
                               │ OS.get_name() 분기
           ┌───────────────────┼───────────────────┐
           ▼                   ▼                   ▼
   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
   │ AndroidBackend│   │   iOSBackend  │   │  SteamBackend │
   │ (GodotGooglePl│   │ (inappstore)  │   │  (GodotSteam) │
   │  ayBilling)   │   │               │   │               │
   └───────┬───────┘   └───────┬───────┘   └───────┬───────┘
           │ JSON               │                    │
           ▼                    ▼                    ▼
   ┌─────────────────────────────────────────────────────────┐
   │ 영수증 검증 서버 (Firebase Function / Nakama / 자체)  │
   │   · Google Play Developer API / Apple App Store /       │
   │     Steam WebAPI로 토큰 재검증                           │
   │   · 인벤토리 발급                                        │
   └─────────────────────────────────────────────────────────┘
```

---

## 1. Android — Google Play Billing

### 1.1 플러그인 선택

| 플러그인 | 상태 | 권장 |
|---|---|---|
| **`godot-sdk-integrations/godot-google-play-billing`** (공식) | Godot 4.2+, Billing Library 최신 | ✅ 가장 표준 |
| `code-with-max/godot-google-play-iapp` (커뮤니티) | Godot 4.6+, Billing v8.3.0, 타입 힌트 강함 | ✅ 최신 API 원하면 |
| OpenIAP 기반 cross-platform | Android + iOS 통합 API, 2026년 초 등장 | ⏳ 커뮤니티 성숙 대기 |

StarReach는 공식 플러그인 권장. 최신 Billing API를 원하면 `godot-google-play-iapp`.

### 1.2 설치 순서

1. `.aar` 플러그인 파일을 `star-reach/android/plugins/`에 배치.
2. Android 커스텀 빌드 활성화: `Project → Install Android Build Template` (또는 `project.godot`에서 `android/gradle_build/use_gradle_build=true`).
3. `Project → Export → Android` 프리셋에서 해당 플러그인 체크.
4. Play Console에서 앱 등록 → 상품(SKU) 생성: consumable / non-consumable / subscription.

### 1.3 상품 타입 (Google)

| 타입 | 예시 | 소비 가능? |
|---|---|---|
| **Consumable** | 코인 1,000개 팩 | ✅ 소비 후 재구매 가능 |
| **Non-consumable** | 광고 제거, 프리미엄 테마 | ❌ 영구 소유 |
| **Subscription** | 월정액 자동 수집기 | 갱신형 |

StarReach 증분 시뮬 주력: **consumable(코인 팩) + non-consumable(광고 제거·스킨)**. subscription은 드묾.

### 1.4 GDScript 사용 패턴 (공식 플러그인 기준)

```gdscript
# res://scripts/autoload/iap_service.gd (일부)
var _billing: Object = null

func _ready() -> void:
    if OS.get_name() != "Android":
        return
    if not Engine.has_singleton("GodotGooglePlayBilling"):
        push_warning("GooglePlayBilling singleton missing")
        return
    _billing = Engine.get_singleton("GodotGooglePlayBilling")
    _billing.connected.connect(_on_connected)
    _billing.disconnected.connect(_on_disconnected)
    _billing.sku_details_query_completed.connect(_on_sku_details)
    _billing.purchases_updated.connect(_on_purchases_updated)
    _billing.startConnection()

func purchase(sku: String) -> void:
    var r: Dictionary = _billing.purchase(sku)
    if r.status != OK:
        push_error("purchase failed: %s" % r)

func _on_purchases_updated(purchases: Array) -> void:
    for p in purchases:
        _verify_receipt(p.purchase_token, p.sku)  # 서버 검증
```

### 1.5 자주 발생하는 함정

- **테스트 구매 실패 → 테스터 계정 등록 안 됨**: Play Console → License testing에 이메일 추가.
- **Gradle 빌드 활성화 안 함**: 플러그인 `.aar`이 제대로 패킹 안 됨.
- **`consumePurchase` 누락**: consumable을 구매 후 소비하지 않으면 다시 살 수 없음.
- **Play Billing v5+에서 `querySkuDetails` → `queryProductDetails` 변경**: 플러그인 버전에 따라 API 이름 다름.

---

## 2. iOS — StoreKit

### 2.1 플러그인 상황 (중요)

iOS는 **플러그인 상황이 Android보다 불안정**합니다.

| 플러그인 | StoreKit | 상태 |
|---|---|---|
| `godot-sdk-integrations/godot-ios-plugins` (공식, `inappstore`) | **StoreKit 1** | 과거 구매 복원·구독 상태 조회가 불안정 |
| `hrk4649/godot_ios_plugin_iap` (커뮤니티) | StoreKit 1 (Swift) | 공식보다 코드 단순 |
| Thunder Plugins (상용) | StoreKit 2 | 유료, 유지보수 활발 |
| OpenIAP 기반 (2026.02+) | StoreKit 2 + Billing 8 | ✅ 가장 현대적, 아직 커뮤니티 성숙 중 |

**현실 권장**: StoreKit 2 기반(OpenIAP 또는 Thunder)으로 가는 편이 장기적 안정. 예산이 없고 StoreKit 1 제약을 감수하면 공식 플러그인.

### 2.2 빌드 환경

- **macOS + Xcode 필수** — Windows만으로는 iOS 빌드 불가.
- 대안: GitHub Actions의 macOS runner로 CI 빌드.
- Apple Developer Program ($99/yr).

### 2.3 GDScript 패턴 (공식 `inappstore` 기준)

```gdscript
var _store: Object = null

func _ready() -> void:
    if OS.get_name() != "iOS": return
    if not Engine.has_singleton("InAppStore"): return
    _store = Engine.get_singleton("InAppStore")
    _store.set_auto_finish_transaction(false)
    _store.connect("product_purchased", _on_product_purchased)

func purchase(sku: String) -> void:
    var r: int = _store.purchase({"product_id": sku})
    if r != OK: push_error("iOS purchase call failed")

func _on_product_purchased(result: Dictionary) -> void:
    if result.result == "ok":
        _verify_receipt(result.transaction_id, result.product_id)
        _store.finish_transaction(result.product_id)
```

### 2.4 iOS 특이사항

- **앱 심사 시 IAP 테스트 필수** — 누락 시 리젝.
- **Sandbox 환경**에서 테스트: App Store Connect → Sandbox Tester 계정 생성.
- **영수증 검증은 반드시 production endpoint 먼저**, `21007` (sandbox receipt used in production) 에러 시 sandbox로 폴백 — Apple 공식 가이드.
- **Restore Purchases 버튼 UI 필수** — Apple 심사 가이드라인.
- **3.1.1 항목**: "가상 재화·게임 내 기능은 반드시 StoreKit 경유" — 우회 결제 금지(단, 한국은 2024+ External Purchase Link 허용).

---

## 3. Steam — Steamworks

### 3.1 GodotSteam

- **`GodotSteam`** (godotsteam.com): MIT, 가장 성숙한 Steamworks 바인딩.
- GDExtension 또는 pre-compiled engine build 제공. GDExtension 방식이 유지보수 유리.
- Godot Asset Library에서 직접 설치 가능.

### 3.2 Steam의 결제 모델 — DLC vs MicroTransactions

Steam은 모바일과 **결제 모델이 다릅니다**:

| 모델 | 용도 | 구현 |
|---|---|---|
| **DLC** | 스킨팩, 확장팩, 광고 제거 같은 **영구 소유** | Steamworks partner에서 DLC 상품 등록 → `Steam.isDLCInstalled(app_id)` 체크 |
| **MicroTransaction** | 코인 팩 같은 **소모형** | Steam WebAPI `InitTxn` / `FinalizeTxn` — 서버 필수 |
| **Steam Item / Inventory Service** | 게임 내 아이템 NFT화 | 복잡, 대규모 게임용 |

**Valve 권장**: 단순한 경우 DLC, 복잡한 경제 게임은 MicroTransactions. StarReach 같은 증분 시뮬은 **코인 팩 = MicroTransactions**, **광고 제거·스킨 = DLC** 조합이 자연스러움.

### 3.3 MicroTransaction 구현 흐름

```
[게임 클라이언트] ──(1) 사용자 "코인 10k 팩 구매" 클릭
      │
      │ (2) 백엔드에 orderid 요청
      ▼
[게임 서버] ──(3) Steam WebAPI InitTxn(userid, items)──► [Steamworks]
      ◄──(4) 트랜잭션 ID 반환
      │
      ▼
[게임 클라이언트] ──(5) Steam overlay가 결제창 표시 → 사용자 승인
      │
      ▼
[게임 서버] ──(6) Steam WebAPI FinalizeTxn(txid)────► [Steamworks]
      │
      └─(7) 인벤토리/DB에 코인 증액
```

**핵심**: 클라이언트에서 직접 결제 처리 못 함. **서버가 Steam WebAPI 호출**.

### 3.4 DLC 체크 (광고 제거 등)

```gdscript
if Steam.isDLCInstalled(DLC_REMOVE_ADS_ID):
    _hide_ads()
```

간단. 서버 불필요. DLC는 Steam 클라이언트가 직접 관리.

---

## 4. 공통 추상화 설계 — `IAPService`

플랫폼마다 API가 다르므로 **GDScript 인터페이스 + 플랫폼별 구현**으로 감쌈.

### 4.1 인터페이스 (@abstract)

```gdscript
# res://scripts/iap/iap_backend.gd
@abstract
class_name IAPBackend
extends RefCounted

signal purchase_completed(sku: StringName, receipt: Dictionary)
signal purchase_failed(sku: StringName, reason: String)
signal products_loaded(products: Array[IAPProduct])

@abstract func initialize() -> void
@abstract func query_products(skus: PackedStringArray) -> void
@abstract func purchase(sku: StringName) -> void
@abstract func restore_purchases() -> void
```

### 4.2 상품 정의 (Custom Resource)

```gdscript
# res://scripts/resources/iap_product.gd
class_name IAPProduct
extends Resource

enum Kind { CONSUMABLE, NON_CONSUMABLE, SUBSCRIPTION }

@export var sku: StringName              # Google/Apple product id
@export var kind: Kind
@export var display_name: String
@export var localized_price: String       # "₩5,500" — 플랫폼에서 받아와 채움
@export_multiline var description: String

## 게임 측에서 구매 성공 시 지급할 보상
@export var grants_coins: float = 0.0
@export var grants_flag: StringName = &""  # 예: &"ads_removed"
```

### 4.3 SKU 카탈로그

```
res://data/iap/
├── pack_coins_small.tres   (CONSUMABLE, grants_coins=1000)
├── pack_coins_medium.tres  (CONSUMABLE, grants_coins=10000)
├── pack_coins_large.tres   (CONSUMABLE, grants_coins=100000)
├── remove_ads.tres         (NON_CONSUMABLE, grants_flag="ads_removed")
└── premium_theme.tres      (NON_CONSUMABLE, grants_flag="premium_theme")
```

동일 SKU ID를 **각 플랫폼 콘솔(Play/App Store/Steam)에 모두 등록**하되, 플랫폼별 가격은 거기서 관리.

### 4.4 `IAPService` Autoload 파사드

```gdscript
# res://scripts/autoload/iap_service.gd
extends Node

signal purchase_completed(product: IAPProduct)
signal purchase_failed(sku: StringName, reason: String)

const PRODUCTS: PackedStringArray = [
    "res://data/iap/pack_coins_small.tres",
    "res://data/iap/pack_coins_medium.tres",
    "res://data/iap/pack_coins_large.tres",
    "res://data/iap/remove_ads.tres",
    "res://data/iap/premium_theme.tres",
]

var _backend: IAPBackend
var _catalog: Dictionary[StringName, IAPProduct] = {}

func _ready() -> void:
    _load_catalog()
    _backend = _select_backend()
    if _backend == null:
        return
    _backend.purchase_completed.connect(_on_purchase_completed)
    _backend.purchase_failed.connect(_on_purchase_failed)
    _backend.initialize()

func buy(sku: StringName) -> void:
    if _backend == null:
        purchase_failed.emit(sku, "No IAP backend on this platform")
        return
    _backend.purchase(sku)

func is_entitled(flag: StringName) -> bool:
    return GameState.flags.has(flag)

func _select_backend() -> IAPBackend:
    match OS.get_name():
        "Android":
            return preload("res://scripts/iap/android_backend.gd").new()
        "iOS":
            return preload("res://scripts/iap/ios_backend.gd").new()
        "Windows", "macOS", "Linux":
            if Engine.has_singleton("Steam"):
                return preload("res://scripts/iap/steam_backend.gd").new()
            return null
        _:
            return null

func _on_purchase_completed(sku: StringName, receipt: Dictionary) -> void:
    # 영수증 서버 검증 비동기
    var verified: bool = await ReceiptValidator.verify(OS.get_name(), sku, receipt)
    if not verified:
        purchase_failed.emit(sku, "Receipt validation failed")
        return
    var product: IAPProduct = _catalog.get(sku)
    _grant(product)
    purchase_completed.emit(product)

func _grant(p: IAPProduct) -> void:
    if p.grants_coins > 0.0:
        GameState.add_currency(&"coin", p.grants_coins)
    if p.grants_flag != &"":
        GameState.set_flag(p.grants_flag, true)
```

**포인트**:
- UI는 `IAPService.buy(&"pack_coins_small")`만 호출. 백엔드 교체에 독립.
- Consumable/non-consumable 차이를 **데이터**(IAPProduct.kind)에서 결정.
- 영수증 검증 → 지급 → 시그널, 일관된 흐름.

---

## 5. 영수증 검증 (Receipt Validation)

### 5.1 왜 필수인가

클라이언트 검증만 하면 다음 공격에 취약:
- **가짜 응답 주입**: 루팅/탈옥 기기에서 StoreKit/Billing 응답 위조.
- **Replay**: 유효한 영수증을 저장해 여러 번 제출.
- **공유**: 한 사람의 영수증을 다른 사용자가 사용.

→ **서버가 Google/Apple/Steam의 API로 재검증** → 인벤토리 지급.

### 5.2 구현 옵션

| 옵션 | 비용 | 난이도 |
|---|---|---|
| **Firebase Functions + Firestore** | 소규모 무료, 커지면 저렴 | 중 (함수 2~3개 작성) |
| **Nakama (오픈소스 게임 서버)** | 자체 호스팅 or 호스팅 플랜 | 중상 (전체 서버 플랫폼) |
| **Receipt Validator (`flobuk`)** | 월정액 유료 SaaS | 하 (플러그인만 설치) |
| **자체 서버 (Node/Go)** | 호스팅 비용 | 고 |

StarReach 런칭 단계: **Firebase Functions** 추천. 함수 1~2개로 충분.

### 5.3 Firebase Function 스케치 (Android 예)

```javascript
// functions/verifyGooglePurchase.js
exports.verify = functions.https.onCall(async (data, context) => {
    const { purchaseToken, productId } = data;
    const client = new google.androidpublisher("v3", { auth: authClient });
    const res = await client.purchases.products.get({
        packageName: "com.starreach.game",
        productId,
        token: purchaseToken,
    });
    if (res.data.purchaseState === 0 /* purchased */) {
        await admin.firestore().collection("grants").doc(context.auth.uid).set({
            [productId]: firebase.firestore.FieldValue.arrayUnion(purchaseToken),
        }, { merge: true });
        return { ok: true };
    }
    return { ok: false };
});
```

iOS는 Apple의 `/verifyReceipt` (deprecated, StoreKit 2는 JWS 검증), Steam은 WebAPI `FinalizeTxn`. **세 플랫폼 모두 별도 검증 루트**.

### 5.4 Sandbox vs Production

- 개발 중엔 반드시 테스트 계정·Sandbox 환경 사용.
- 앱 심사는 Sandbox에서 테스트. 첫 승인 후 프로덕션으로.
- **Apple 특히 주의**: production 엔드포인트가 Sandbox 영수증에 `21007` 에러 → Sandbox endpoint로 폴백 로직 필수.

---

## 6. 법·정책 주의사항

### 6.1 한국 앱마켓법 (2022+)

- 구글/애플은 **제3자 결제 시스템 병기 허용** 의무.
- Google Play는 "Alternative Billing" 지원, 수수료 11% (대신 15% 기본이 11%로 내림).
- Apple은 "External Purchase Link" API 제공 (iOS 17.4+, 유럽+한국).

StarReach가 한국 런칭 시 이 제도 활용하면 수수료 4%p 절약. 단 자체 PG 연동 필요 → **소규모 팀은 그냥 기본 결제 쓰는 편이 단순**.

### 6.2 Apple 가이드라인 3.1.1 / 3.1.3

- 가상 재화·앱 내 기능은 StoreKit 필수 (디지털 상품).
- 실물 상품/외부 서비스는 외부 결제 가능.
- StarReach 코인·스킨은 **디지털** → StoreKit 강제.

### 6.3 수수료 구조 (2026.04 기준)

| 플랫폼 | 수수료 |
|---|---|
| Google Play | 15% (연 $1M 이하), 30% (초과) |
| App Store | 15% (Small Business Program), 30% (기본) |
| Steam | 30% (대부분), 25% ($10M 이상), 20% ($50M 이상) |

---

## 7. StarReach 적용 로드맵

**Phase 1 현재 상태**: 결제 없음. GameState에 재화만.

**Phase 4 (출시 준비) 제안**:

1. **Phase 4.0**: `IAPProduct` Custom Resource + `IAPService` Autoload 뼈대(모든 플랫폼에서 no-op fallback).
2. **Phase 4.1**: Android 첫 적용.
   - `godot-google-play-billing` 설치
   - `AndroidBackend` 구현
   - Play Console에 테스트 SKU 3종 등록
   - Firebase Function으로 영수증 검증
3. **Phase 4.2**: iOS (Apple Developer 가입 후).
   - StoreKit 2 플러그인 선택 (OpenIAP 또는 Thunder)
   - `iOSBackend` 구현
   - App Store Connect SKU 등록
4. **Phase 4.3**: Steam.
   - GodotSteam GDExtension 설치
   - Steamworks partner 등록 + $100 출품비
   - DLC로 광고 제거 / MicroTransaction으로 코인팩
   - Steam WebAPI 서버 엔드포인트

**초기 검증만 필요**할 때 (Phase 2~3): `IAPService`를 **mock backend**로 구현 — 모든 호출에 즉시 `purchase_completed` 발신. UI 흐름과 보상 지급 로직을 IAP 없이 검증 가능.

---

## 8. 즉시 적용 가능한 최소 스텁

플랫폼 플러그인 없이도 UI/보상 지급 로직을 미리 개발할 수 있게 **mock 백엔드**부터 만드는 것을 권장:

```gdscript
# res://scripts/iap/mock_backend.gd
class_name MockIAPBackend
extends IAPBackend

func initialize() -> void:
    print("Mock IAP initialized — all purchases auto-succeed")

func query_products(_skus: PackedStringArray) -> void:
    await get_tree().create_timer(0.1).timeout
    products_loaded.emit([])  # 카탈로그 채우는 건 IAPService가 담당

func purchase(sku: StringName) -> void:
    await get_tree().create_timer(0.3).timeout
    purchase_completed.emit(sku, {"mock": true})

func restore_purchases() -> void:
    await get_tree().create_timer(0.3).timeout
```

개발 중에는 `_select_backend()`에서 빌드 설정에 따라 Mock 반환. 지금 단계에선 충분.

---

## 9. 체크리스트

- [ ] 플랫폼별 상품 타입(consumable/non-consumable/subscription/DLC) 정리
- [ ] SKU ID 통일(모든 스토어 동일 문자열 권장)
- [ ] 영수증 검증 서버 구축 (Firebase Function 또는 Receipt Validator SaaS)
- [ ] Restore Purchases 버튼(iOS 심사 필수)
- [ ] Sandbox 테스트 계정 (Google Play Internal Testing / App Store Sandbox / Steam Partner)
- [ ] 첫 심사 전 가격 지역화 설정 (통화별)
- [ ] 한국 외부 결제 API 활용 여부 결정

---

## 10. 참고 자료

- [Android in-app purchases — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_in_app_purchases.html)
- [godot-sdk-integrations/godot-google-play-billing (공식)](https://github.com/godot-sdk-integrations/godot-google-play-billing)
- [code-with-max/godot-google-play-iapp (Billing v8)](https://github.com/code-with-max/godot-google-play-iapp)
- [godot-sdk-integrations/godot-ios-plugins (inappstore)](https://github.com/godot-sdk-integrations/godot-ios-plugins/blob/master/plugins/inappstore/README.md)
- [GodotSteam 공식 사이트](https://godotsteam.com/)
- [GodotSteam GitHub](https://github.com/GodotSteam)
- [flobuk/godot-receiptvalidator](https://github.com/flobuk/godot-receiptvalidator)
- [Godot IAP: A Brutally Honest Guide — Wayline](https://www.wayline.io/blog/godot-iap-in-app-purchases-guide)
- [Integrate Steamworks Into Your Godot Project — SuperJump](https://www.superjumpmagazine.com/integrate-steamworks-into-your-godot-project-with-godotsteam/)
