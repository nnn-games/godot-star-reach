# Star Reach: 싱글플레이 우주 발사 증분 시뮬레이터 PRD

**복잡한 것은 버렸다. 도파민과 우주 스케일만 남겼다.**

## 1. 게임 개요 (Overview)

- **장르**: 증분 시뮬레이터 (Incremental Simulator) + 업그레이드 / 라이트 타이쿤
- **핵심 비유**: 다단계 확률 판정 × 로켓 발사 × 지상~심우주 100개 목적지
- **플레이 모드**: **싱글 오프라인**
- **타겟 플랫폼**: **Android (Google Play)**, **iOS (App Store)**, **PC Steam**
- **엔진**: **Godot 4.6** (단일 코드베이스, 플랫폼별 빌드)
- **대상 연령**: 전 연령 (모바일·Steam 양쪽 ESRB E / PEGI 7 목표)
- **세션 길이**: 단기 5~15분 액티브 세션 + 장기 복귀형 데일리 + 오프라인 자동 진행
- **설계 철학**: 강제하지 않는다. 선택하게 만든다. 실패는 자원이다.

**Star Reach**는 작은 우주 스타트업의 운영자가 되어, 다단계 확률 판정으로 로켓을 쏘아 올리고, 실패에서 얻은 XP로 기술을 강화하며, 지구 대류권에서 은하 중심 블랙홀까지 100개 이상의 실제 천체에 도달하는 증분 시뮬레이터입니다.

## 2. 핵심 코어 5가지 (Core Mechanics)

1. **다단계 확률 발사 루프** — 1~10단계 독립 확률 판정. 모든 단계를 통과해야 목적지 완료. 단계당 약 2초, 한 발사 6~20초.
2. **3화폐 분리 경제** — XP(세션) / Credit(영구) / TechLevel(해금). 교환 금지로 각 축의 의사결정이 독립적.
3. **구간형 확률 상한** — 한 번 정복한 Tier 구간은 이후 발사에서 자동으로 `maxChance` 적용. "역행 감각" 제거.
4. **Stress / Overload / Abort** — T3 화성 이상부터 활성화되는 리스크 레이어. 무리하면 수리비, 쉬면 자연 감쇠.
5. **오프라인 자동 진행** — 마지막 종료 시점부터의 시간 차로 자동 발사를 시뮬. 캡 8시간. 복귀 시 "오프라인 요약" 모달.

## 3. 핵심 게임플레이 루프 (Gameplay Loop)

### 3.1 마이크로 루프 (단일 발사, 6~20초)

```
[LAUNCH 탭]
  ↓
[Stage 1: 확률 판정 → 2초 상승 연출 (2D 애니메이션 또는 사전 렌더 영상)]
  ├─ 성공 → XP 즉시 지급 → Stage 2
  └─ 실패 → 자유낙하 연출 → 다음 발사 준비 (0.5초 내 재발사 가능)
[Stage N: ...]
  ↓
모든 단계 통과
  ↓
[목적지 완료] → Credit + TechLevel 보상 + 도감/뱃지 갱신
```

체감 쿨타임 약 0.8초 — 즉각 재시도가 도파민 루프의 생명.

### 3.2 매크로 루프 (5~15분 세션)

```
[메인 화면 진입]
  → 발사 패널 / LAUNCH 버튼 노출
  → N단계 발사 반복
  → 목적지 완료 시:
      ├─ Credit + TechLevel 지급
      ├─ Region 첫도달 시 Badge / Codex 갱신
      └─ TechLevel 충족 시 다음 목적지 자동 해금
  → Launch Tech (XP 소비, 세션형 5종) / Facility Upgrades (Credit 소비, 영구형 5종) 분기
  → [반복]
```

### 3.3 메타 루프 (여러 날)

```
일일 접속 → 일일 보상 (5~25 Credit + 부스터)
  → 일일 미션 3개 → 주간 미션 TechLevel 캡(500)
  → Program Level 상승 → 다음 Zone 해금
  → 도감/뱃지 컬렉션
  → 오프라인 자동 진행으로 비접속 보상 누적 (캡 8h)
```

## 4. 발사 결과 분포 (Tier별 기준값)

확률표는 `LaunchBalanceConfig` 리소스(`Resource` / `.tres`)에 분리. 하드코딩 금지.

| Tier | 구간 (Zone) | 스테이지 | baseChance | maxChance |
|---:|---|---:|---:|---:|
| 1 | Atmosphere (대기권) | 3~4 | 50% | 85% |
| 2 | Cislunar (달 궤도) | 5~6 | 44% | 78% |
| 3 | Mars Transfer | 7~8 | 36% | 72% |
| 4 | Outer Solar | 9 | 28% | 66% |
| 5 | Interstellar | 10 | 22% | 60% |

**확률 보정 합산 캡**: +55%p
- Launch Tech `enginePrecision`: 최대 +40%p
- Facility `engineTech`: 최대 +10%p
- IAP `Guidance Module Pass`: +5%p

## 5. 3화폐 경제

| 화폐 | 역할 | 획득 | 소비 | 리셋 |
|---|---|---|---|---|
| **XP** | 세션형 단기 성장 | 스테이지 성공 시 | Launch Tech 5종 | 목적지 변경 시 |
| **Credit** | 영구 성장 + 리스크 정산 | 목적지 완료 / Daily | Facility Upgrade 5종 / Stress 수리비 | 없음 |
| **TechLevel** | 해금 축 (단조 증가) | 목적지 완료 / Mission | (직접 소비 없음, 임계치 비교만) | 없음 |

**금지된 변환 경로**:
- XP → Credit ❌
- Credit → TechLevel ❌
- TechLevel 즉시 지급 IAP ❌ (단조 증가축은 P2W 방어선)

## 6. Stress / Overload / Abort (리스크 레이어)

T3 (Mars Transfer) 이상에서 활성화.

| Tier | 실패당 +Stress | Abort 확률 | Repair Cost |
|---:|---:|---:|---:|
| 1~2 | 0 | 0% | 0 C |
| 3 | +10 | 40% | 300 C |
| 4 | +15 | 50% | 700 C |
| 5 | +20 | 60% | 1,500 C |

- 5초 이상 대기 시 초당 자연 감쇠 (AFK로 해소 가능 → 강제 대기 페널티 회피)
- Launch Tech의 `Stress Bypass` 업그레이드로 누적량 감소 가능

## 7. 시각·연출 시스템 (Godot 2D 기반)

### 7.1 연출 원칙

> **2D + 사전 렌더 영상 조합**으로 모바일/Steam 양쪽에서 안정적인 60fps 재생.

| 영역 | Godot 2D 구성 |
|---|---|
| 로켓 본체 | `Sprite2D` + `AnimationPlayer` (대안: `AnimatedSprite2D`) |
| 배경 | `ParallaxBackground` + 레이어드 배경 텍스처 (전경/중경/원경/별) |
| 환경 색감 | `CanvasModulate` + `WorldEnvironment` 색조 보간 |
| 트윈 | Godot `Tween` / `AnimationPlayer` |
| 카메라 | `Camera2D` 스무딩 + `screen_shake` 헬퍼 |
| Sky Transition | Tier별 `SkyProfile.tres` (배경 텍스처 + 색조 + 파티클 프리셋) → `Tween`으로 보간 |
| 발사 → 목적지 도달 핵심 컷 | **사전 렌더 영상**(`VideoStreamPlayer`, .ogv) — 핵심 마일스톤 (10/25/50/75/100) 한정 |

### 7.2 영상 사용 정책

- **모든 발사를 영상으로 재생하지 않는다** — 도파민 루프(0.8초 쿨)를 유지해야 함.
- 영상은 **첫 도달 / 마일스톤(10/25/50/75/100) / 목적지별 1회 보상 컷** 등 **저빈도 이벤트**에만 사용.
- 영상 길이는 5~12초. 스킵 가능 (2회차부터는 자동 스킵 옵션).
- 모바일 빌드 용량 압박을 위해 영상은 H.264 또는 Theora(.ogv), 720p 24fps, 평균 비트레이트 1.5Mbps 이하.

## 8. 미니멀 UX (Minimal UX)

화면의 모든 요소는 **"지금 LAUNCH를 누를 가치가 있나?"** 한 가지 판단에 기여.

| 영역 | 요소 | 비고 |
|---|---|---|
| **하단 중앙** | 🚀 LAUNCH 버튼 (대형 원형, 0.8초 펄스) | 가장 중요. 화면 어디든 손가락으로 즉시 닿게 |
| **상단 중앙** | 현재 목적지명 + 진행 단계 (예: 3 / 7) | |
| **상단 좌측** | XP / Credit / TechLevel 3화폐 패널 | |
| **상단 우측** | 메뉴 (Upgrade / Codex / Settings) | |
| **하단 좌측** | Stress 게이지 (T3+ 활성화 시에만 노출) | |
| **하단 우측** | 자동 발사 토글 (해금 후 노출) | |
| **중앙 오버레이** | 발사 결과 텍스트 (성공/실패), 단계 통과 표시 | |

## 9. 저장 / 로드 / 오프라인

### 9.1 저장 포맷

- 경로: `user://savegame.json`
- 포맷: JSON (`FileAccess` + `JSON.stringify`)
- 스키마 버전 필드 필수 (`"version": 1`) → 로드 시 마이그레이션 훅
- 트리거: 10초 주기 + `NOTIFICATION_WM_CLOSE_REQUEST` + 수동 저장 버튼

### 9.2 오프라인 진행

- 저장 시 `Time.get_unix_time_from_system()` 기록
- 로드 시 델타 = `현재 - 저장 시간` 계산
- **캡 8시간** (그 이상은 잘라냄)
- 복귀 시 모달: `오프라인 동안 자동 발사 N회 / Credit +X / XP +Y` 요약
- 자동 발사 미해금 시 캡 짧게 (1시간) 또는 0

### 9.3 클라우드 세이브 (V2)

- Steam Cloud (Steam 빌드)
- Google Play Games Saved Games / iCloud Key-Value (모바일)
- V1은 로컬 단독 — V2에서 동기화 추가

## 10. 수익 모델 (Monetization) — 플랫폼별 분리

> **모바일 IAP + Steam 프리미엄/DLC** 두 트랙으로 분리 설계.

### 10.1 공통 원칙

1. **P2W 금지** — IAP는 편의성·가속·코스메틱·확률 보정(투명 공개)만.
2. **확률 투명 공개** — 보정 상품은 "기본 5% → 8%" 식으로 수치 명시 (국내 확률형 아이템 표시 의무법 / Apple / Google 가이드라인 준수).
3. **진행도 게이트** — 첫 5분 IAP 모달 금지. Tier 해금에 맞춰 점진 노출.
4. **아동 보호** — 13세 미만 광고/결제 CTA 차단 (COPPA / GDPR-K).

### 10.2 📱 Mobile (Android / iOS) — F2P + 소액 IAP + 광고

| 채널 | 상품 | 가격대 | 의도 |
|---|---|---|---|
| Soft Currency Pack | Credit Pack S/M/L | $0.99 / $4.99 / $9.99 | 진입 장벽 최저 |
| Booster (소모) | 2x Boost (30분), Auto Fuel (60분), Trajectory Surge | $1.99 ~ $4.99 | 세션 내 즉각 효과 |
| Bundle | Starter Pack, Weekly Deal, Zone Unlock Pack | $9.99 ~ $29.99 | 진입 후 3일 내 핵심 전환 |
| Subscription | Orbital Ops Pass | $4.99/월 | 매일 소형 혜택 + 광고 제거 |
| Rewarded Ad | Abort 회피 / Daily Bonus / Auto-Fuel 충전 | 무료 (광고 수익) | 비결제 유저 간접 수익화 |
| Battle Pass (분기) | Season Pass (Free + Premium) | $9.99 | 리텐션 + 결제 동시 확보 |

플랫폼 정책:
- Apple/Google IAP 외 결제 금지 (디지털 재화)
- Apple Small Business Program / Google Play 15% 적용 신청 (≤$1M 매출)
- StoreKit / Google Play Billing 영수증 검증 + 멱등성 가드

### 10.3 🖥️ Steam (PC) — 프리미엄 1회 구매 + 시즌 DLC

| 채널 | 상품 | 가격대 | 의도 |
|---|---|---|---|
| Standard Edition | Star Reach 본편 | **$14.99** | 광고 없음 + 핵심 콘텐츠 전부 |
| Deluxe Edition | + 스킨 + OST + 아트북 PDF | $24.99 | 출시일 15% 상향 번들 |
| Expansion DLC | "Interstellar Frontier" 등 신규 Zone 5개 | $7.99 | 분기~반기 주기 |
| Cosmetic DLC | Rocket Skin Pack, Control Room Theme | $2.99 ~ $4.99 | 코어 팬 반복 결제 |
| OST / Supporter | 사운드트랙 + 크레딧 | $4.99 | 코어 팬 지원 |

플랫폼 정책:
- 환불 14일/2시간 → **첫 2시간 품질 확보**가 생명 (T1 첫 클리어 보장 튜토리얼)
- Steam Cloud 필수 / Steam Deck 호환 / Steam Achievements 100개 (목적지 1:1 매핑)
- 광고 없음 / 확률형 가차 없음 (PC 게이머 문화 충돌)

### 10.4 수익 믹스 비중 예상

| 플랫폼 | IAP | 광고 | 구독 | DLC/코스메틱 |
|---|---:|---:|---:|---:|
| Mobile | 50% | 25% | 15% | 10% |
| Steam | — | — | — | 100% (본편 + DLC + 코스메틱) |

## 11. 메타·컬렉션 (장기 동기 부여)

| 시스템 | 규모 | 설계 의도 |
|---|---|---|
| **Discovery / Codex** | 12 천체계 (Lite B) | "이 별을 나는 얼마나 알고 있나" |
| **Badge** | 19종 (Win 카운트 5 + 첫도달 14) | Steam Achievements / Google Play Games Achievements 매핑 |
| **Mission** | 주간 / 일일 (주간 TechLevel 캡 500) | 일일 3개 랜덤 풀 |
| **Best Records** | TotalWins / TechLevel / Best Tier | 로컬 최고 기록 + (V2) 플랫폼 리더보드 |

## 12. 시스템 의존 그래프

```
[Save / Autoload Singletons (GameState, EventBus, SaveSystem)]
  ↓
[Launch Core: Session → Multi-Stage → Stress → AutoLaunch]
  ↓ 성공/완료 이벤트 (Godot signal)
[Progression: Destination → Region → Program Lv. → LaunchTech / Facility]
  ↓ 보상 지급
[Economy: XP / Credit / TechLevel]
  ↓
[Cinematic / VFX (2D + Pre-rendered Video)]  +  [Meta: Discovery / Badge / Mission / BestRecords]
  ↓
[Monetization (Platform IAP)]
```

## 13. 개발 로드맵 (MVP 14주, Godot 단일 코드베이스)

| Phase | 기간 | 주요 작업 |
|---|---|---|
| **P1** | 1~2주차 | 확률 판정 엔진(`LaunchService`) + 발사 반복 루프 (`LaunchBalanceConfig.tres`) |
| **P2** | 3~4주차 | Multi-Stage Probability + Tier 구간 시스템 + Stress / Abort |
| **P3** | 5~6주차 | Sky/Lighting Transition (2D `ParallaxBackground` + `CanvasModulate`) |
| **P4** | 7~8주차 | Auto Launch + Daily / Mission / 도감 / 뱃지 |
| **P5** | 9~10주차 | UI Shell (LaunchApp / GlobalHUD) + 사전 렌더 영상 5종 (`VideoStreamPlayer`) |
| **P6** | 11~12주차 | IAP — Steam Microtransactions / Google Play Billing / StoreKit, 영수증 검증 |
| **P7** | 13~14주차 | 밸런스 QA + 사운드/이펙트 타이밍 + 출시 제출 (Steam Build Submission, App Store Review) |

Post-Launch: 2주 단위 업데이트 / 분기 신규 Zone DLC.

## 14. 관련 정본 문서

- `docs/design/game_overview.md` — 풀 개요 (벤치마크 포함)
- `docs/contents.md` — 100 목적지 콘텐츠
- `docs/launch_balance_design.md` — 확률 / 보상 곡선 상세
- `docs/systems/INDEX.md` — 시스템 카탈로그
- `docs/systems/ARCHITECTURE.md` — Mermaid 다이어그램
- `docs/porting/INDEX.md` — 시스템 1~4 디자인 관점 재서술
