# Star Reach — 출시를 위한 전체 개발 계획 (Godot 싱글 오프라인)

본 문서는 현재 프로토타입 상태(증분 시뮬 템플릿 + Phase 1.5 SaveSystem 완료)에서 목표로 하는 **'Android / iOS / PC Steam 동시 출시 싱글 오프라인 우주 발사 증분 시뮬'** 정식 출시까지 필요한 모든 개발 항목을 단계별(Phase)로 정의합니다.

> **전제**: 모든 Phase는 **Godot 4.6 단일 코드베이스** + 플랫폼별 빌드 (Android APK/AAB / iOS IPA / Windows·Linux Steam) 기준입니다.

---

## Phase 1: 핵심 시스템 코어 (Core Loop & Probability Engine)

가장 먼저 다단계 확률 엔진과 발사 반복 루프를 데이터 주도(`Resource`/`.tres`)로 구축합니다.

- [ ] **데이터 주도 확률 설계**: `LaunchBalanceConfig.tres`에 5 Tier × `baseChance / maxChance` 정의 (`Resource` 상속).
- [ ] **`LaunchService` 구현**: 단일 발사 호출 → N단계 확률 판정 → 단계별 `EventBus.stage_succeeded / stage_failed` 시그널 발화.
- [ ] **`LaunchSessionService`**: 세션 단위 컨텍스트 (현재 목적지, Tier, base modifiers 합산).
- [ ] **3화폐 `GameState` 오토로드**: `xp / credit / tech_level` 필드 + `add_*` / `spend_*` 메서드 + 변경 시그널.
- [ ] **결정적 시뮬 보장**: `RandomNumberGenerator.seed`를 세이브에 저장 → 동일 입력에서 동일 결과 재현 (오프라인 시뮬 정합성).
- [ ] **저장 스키마 확장**: `SaveSystem`에 v2 마이그레이션 (현 v1: 코인 기반 → v2: 3화폐 + 목적지 진행).

---

## Phase 2: Multi-Stage Probability + Stress / Abort

확률 엔진 위에 Tier 구간 시스템과 Stress 리스크 레이어를 얹습니다.

- [ ] **구간형 확률 상한**: `GameState.cleared_tiers`에 따라 정복 Tier의 스테이지를 자동 `maxChance`로 적용.
- [ ] **Pity System**: 연속 실패 카운트로 확률 미세 보정 (UI 노출 X).
- [ ] **`StressService`**: T3+ 활성. 실패당 Stress 누적, 5초 idle 후 초당 자연 감쇠 (`_process(delta)`).
- [ ] **Overload / Abort**: Stress > 100 → 다음 발사 시 Abort 확률 적용 → Credit 차감 (Repair Cost).
- [ ] **`Stress Bypass` 업그레이드 훅**: Launch Tech에서 누적량 감소 효과 적용.

---

## Phase 3: 시각·연출 시스템 (2D + 사전 렌더 영상)

3D 시네마틱과 Sky Transition을 Godot 2D 스택으로 재구현합니다.

- [ ] **`ParallaxBackground` 레이어 시스템**: Tier별 3~5장 텍스처 레이어 (전경/중경/원경/별).
- [ ] **`SkyProfile.tres` 리소스**: Tier별 색조, 배경 텍스처 ID, 파티클 프리셋, BGM 트랙.
- [ ] **`SkyProfileApplier`**: 목적지 변경 / 단계 통과 시 `Tween`으로 1.5~3초 보간.
- [ ] **`CanvasModulate` 색조 보간**: 전체 화면 톤 (예: 푸른 대기 → 칠흑 우주).
- [ ] **로켓 스프라이트 `AnimationPlayer`**: 정지 / 점화 / 가속 / 자유낙하 / 폭발 5종 트랙.
- [ ] **`Camera2D.shake_amplitude` 헬퍼**: 발사 / 실패 / 목적지 완료 펄스.
- [ ] **사전 렌더 영상 5종 (`VideoStreamPlayer` + .ogv)**:
  - 첫 카르만 선 돌파 / 첫 달 도달 / 첫 화성 도달 / 첫 토성 고리 도달 / 마지막 블랙홀 도달
  - 각 5~12초, 720p 24fps, 평균 1.5Mbps
  - 스킵 가능 / 2회차부터 자동 스킵 옵션

---

## Phase 4: Auto Launch + 메타·컬렉션

장기 동기 부여 시스템을 묶어 추가합니다.

- [ ] **`AutoLaunchService`**: T1 첫 클리어 / 누적 10회 발사 시 무료 해금. 0.5~2.5 launches/s 속도.
- [ ] **`OfflineProgressService`**: 종료 시 `last_saved_unix` 기록 → 재개 시 델타 시뮬 (캡 8h, 자동 발사 미해금 시 1h 또는 0).
- [ ] **오프라인 요약 모달**: 자동 발사 N회 / Credit +X / XP +Y 표시.
- [ ] **`DiscoveryService` (Codex)**: 12 천체계 도감.
- [ ] **`BadgeService`**: 19종 (Win 카운트 5 + 첫도달 14). Steam Achievements / Google Play Games Achievements 매핑 준비.
- [ ] **`MissionService`**: 일일 3개 / 주간 TechLevel 캡 500. 풀 정의 + 자동 롤링.
- [ ] **로컬 베스트 기록**: TotalWins / TechLevel / Best Tier — V2에서 플랫폼 리더보드 연동 훅 남기기.

---

## Phase 5: UI Shell + 사운드

플레이어가 매 순간 보고 듣는 표면을 만듭니다.

- [ ] **`MainScreen.tscn` UI 셸**: 상단 3화폐 / 중앙 발사 영역 / 하단 LAUNCH 버튼 + Stress / 자동 발사.
- [ ] **`UpgradePanel.tscn`**: Launch Tech / Facility Upgrades 두 탭.
- [ ] **`CodexPanel.tscn`**: 12 천체계 갤러리 + 첫도달 잠금 표시.
- [ ] **`SettingsPanel.tscn`**: 사운드 / 그래픽 / 자동 스킵 / 데이터 초기화.
- [ ] **`OfflineSummaryModal.tscn`**: 진입 시 1회 표시.
- [ ] **사운드 디자인**:
  - SFX: 점화 / 가속 / 단계 통과 / 폭발 / 자유낙하 / UI 클릭
  - BGM: 로비 (잔잔) / Atmosphere Tier (긴장) / Outer Solar (장엄) / Interstellar (몽환) — Tier별 크로스페이드
  - 모바일: 한 곡 ≤ 90초 루프, 압축 OGG Vorbis q=4

---

## Phase 6: 수익 모델 (IAP) — 플랫폼별 분리

플랫폼별 IAP / 광고 / 구독을 연동합니다.

### 6.1 Mobile (Android / iOS)

- [ ] **Google Play Billing 연동** (Android): GDScript 플러그인 또는 Godot Android 플러그인 (예: `godot-android-plugin-google-play-billing`).
- [ ] **StoreKit 연동** (iOS): Godot iOS plugin (커스텀 또는 커뮤니티 플러그인).
- [ ] **상품 정의**: Credit Pack S/M/L, 2x Boost, Auto Fuel, Trajectory Surge, Starter Pack, Weekly Deal, Zone Unlock Pack, Orbital Ops Pass (월구독).
- [ ] **영수증 검증**: 클라이언트 영수증 → Apple / Google 검증 (서버 없이 클라이언트 단독 검증, 멱등성 가드).
- [ ] **Rewarded Ad 연동**: AdMob Godot plugin — Abort 회피 / Daily Bonus / Auto-Fuel 충전.
- [ ] **연령 게이트**: 13세 미만 결제/광고 CTA 차단 (COPPA / GDPR-K).

### 6.2 PC (Steam)

- [ ] **GodotSteam 통합**: `addons/godotsteam`로 Steam SDK 래퍼 사용 (현재 프로젝트에 이미 설치되어 있음).
- [ ] **Steam Achievements 100개**: 목적지 1:1 매핑.
- [ ] **Steam Cloud 세이브**: `user://savegame.json` 자동 동기화 설정.
- [ ] **Steam Microtransactions** (DLC 위주): Standard Edition $14.99 / Deluxe $24.99 / Expansion DLC $7.99 / Cosmetic DLC $2.99~$4.99 / OST $4.99.
- [ ] **Steam Deck 호환 인증**: 컨트롤러 입력 매핑 + 텍스트 가독성 검증.

### 6.3 공통 BM 가드

- [ ] **P2W 0%**: 모든 IAP는 편의성·가속·코스메틱·확률 보정(투명 공개)만.
- [ ] **확률 보정 상품 수치 명시**: "기본 5% → 8%" UI에 직접 표기.
- [ ] **첫 5분 IAP 모달 금지** + Tier 해금 시 점진 노출.

---

## Phase 7: QA · 폴리싱 · 출시 (Release)

- [ ] **밸런스 튜닝**: T1 첫 클리어 ~3분, T5 마지막 클리어 ~120시간 목표.
- [ ] **튜토리얼 첫 2시간 보장** (Steam 환불 정책 방어): 첫 2~3발 100% 보정 + T1 첫 목적지 30분 내 클리어.
- [ ] **부하 테스트**: 100시간 누적 플레이 시뮬, 메모리 누수 / 세이브 파일 크기 확인.
- [ ] **다국어 (Localization)**: 한국어 / 영어 1차. `tr()` 호출 + `translation/*.po` 정리.
- [ ] **플랫폼별 빌드 검증**:
  - Android: 다양한 화면 비율 (16:9 / 19.5:9 / 폴더블), Android 8+ 호환
  - iOS: iPhone SE ~ Pro Max, iPad 호환, App Store Review Guidelines 준수
  - Steam: Windows 10/11 + Steam Deck (Linux), 1080p / 1440p / 4K
- [ ] **출시 제출**:
  - Google Play Console: 폐쇄 테스트 → 오픈 테스트 → 정식 출시
  - App Store Connect: TestFlight → App Review → 출시
  - Steam Build: Steam Direct $100 + Build Submission + 출시일 위시리스트 50K+ 목표

---

## Post-Launch: 라이브 운영

- **2주 단위 업데이트 사이클**: 밸런스 패치 / 작은 콘텐츠 추가
- **분기별 신규 Zone DLC** (Steam) / Zone Unlock Pack (모바일)
- **시즌 이벤트**: 실제 우주 이벤트 (일식 / 유성우 / 발사 일정)와 연동한 한정 코스메틱
- **클라우드 세이브 V2**: Google Play Games Saved Games / iCloud Key-Value (모바일 통합)

---

## 관련 문서

- `docs/prd.md` — PRD
- `docs/flow.md` — 게임 흐름 (Godot 씬 매핑)
- `docs/design/game_overview.md` — 풀 개요
- `docs/systems/INDEX.md` — 시스템 카탈로그
- `CLAUDE.md` (루트) — Agent-Driven 워크플로우
- `star-reach/CLAUDE.md` — Godot 내부 코드/씬 규칙
