# 포스트 랜딩 BM 단계별 노출 전략

> **문서 유형**: 포스트 랜딩 유저 대상 BM 노출 전략 (Stage A~D)
> **작성일**: 2026-04-24
> **상위 문서**: `docs/bm.md`, `docs/prd.md`, `docs/design/game_overview.md` §7
> **문서 성격**: `docs/bm.md`에 정의된 IAP / DLC / Subscription 카탈로그를 **언제 / 어떻게 / 어느 플랫폼에서** 노출할지를 결정하는 운영 기획.

---

## 1. 문서 목적

이 문서는 **랜딩이 끝난 유저**를 대상으로 하는 본격 BM 구조를 Star Reach의 현재 콘텐츠와 두 플랫폼 (Mobile / Steam) 특성에 맞춰 매우 구체적으로 정의한다.

`docs/bm.md`가 **무엇을 파는가** (상품 카탈로그 / 가격 / 데이터 구조 / 플랫폼 통합)를 다룬다면, 이 문서는 **언제 누구에게 어떻게 보여줄 것인가** (Stage 게이트 / 노출 트리거 / 빈도 제한)를 다룬다.

### 1.1 랜딩 완료 유저의 정의

이 문서에서 말하는 `랜딩 완료 유저`는 게임 온보딩이 끝난 유저를 의미하며, 실제 타게팅 기준은 아래로 본다.

1. `T1 첫 클리어`를 달성했다.
2. 또는 `누적 10회 발사`를 넘겨 기본 `Auto Launch` 해금 구간에 진입했다.

즉, 이 시점 이후 유저는 이미 아래를 이해한 상태다.

1. `Launch -> 실패/성공 -> XP 획득 -> Launch Tech 강화 -> Destination 클리어` 루프
2. `Facility Upgrades`가 영구 성장이라는 점
3. 새로운 Tier로 갈수록 기본 성공률이 내려간다는 점
4. `T3`부터 `Stress / Overload / Abort`가 실질 리스크로 작동한다는 점

포스트 랜딩 BM의 목표는 결제를 강요하는 것이 아니라, 이미 이해한 루프를 더 오래, 더 깊게, 더 안정적으로 즐기게 만드는 것이다.

### 1.2 두 플랫폼 트랙

Star Reach는 단일 Godot 4.6 코드베이스에서 두 트랙을 동시 운영한다.

| 트랙 | 채널 | BM 성격 |
|---|---|---|
| **Mobile (Android / iOS)** | IAP / Rewarded Ads / Subscription / Battle Pass | 소액 다회 결제, 광고 보상, 구독 + 시즌 패스 |
| **Steam (PC)** | Standard Edition + Deluxe / DLC / Cosmetic DLC | 본편 1회 + 확장 DLC + 코스메틱 DLC. **광고 / 소액 IAP / 가챠 없음** |

따라서 같은 Stage라도 **두 플랫폼의 노출 전략이 다르다**. 본문은 Stage별로 두 트랙을 모두 명시한다.

---

## 2. 현재 콘텐츠 기준 BM 핵심 인사이트

### 2.1 성공률 구조는 이미 BM 훅이 분명하다

현재 밸런스는 구간형 성공률 구조다.

| 구간 | 기본 성공률 | 재도전 상한 |
|---|---:|---:|
| T1 | 50% | 85% |
| T2 | 44% | 78% |
| T3 | 36% | 72% |
| T4 | 28% | 66% |
| T5 | 22% | 60% |

이 구조 때문에 BM이 붙을 수 있는 축은 명확하다.

1. `XP 성장 가속`
2. `Launch 속도 가속`
3. `새 구간 진입 시 성공률 보정`
4. `T3+` 리스크 방어

### 2.2 세션 성장과 영구 성장이 분리되어 있어 상품 축이 자연스럽다

현재 구조는 아래처럼 나뉜다.

1. `Launch Tech` — 세션 성장, Destination 변경 시 리셋 (XP 사용)
2. `Facility Upgrades` — 영구 성장, Credit 사용
3. `Program Lv.` — Destination 해금 축 (TechLevel 사용)

따라서 BM도 아래처럼 분리하는 것이 가장 자연스럽다.

1. **세션형 BM** — `IAP_BOOST_2X`, `IAP_AUTO_FUEL`, `IAP_TRAJECTORY_SURGE`
2. **영구 편의 BM** — `IAP_VIP`, `IAP_AUTO_LAUNCH_PASS`
3. **중장기 보정 BM** — `IAP_GUIDANCE_MODULE`
4. **리스크 방어 BM** — `IAP_SYSTEM_PURGE`, `IAP_SHIELD_T3/T4/T5`
5. **장기 유지 BM** — `Subscription Orbital Operations Pass`, `Battle Pass`
6. **Steam 전용** — Expansion DLC / Cosmetic DLC

### 2.3 T3부터는 명확한 방어형 BM 타이밍이 생긴다

현재 `Stress`는 `T3`부터 시작한다.

| Tier | 실패당 Stress | Abort 확률 | Repair Cost |
|---|---:|---:|---:|
| T3 | 10 | 40% | 300 Credit |
| T4 | 15 | 50% | 700 Credit |
| T5 | 20 | 60% | 1500 Credit |

이 수치는 매우 중요하다.
`IAP_SYSTEM_PURGE`와 `IAP_SHIELD_*`는 초반 BM이 아니라 **T3 진입 이후 장기 플레이 보호 상품**으로 노출해야 가장 자연스럽다. T1~T2 구간에서는 노출 자체가 불필요하다.

### 2.4 Credit 직접 판매는 노출 시점이 매우 중요하다

현재 `Facility Upgrades`는 `8 Credit`부터 시작해 `1.2x` 성장 공식을 쓴다. Destination 클리어 보상은 대략 아래처럼 뛴다.

| 구간 | Destination 보상 범위 |
|---|---|
| T1 | 5 ~ 15 Credit |
| T2 | 18 ~ 45 Credit |
| T3 | 50 ~ 110 Credit |
| T4 | 130 ~ 280 Credit |
| T5 | 320 ~ 800 Credit |

이 구조에서 `IAP_CREDIT_S`를 T1 구간에 팔면 영구 경제가 바로 무너진다. 따라서 Credit Pack은 다음 게이트를 따른다.

| 상품 | 노출 게이트 |
|---|---|
| `IAP_CREDIT_S` ($0.99 / +500 C) | T2 진입 후 |
| `IAP_CREDIT_M` ($4.99 / +3,000 C) | T3 진입 후 |
| `IAP_CREDIT_L` ($9.99 / +7,500 C) | T4 진입 후 |

또한 `TechLevel` 직접 판매 IAP는 **존재하지 않는다** (단조 증가축 P2W 방어선).

### 2.5 Steam은 BM 구조 자체가 다르다

PC 게이머 문화상 Steam에서는 다음을 적용하지 않는다.

1. 광고 (Rewarded Ad 전부 미노출)
2. 소액 소모 IAP (`IAP_BOOST_2X`, `IAP_AUTO_FUEL`, `IAP_SYSTEM_PURGE` 등 전부 미노출)
3. 구독형 상품 (`Orbital Operations Pass` 미판매)
4. Battle Pass (시즌 패스 형태 미판매)
5. 확률성 가챠

대신 **Standard Edition $14.99 / Deluxe Edition $24.99** 본편 + **Expansion DLC ($7.99)** + **Cosmetic DLC ($2.99)** + **Supporter DLC ($4.99~$9.99)** 만 운영한다. Steam 트랙의 Stage A~D 노출은 **DLC CTA 타이밍과 도감/업적 동기 부여**가 중심이다.

---

## 3. 포스트 랜딩 유저 구간 정의

| 구간 | 실제 상태 | 플레이 감정 | BM 초점 |
|---|---|---|---|
| **Stage A** | `T1 첫 클리어 ~ T2 초입` | 이제 반복 플레이 가치가 보이기 시작 | 첫 결제 전환, 속도 보정, 코스메틱 진입 |
| **Stage B** | `T2 중반 ~ T3 초입` | 실패가 늘고 성장 최적화가 재밌어짐 | 세션 가속, 확률 보정, Battle Pass 도입 |
| **Stage C** | `T3 중반 ~ T4` | Stress와 Abort가 체감됨 | 리스크 방어, 구독 도입, Steam DLC CTA |
| **Stage D** | `T5 진입 이후` | 장기 목표, 도감 완성, 시즌 컬렉션 | 고가치 패키지, 구독 유지, Expansion DLC |

---

## 4. BM 설계 원칙

### 4.1 초반 결제는 `속도형`, 중후반 결제는 `보정형/방어형`

포스트 랜딩 직후에는 `IAP_VIP`, `IAP_BOOST_2X`, `IAP_AUTO_FUEL`처럼 세션 속도를 올려주는 상품이 가장 자연스럽다.
반대로 `IAP_GUIDANCE_MODULE`, `IAP_TRAJECTORY_SURGE`, `IAP_SYSTEM_PURGE`, `IAP_SHIELD_*`는 실제 난도 하락과 실패 리스크를 체감한 이후에 보여줘야 한다.

### 4.2 코어 룰을 부수는 상품은 만들지 않는다

다음은 카탈로그에 존재하지 않는다.

1. Destination 즉시 클리어 티켓
2. 100% 성공 보장권
3. T1~T2 구간 전용 리바이브
4. 초중반 Credit 직접 판매 (T2 이전 노출 금지)
5. `Program Lv.` / `TechLevel` 직접 판매 IAP

### 4.3 상품은 반드시 현재 콘텐츠의 아픔과 연결되어야 한다

| 플레이어 아픔 | 맞는 상품 (`docs/bm.md` 참조) |
|---|---|
| XP가 느리다 | `IAP_VIP`, `IAP_BOOST_2X` |
| Auto Launch가 답답하다 | `IAP_AUTO_LAUNCH_PASS`, `IAP_AUTO_FUEL` |
| 새 구간 진입 성공률이 낮다 | `IAP_GUIDANCE_MODULE`, `IAP_TRAJECTORY_SURGE` |
| T3 이후 Stress가 쌓인다 | `IAP_SYSTEM_PURGE` |
| T4/T5 Abort 손실이 크다 | `IAP_SHIELD_T3/T4/T5` |
| Credit이 모자라 다음 Facility를 못 찍는다 | `IAP_CREDIT_S/M/L` (Stage 게이트 적용) |
| 매일 들어올 이유가 약하다 | `Subscription Orbital Operations Pass`, Daily Reward |
| 시즌 한정 코스메틱이 갖고 싶다 | `Battle Pass` (Mobile), `DLC_ROCKET_SKINS_PACK_*` (Steam) |

### 4.4 노출 빈도는 `docs/bm.md` §11.2 규칙을 따른다

1. 첫 접속 5분 내 BM 모달 금지
2. 같은 상품을 2회 연속 닫으면 7일 재노출 금지
3. 한 세션에서 강한 BM 모달은 최대 2회
4. Stress 관련 상품은 `Stress > 0`일 때만
5. 광고 버튼은 일일 한도 초과 시 숨김
6. **VIP 보유 시 광고 / VIP CTA 완전 비표시**

---

## 5. Stage A — T1 첫 클리어 ~ T2 초입

### 5.1 유저 상태

- T1을 처음 클리어했고, T2 진입을 막 시작한 시점
- 반복 루프의 가치를 인지하기 시작
- 아직 Stress / Abort / Overload 메커닉을 체험하지 못함
- `IAP_VIP` 미보유 시 광고 보상 채널이 매력적

### 5.2 Mobile 트랙 — 추천 상품 레일

| 우선순위 | 상품 | 가격 (USD) | 노출 형태 |
|---|---|---:|---|
| 1 | `IAP_STARTER_PACK` | $4.99 | T1 첫 클리어 직후 24h 한정 모달 |
| 2 | `IAP_VIP` | $2.99 | T1 완료 Win 화면 하단 추천 카드 |
| 3 | `IAP_BOOST_2X` | $1.49 | Shop 상단 추천 카드 |
| 4 | `IAP_AUTO_FUEL` | $0.99 | Auto Launch HUD 인라인 버튼 |
| 5 | `IAP_AUTO_LAUNCH_PASS` | $4.99 | Auto Launch 30분 누적 사용 시 Shop 상단 |
| 6 | `IAP_FIRST_MISSION_PACK` | $2.99 | T2 첫 진입 직후 모달 (이때부터 Stage B 전환) |
| 7 | `Battle Pass` (Free 트랙 자동 진입) | — / Premium $9.99 (시즌 첫 14일 $6.99) | T1 완료 직후 Pass 탭 NEW 뱃지 |

### 5.3 Mobile 트랙 — 광고 노출

| 광고 채널 | 노출 시점 | 일일 한도 |
|---|---|---:|
| Win 화면 광고 | 모든 목적지 완료 시 | 5회 |
| 일일 보상 광고 | DailyRewardModal 클레임 직전 | 1회 |
| Auto Fuel 충전 광고 | Auto Fuel 만료 직후 | 4회 |

> Stage A에서는 Abort 광고는 노출되지 않는다 (Abort 자체가 T3+ 발생).

### 5.4 Steam 트랙 — Stage A 전략

Steam에서는 본편을 이미 구매한 유저이므로 Stage A의 BM 노출은 **소비형 상품 0건**이다. 대신 다음을 활성화한다.

| 항목 | 노출 |
|---|---|
| Steam Achievements 진행 | T1 클리어 시 `KARMAN_LINE` 등 자동 트리거 |
| Cosmetic DLC CTA (소프트) | 메인 메뉴 사이드 카드 (`DLC_TRAIL_FX_PACK`, `DLC_LAUNCHPAD_THEMES`) |
| Steam Cloud 동기화 안내 | 첫 접속 시 1회 토스트 |

### 5.5 Stage A 운영 메모

1. **첫 결제 전환 핵심 KPI**는 `IAP_STARTER_PACK` 24h 한정 노출의 전환율이다.
2. Stage A 유저는 `성공률을 돈으로 사는 느낌`보다 `반복 속도가 빨라지는 느낌`에 더 잘 반응한다 → 확률 보정형 (`IAP_GUIDANCE_MODULE`, `IAP_TRAJECTORY_SURGE`) 노출은 Stage B로 미룬다.
3. Stress 관련 상품 (`IAP_SYSTEM_PURGE`, `IAP_SHIELD_*`)은 **노출 자체를 차단**한다 (`highest_completed_tier < 3` 가드).
4. `IAP_CREDIT_*`는 Stage A 동안 Shop 카탈로그에 표시되지 않는다.
5. VIP 보유 시 모든 광고 버튼과 VIP CTA는 즉시 비표시 (`docs/bm.md` §11.2).

---

## 6. Stage B — T2 중반 ~ T3 초입

### 6.1 유저 상태

- 같은 Destination을 여러 번 시도하며 실패율을 체감
- `Launch Tech` 빌드 최적화에 흥미가 생김
- T3 진입 직전이지만 Stress 메커닉은 아직 미체험
- 첫 결제를 이미 했거나, Stage A에서 결제하지 않은 채 진입

### 6.2 Mobile 트랙 — 추천 상품 레일

| 우선순위 | 상품 | 가격 (USD) | 노출 형태 |
|---|---|---:|---|
| 1 | `IAP_GUIDANCE_MODULE` | $5.99 | T2 첫 진입 시 1회 모달, 이후 같은 Destination 3회 실패 시 사이드 카드 |
| 2 | `IAP_TRAJECTORY_SURGE` | $1.99 | 같은 Destination 3회 실패 화면 우측 인라인 카드 |
| 3 | `IAP_AUTO_LAUNCH_PASS` | $4.99 | Auto Launch 60분 이상 누적 사용 시 |
| 4 | `IAP_CREDIT_S` | $0.99 | Facility Upgrade 화면에서 `Credit < 다음 업그레이드 비용`일 때 |
| 5 | `IAP_BOOST_2X` | $1.49 | 일일 미션 갱신 시점 / 30분 이상 미접속 후 재방문 |
| 6 | `Battle Pass` Premium | $9.99 (시즌 첫 14일 $6.99) | Pass 탭 진행도 도달 강조 (시즌 시작 후 1주일 내) |
| 7 | `IAP_WEEKLY_DEAL` | $4.99 ~ $9.99 | 매 일요일 갱신 시 1회 모달 |

### 6.3 Mobile 트랙 — 광고 노출

Stage A 광고에 더해 다음이 추가될 수 있다 (Abort는 T3 진입 시점부터).

- Win 화면 광고 일일 한도 5회 유지
- 일일 보상 광고 유지

### 6.4 Steam 트랙 — Stage B 전략

| 항목 | 노출 |
|---|---|
| Cosmetic DLC CTA (강화) | T2 첫 진입 직후 1회 모달 (`DLC_ROCKET_SKINS_PACK_1`) |
| 도감 진행도 보너스 25% 달성 시 | 칭호 + Credit 보너스 + Achievements 트리거 |
| Supporter DLC 미노출 | Stage C 이후 노출 |

### 6.5 Stage B 운영 메모

1. **`IAP_GUIDANCE_MODULE`은 첫 세션 5분 이내 모달 노출 금지** (`docs/bm.md` §11.2). T2 첫 진입 시점이라도 5분 가드를 통과해야 함.
2. `Battle Pass Premium` 첫 14일 30% 할인은 **시즌 시작일 기준** 카운트, T2 진입 시점과 무관.
3. Credit Pack 노출은 항상 `Facility Upgrade UI`에서 결핍 시점에 인라인으로만 — 강제 모달 금지.
4. Stage B에서 `IAP_TRAJECTORY_SURGE`와 `IAP_GUIDANCE_MODULE`이 동시에 노출되지 않도록 가드 (같은 실패 카운트로 두 개를 동시에 트리거하지 말 것).

---

## 7. Stage C — T3 중반 ~ T4

### 7.1 유저 상태

- T3 첫 진입을 통과했고 첫 Overload / 첫 Abort를 경험
- Stress 게이지를 처음 체감
- `실패가 아깝다`는 감정이 핵심
- 매일 들어와서 Facility를 한 칸씩 올리는 루프가 자리잡음

### 7.2 Mobile 트랙 — 추천 상품 레일

| 우선순위 | 상품 | 가격 (USD) | 노출 형태 |
|---|---|---:|---|
| 1 | `IAP_RISK_RECOVERY_PACK` | $4.99 | T3 첫 Overload 또는 첫 Abort 직후 24h 한정 모달 |
| 2 | `IAP_SYSTEM_PURGE` | $0.99 | `Stress >= 50`일 때 HUD 인라인 버튼, `Stress >= 70`에서 강조 |
| 3 | `IAP_SHIELD_T3` | $2.99 | 첫 T3 Abort 직후 AbortScreen CTA |
| 4 | `IAP_SHIELD_T4` | $4.99 | T4 진입 시 Destination 선택 화면 사이드 카드 |
| 5 | `Subscription Orbital Operations Pass` | $4.99/월 (7일 무료 체험) | T3 첫 진입 시 1회 모달 + Shop 상단 고정 |
| 6 | `IAP_CREDIT_M` | $4.99 | Facility Upgrade 결핍 시 인라인 |
| 7 | `IAP_GUIDANCE_MODULE` (미보유 유저) | $5.99 | T3 같은 Destination 3회 실패 |

### 7.3 Mobile 트랙 — 광고 노출

Stage C에서 처음으로 Abort 광고가 활성화된다.

| 광고 채널 | 노출 시점 | 일일 한도 |
|---|---|---:|
| Abort 화면 광고 | Abort 발생 시 | 3회 |
| Win 화면 광고 | 목적지 완료 시 | 5회 (유지) |
| 일일 보상 광고 | DailyRewardModal | 1회 (유지) |
| Auto Fuel 충전 광고 | Auto Fuel 만료 직후 | 4회 (유지) |

> Subscription 보유자는 광고 완전 제거 — Abort 화면 광고 버튼도 비표시.

### 7.4 Steam 트랙 — Stage C 전략

| 항목 | 노출 |
|---|---|
| Expansion DLC `DLC_INTERSTELLAR_FRONTIER` ($7.99) | T3 첫 클리어 시 메인 메뉴 사이드 카드 (출시되어 있을 경우) |
| Cosmetic DLC 추가 노출 | `DLC_ROCKET_SKINS_PACK_2`, `DLC_LAUNCHPAD_THEMES` |
| Supporter DLC | `DLC_OST` ($4.99) — T3 첫 클리어 후 1회 모달 |
| Achievements | T3 도달 업적 트리거 (`MARS_OLYMPUS` 등) |
| 도감 진행도 50% 보너스 | 메타 보너스 풀 (`docs/bm.md` §10) |

### 7.5 Stage C 운영 메모

1. **Subscription 노출은 T3 첫 진입에 정확히 1회**만 강한 모달. 이후 Shop 상단 고정 카드로 유지하되 모달은 7일 가드.
2. `IAP_SHIELD_*`는 **현재 도전 중인 Tier에 맞는 상품**만 강조. T4 도전자에게 `IAP_SHIELD_T3` 강조 금지.
3. `IAP_SYSTEM_PURGE`는 모달이 아니라 **HUD 인라인 버튼**이 기본. Stress가 0에 가까울 때는 추천하지 않음.
4. Abort 광고와 `IAP_SHIELD_*`는 같은 AbortScreen에서 함께 노출 (광고는 50% 환불, Shield는 100% 면제).
5. Steam Subscription 미판매 — Subscription CTA는 Mobile 빌드에서만 동작.
6. Steam에서 Abort가 발생해도 광고 / Shield IAP CTA 모두 노출하지 않음. 대신 Achievements `ZERO_FAILURE_*` 진행도 손실 안내만.

---

## 8. Stage D — T5 진입 이후

### 8.1 유저 상태

- T5 첫 진입을 했거나 진행 중
- 100개 도감 중 70~90% 완성을 향해 가는 장기 유저
- 단순 성장보다 **장기 동기 / 컬렉션 / 도감 완성**이 중심
- 누적 플레이타임이 50시간 이상

### 8.2 Mobile 트랙 — 추천 상품 레일

| 우선순위 | 상품 | 가격 (USD) | 노출 형태 |
|---|---|---:|---|
| 1 | `IAP_INTERSTELLAR_PACK` | $14.99 | T5 첫 진입 직후 24h 한정 모달 |
| 2 | `IAP_SHIELD_T5` | $9.99 | T5 Destination 선택 화면 사이드 카드 / 첫 T5 Abort 직후 |
| 3 | `Subscription Orbital Operations Pass` (미보유 유저) | $4.99/월 | T5 첫 클리어 후 Shop 상단 강조 |
| 4 | `IAP_CREDIT_L` | $9.99 | Facility Upgrade 결핍 시 인라인 |
| 5 | `IAP_ZONE_UNLOCK_PACK` | $9.99 ~ $29.99 | 신규 Zone 첫 진입 시 1회 모달 |
| 6 | `Battle Pass` Premium (시즌 후반 미보유 유저) | $9.99 | 시즌 종료 7일 전 Last Chance 모달 |
| 7 | `IAP_TRAJECTORY_SURGE` | $1.99 | T5 같은 Destination 3회 실패 화면 |

### 8.3 Mobile 트랙 — 광고 노출

Stage C와 동일. Subscription 보유자는 모든 광고 비표시.

### 8.4 Steam 트랙 — Stage D 전략

Steam에서 가장 BM 노출이 활발한 구간이다.

| 우선순위 | 상품 | 가격 (USD) | 노출 형태 |
|---|---|---:|---|
| 1 | `DLC_INTERSTELLAR_FRONTIER` | $7.99 | T5 첫 진입 시 메인 메뉴 강조 모달 (1회) |
| 2 | `DLC_DEEP_SPACE_EDGE` | $7.99 | 출시 시점 + Interstellar Frontier 클리어 후 |
| 3 | `DLC_SUPPORTER_PACK` | $9.99 | 도감 75% 달성 시 1회 모달 |
| 4 | `DLC_OST` / `DLC_ARTBOOK` | $4.99 | 메인 메뉴 사이드 카드 상시 |
| 5 | Cosmetic DLC 미보유분 | $2.99 | 시즌 컬렉션 패널에서 인라인 |

### 8.5 메타 보너스 풀 노출 (양 플랫폼 공통)

`docs/bm.md` §10에 정의된 메타 보너스를 Stage D에서 본격 활용.

| 메커니즘 | Stage D 트리거 |
|---|---|
| 누적 플레이타임 칭호 | 100h / 500h / 1000h 도달 시 토스트 |
| 도감 진행도 보너스 | 50% / 75% / 100% 도달 시 모달 |
| 시즌 컬렉션 완료 | 시즌 종료 시점 컬렉션 완성 시 한정 코스메틱 |
| 첫도달 마일스톤 | 50 / 75 / 100번째 Destination 첫 도달 시 영상 + 대량 Credit |
| Region Mastery | 지역 모든 목적지 클리어 시 칭호 |

### 8.6 Stage D 운영 메모

1. **T5 진입은 게임의 엔드게임 진입 시점**이다. 이 구간에서 결제 모달을 남발하면 이탈로 이어짐 — 모달은 T5 첫 진입 / 첫 클리어 / Zone 첫 진입에만 1회씩.
2. Subscription 유지율이 가장 중요한 구간. 만료 7일 전 갱신 안내 토스트 필수.
3. Steam Expansion DLC 노출은 본편 클리어 후 자연스러운 다음 단계로 제시. 강한 모달은 1회만.
4. Battle Pass `Last Chance` 모달은 시즌 종료 7일 전과 1일 전 각 1회만 (총 2회 한도).
5. `IAP_ZONE_UNLOCK_PACK`은 **그 Zone의 모든 목적지에 대해 +50% 보상 영구**라는 강한 효과이므로 Zone 진입 시 단 1회만 모달, 이후는 Shop 카탈로그에서만 노출.
6. 도감 100% 달성 후에는 BM 노출이 거의 정지되어야 한다. 이 시점 유저는 Battle Pass 신규 시즌 또는 Expansion DLC 외에 결제 동기가 거의 없다.

---

## 9. 노출 타이밍과 UI 규칙 매트릭스

### 9.1 Mobile 노출 매트릭스

| 상황 | 노출 상품 | 노출 형태 | 빈도 제한 |
|---|---|---|---|
| `T1 첫 클리어` 직후 | `IAP_STARTER_PACK` | 24h 한정 모달 | 1회 |
| `T1 완료` Win 화면 | `IAP_VIP`, `IAP_BOOST_2X` | 화면 하단 카드 | 1회 |
| `T2 첫 진입` | `IAP_GUIDANCE_MODULE`, `IAP_FIRST_MISSION_PACK` | Win/Unlock 화면 모달 | 1회 |
| `Auto Launch` 30분+ 사용 | `IAP_AUTO_LAUNCH_PASS`, `IAP_AUTO_FUEL` | Shop 상단 추천 카드 | 하루 1회 |
| 같은 Destination 3회 실패 (T2+) | `IAP_GUIDANCE_MODULE`, `IAP_TRAJECTORY_SURGE` | 실패 화면 우측 카드 | 24시간 1회 |
| `T3 첫 진입` | `Subscription Orbital Operations Pass` | 모달 | 1회 |
| `T3 첫 Overload` 또는 `첫 Abort` | `IAP_RISK_RECOVERY_PACK` | 24h 한정 모달 | 1회 |
| `Stress >= 50` | `IAP_SYSTEM_PURGE` | HUD 인라인 버튼 | 지속 노출 |
| `Stress >= 70` | `IAP_SYSTEM_PURGE` | HUD 강조 | 지속 노출 |
| 첫 `Abort` (Tier별) | `IAP_SHIELD_T3/T4/T5` | Abort 화면 CTA | 세션당 1회 |
| Abort 화면 | Abort 광고 | Abort 화면 광고 버튼 | 일일 3회 |
| Win 화면 | Win 광고 | Win 화면 광고 버튼 | 일일 5회 |
| `Facility Credit` 결핍 | `IAP_CREDIT_S/M/L` (Stage 게이트) | Facility UI 인라인 | 모달 없음 |
| 매주 일요일 | `IAP_WEEKLY_DEAL` | Shop 상단 모달 | 주 1회 |
| Zone 첫 진입 | `IAP_ZONE_UNLOCK_PACK` | 모달 | Zone당 1회 |
| 시즌 시작 | `Battle Pass` Premium 30% 할인 | Pass 탭 강조 | 시즌당 1회 |
| 시즌 종료 7일 전 | `Battle Pass` Last Chance | 모달 | 1회 |
| `T5 첫 진입` | `IAP_INTERSTELLAR_PACK` | 24h 한정 모달 | 1회 |

### 9.2 Steam 노출 매트릭스

| 상황 | 노출 상품 | 노출 형태 | 빈도 제한 |
|---|---|---|---|
| `T1 첫 클리어` | Achievements 진행 + Cosmetic DLC 사이드 카드 | 메뉴 사이드 카드 | 상시 |
| `T2 첫 진입` | `DLC_ROCKET_SKINS_PACK_1` | 메뉴 사이드 카드 | 1회 모달 |
| `T3 첫 클리어` | `DLC_OST`, `DLC_ROCKET_SKINS_PACK_2` | 메뉴 모달 | 1회 |
| 도감 25% / 50% / 75% / 100% | 메타 보너스 + 칭호 | 모달 | 각 1회 |
| `T5 첫 진입` | `DLC_INTERSTELLAR_FRONTIER` | 메인 메뉴 강조 모달 | 1회 |
| Expansion DLC 클리어 | 다음 Expansion DLC | 메뉴 사이드 카드 | 출시 시 1회 |
| Achievements 100% (114개) | `DLC_SUPPORTER_PACK` | 모달 | 1회 |

### 9.3 공통 운영 규칙 (`docs/bm.md` §11.2 재정리)

1. 첫 접속 후 5분 안에는 강한 BM 모달 금지
2. 같은 상품을 2회 연속 닫으면 7일 재노출 금지
3. 한 세션에서 강한 BM 모달은 최대 2회
4. T1 미완료 유저에게 유료 CTA 최소화 (`IAP_STARTER_PACK` 외 노출 금지)
5. Stress 관련 상품은 실제 Stress가 쌓일 때만 노출 (`Stress > 0`)
6. 광고 버튼은 일일 한도 초과 시 비표시
7. **`IAP_VIP` 보유 시 광고 / VIP CTA 완전 비표시**
8. **Subscription 보유 시 광고 완전 비표시 + Subscription CTA 비표시**
9. Steam 빌드는 광고 / 소액 IAP / Subscription / Battle Pass UI 자체를 컴파일 가드로 비활성화

---

## 10. 지금 노출하면 안 되는 상품

### 10.1 구현 보강이 먼저 필요한 항목

`docs/bm.md` Phase 0 / Phase 1 작업이 끝나기 전에는 노출하지 않는다.

| 상품 | 선결 조건 |
|---|---|
| `IAP_AUTO_FUEL` | `auto_launch_service.gd::get_rate()`에 실제 +0.5/s 가산 적용 (Phase 0-2) |
| `IAP_AUTO_LAUNCH_PASS` | 무료 Auto Launch 해금 구조 분리 완료 (Phase 0-1) |
| 모든 IAP | `iap_service.gd` 영수증 검증 + 멱등성 가드 구현 (Phase 0-3) |
| `Subscription Orbital Operations Pass` | `subscription_service.gd` + 영수증 자동 갱신 검증 (Phase 2-4) |
| `Battle Pass` | 시즌 XP / 트랙 / 보상 시스템 (Phase 2-6) |
| `DLC_*` | GodotSteam 통합 검증 + Steamworks 등록 완료 (Phase 3) |

### 10.2 카탈로그에 존재하지 않는 항목

다음 형태의 상품은 만들지 않는다.

1. `Credit Pack` — T2 진입 이전 노출
2. `TechLevel Pack` — Program Lv. 직접 판매 (단조 증가축 P2W 방어선)
3. `Guaranteed Success Ticket` — 100% 성공 보장권
4. `Destination Skip Ticket` — 즉시 클리어
5. T1/T2 전용 Revive — 초반 리스크가 약하므로 불필요
6. Steam 빌드용 광고 / 소액 IAP / 가챠

---

## 11. 개발 우선순위 (이 문서 관점)

`docs/bm.md` §12의 Phase 구분을 기준으로, 각 Stage의 노출 로직을 어느 시점에 구현해야 하는지 정리한다.

### P0 — Phase 0~1 완료 시 즉시 가능

1. Stage 게이트 판단 유틸 (`bm_gate_service.gd::current_stage() -> Stage` enum)
2. `highest_completed_tier` 기반 노출 가드 (모든 IAP CTA 공통 적용)
3. Stress 기반 인라인 노출 (`IAP_SYSTEM_PURGE`)
4. AbortScreen CTA (`IAP_SHIELD_*` + Abort 광고)

### P1 — Phase 1 완료 시점

1. Stage A 노출 (`IAP_STARTER_PACK` 24h 한정, `IAP_VIP` Win 화면 카드)
2. Daily Reward / Daily Mission 노출 통합
3. Win 광고 / 일일 보상 광고 / Auto Fuel 충전 광고

### P2 — Phase 2 완료 시점

1. Stage B 노출 (`IAP_GUIDANCE_MODULE`, `IAP_TRAJECTORY_SURGE` 실패 카운트 트리거)
2. Stage C `Subscription` 모달 + Shop 상단 고정 카드
3. Battle Pass 시즌 시작 / 종료 모달

### P3 — Phase 3 완료 시점 (Steam)

1. Steam DLC CTA (`DLC_INTERSTELLAR_FRONTIER` 등)
2. Steam Achievements 트리거 (114개)
3. Steam 빌드 컴파일 가드 (광고 / Subscription / Battle Pass UI 비활성화)

### P4 — Phase 4~5

1. Stage D `IAP_INTERSTELLAR_PACK`, `IAP_ZONE_UNLOCK_PACK` 모달
2. 메타 보너스 풀 (도감 25/50/75/100%, 누적 플레이타임 칭호)
3. 시즌 컬렉션 / 첫도달 마일스톤 영상

---

## 12. 최종 제안

포스트 랜딩 BM의 핵심은 아래 한 줄로 정리된다.

> **T2까지는 속도를 팔고, T3~T4에서는 실패 리스크를 팔고, T5에서는 영향력과 장기 가치를 판다. Steam에서는 본편을 팔고, 그 다음 확장과 도감 완성을 판다.**

Star Reach는 이미 `구간형 성공률`, `세션 성장`, `영구 성장`, `Stress 리스크`가 분명하게 나뉘어 있다. 따라서 BM도 이 구조를 따라야 한다.

1. **Stage A 첫 결제는** `IAP_STARTER_PACK`, `IAP_VIP`, `IAP_BOOST_2X`, `IAP_AUTO_FUEL`
2. **Stage B 미드코어 전환은** `IAP_GUIDANCE_MODULE`, `IAP_AUTO_LAUNCH_PASS`, `Battle Pass` Premium
3. **Stage C 리스크 구간 핵심은** `IAP_SYSTEM_PURGE`, `IAP_SHIELD_T3/T4`, `Subscription Orbital Operations Pass`
4. **Stage D 엔드게임 핵심은** `IAP_INTERSTELLAR_PACK`, `IAP_SHIELD_T5`, `IAP_ZONE_UNLOCK_PACK`, 메타 보너스 풀
5. **Steam 트랙은** Stage C에서 `DLC_INTERSTELLAR_FRONTIER`와 Cosmetic DLC, Stage D에서 `DLC_SUPPORTER_PACK`과 Achievements 100% 동기 부여

이 순서가 현재 콘텐츠와 가장 잘 맞고, 두 플랫폼의 문화 차이를 존중하면서 초반 BM 거부감 없이 장기 매출 구조까지 이어질 수 있는 설계다.

---

## 13. 관련 문서

- `docs/bm.md` — IAP / DLC / Subscription 카탈로그 상세 사양 (가격 / 효과 / 데이터 구조 / 플랫폼 통합)
- `docs/prd.md` — 핵심 게임 사양
- `docs/design/game_overview.md` §7 — 수익 모델 개요
