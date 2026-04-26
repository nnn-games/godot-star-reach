# Star Reach — 개발 마스터 플랜

> **작성일**: 2026-04-24
> **현재 상태**: Phase 1.5 (SaveSystem + Autoload 5종 + Stage 10개 정의 완료)
> **목표**: V1 출시 (Android Google Play / iOS App Store / PC Steam)
> **개발 방식**: Agent-Driven (Claude가 코드/씬 직접 작성, 사용자가 F5로 검증)
> **단일 코드베이스**: Godot 4.6 GDScript

---

## 0. 개발 원칙

### 0.1 작업 단위
- **Phase**: 2주 단위 큰 마일스톤 (8개 + Phase 0 = 9개)
- **Step**: Phase 내 1~3일 단위 작업 (Phase당 평균 5~8 Step)
- **Commit**: Step 완료 시점마다 1 commit

### 0.2 Step 실행 사이클
```
1. AI 설계: 기능 / 노드 트리 / Resource 스키마 / 시그널 명세 제시
2. 사용자 동의 (Plan 승인)
3. AI 직접 작성: .gd / .tscn / .tres / project.godot 텍스트 편집
4. AI 자가 검증: godot --headless --check-only 등
5. 사용자 F5 실행 검증 + 에러 로그 회귀 전달
6. AI 자가 수정 (필요 시)
7. Commit + 다음 Step
```

### 0.3 검증 게이트 (Phase 종료 시)
- 헤드리스 smoke test 통과 (`scripts/tests/`)
- 사용자 F5 실행 시 의도된 시나리오 1회 성공
- 기획서(`docs/`)와의 정합성 한 줄 점검
- Git commit + Phase 종료 보고

### 0.4 외부 의존성 별도 관리
다음은 코드/씬과 별개로 진행 (사용자 또는 외주):
| 카테고리 | 분량 | 트리거 시점 |
|---|---|---|
| 사전 렌더 영상 16종 (마일스톤 5 + Zone 11) | 약 30~50MB / 5~12s | Phase 3 시작 시 발주 |
| 코스메틱 아트 (트레일/발사대/시즌) | 시즌별 4~6종 | Phase 4~5 |
| BGM Tier별 5곡 + SFX 셋 | 약 30~50개 | Phase 5 |
| 다국어 번역 (한/영) | 약 1,500 키 | Phase 7 |
| 마케팅 자산 (Steam Capsule, 모바일 ASO) | 정지 + 영상 | Phase 7 |

---

## 1. 마스터 일정 (15주)

| Phase | 기간 | 핵심 산출물 | 검증 |
|---|---|---|---|
| **P0** | 1주 | 클린업 + SaveSystem v2 마이그레이션 + Resource 스키마 | smoke + F5 시작 |
| **P1** | 2주 | LaunchService + N단계 확률 + 3화폐 + EventBus 시그널 | 단일 발사 동작 |
| **P2** | 2주 | Tier 구간 상한 + Pity + Stress/Overload/Abort | T3+ 도전 동작 |
| **P3** | 2주 | Sky Transition (2D) + GPUParticles2D + 마일스톤 영상 | 시각 임팩트 |
| **P4** | 2주 | Auto Launch + Offline 진행 + Codex/Badge/Mission | 메타 루프 동작 |
| **P5** | 2주 | UI Shell + Theme + 사운드 + 다국어 한/영 | UX 완성 |
| **P6** | 2주 | IAP (Steam/Mobile) + Subscription + Battle Pass + Ads | 결제 동작 |
| **P7** | 2주 | 밸런스 QA + 부하 테스트 + 출시 빌드 | 3 플랫폼 제출 |
| **Post** | 지속 | 클라우드 세이브 / Expansion DLC / Battle Pass 시즌 | — |

---

## 2. Phase 상세

### Phase 0 — 클린업 + 마이그레이션 기반 (1주)

**목표**: 현 프로토타입에서 깨끗한 출발선 확보.

**Step 0.1 — Tetris 잔재 제거**
- `scenes/tetris/`, `scripts/tetris/` 삭제
- `project.godot` 입력 매핑 `tetris_*` 키 제거
- `.godot/` 캐시 자동 재생성

**Step 0.2 — SaveSystem v1 → v2 마이그레이션 스키마**
- `scripts/autoload/save_system.gd`에 `SCHEMA_VERSION = 2` 정의
- v1 (`coin` 단일) → v2 (`xp / credit / tech_level`) 마이그레이션 함수
- `data/savegame_schema_v2.md` (선택) 스키마 문서

**Step 0.3 — 기본 Resource 클래스 정의**
- `scripts/resources/launch_balance_config.gd` (`class_name LaunchBalanceConfig`)
- `scripts/resources/tier_segment.gd` (`class_name TierSegment`)
- `scripts/resources/destination.gd` (`class_name Destination`)
- `data/launch_balance_config.tres` 5 TierSegment 작성 (`docs/launch_balance_design.md` 수치)

**Step 0.4 — EventBus 시그널 풀 카탈로그**
- `scripts/autoload/event_bus.gd`에 `docs/system_mapping_analysis.md` §4.2의 28개 시그널 모두 선언
- 각 시그널에 한 줄 주석 (Why)

**Step 0.5 — GameState 3화폐 전환**
- `coin` → `xp` / `credit` / `tech_level`로 분리
- `add_*`, `spend_*`, `spend_credit_clamped` API 정의
- `currency_changed` 시그널 발화

**Step 0.6 — godotsteam 활성화 확인 + Phase 0 검증**
- `addons/godotsteam` 플러그인 enable
- Steam app_id 0 (개발용) 확인
- 헤드리스 smoke (`smoke_load_game.gd`) 통과
- F5 실행 시 메인 메뉴 진입 + game.tscn 로드 무에러

**Phase 0 종료 게이트**: SaveSystem v1 세이브 파일이 v2로 자동 마이그레이션되어 로드되고, F5 시작이 무에러 진입.

---

### Phase 1 — Core Loop: LaunchService + 3화폐 (2주)

**목표**: "LAUNCH 탭 → N단계 확률 판정 → XP 지급 → 다음 LAUNCH"의 마이크로 루프 동작.

**Step 1.1 — LaunchService 기본 골격**
- `scripts/services/launch_service.gd`
- API: `start_launch()`, `_judge_stage(i)`, `_apply_stage_result(i, success)`
- 시그널 발화: `launch_started`, `stage_succeeded`, `stage_failed`, `launch_completed`
- `LaunchBalanceConfig.tres` 참조하여 확률 계산

**Step 1.2 — LaunchSessionService 컨텍스트**
- `scripts/services/launch_session_service.gd`
- 현재 목적지 / Tier / base_modifiers 보유
- 메인 화면 진입 시 자동 활성

**Step 1.3 — Destination 100개 데이터 (T1만 우선)**
- `data/destinations/d_001.tres ~ d_010.tres` (T1 10개)
- 나머지 90개는 Phase 4까지 작업 (외주 가능)

**Step 1.4 — 메인 화면 LAUNCH 버튼**
- `scenes/main/main_screen.tscn` 생성 (기존 game.tscn에서 분리 또는 리팩터)
- 하단 중앙 LAUNCH 대형 원형 버튼
- 상단 3화폐 표시 (XP / Credit / TechLevel)
- 단계 진행 표시기 (점등)

**Step 1.5 — 결정적 시뮬 (RNG seed 저장)**
- `RandomNumberGenerator.seed`를 SaveSystem에 저장 / 로드
- 같은 입력에서 같은 결과 보장 (오프라인 진행 정합성)

**Step 1.6 — 첫 발사 단순 결과 모달**
- `scenes/ui/launch_result_modal.tscn`
- 성공 / 실패 텍스트 + XP 가산 표시 (정식 WinScreen은 Phase 2~3)

**Step 1.7 — Phase 1 검증**
- Headless: `scripts/tests/smoke_launch_loop.gd` (10회 발사 → XP 누적)
- F5: T1 첫 목적지(`D_001`) 클리어 → Credit + TechLevel 보상

**Phase 1 종료 게이트**: F5 시작 → LAUNCH 5회 탭 → XP 누적 + 1회 이상 단계 통과 + 1회 이상 단계 실패 + 1회 목적지 완료 가능.

---

### Phase 2 — Multi-Stage + Stress / Overload / Abort (2주)

**목표**: 구간형 확률 상한 + Pity System + T3+ 리스크 레이어 동작.

**Step 2.1 — 구간형 확률 상한 적용**
- `LaunchService::_compute_chance(tier, stage)`
- `GameState.highest_completed_tier` 기반 자동 상한 적용
- `cleared_tiers` 배열 SaveSystem 반영

**Step 2.2 — Pity System**
- `scripts/services/pity_service.gd`
- 연속 실패 카운트 기반 자동 보정 (UI 노출 X)
- 보정 곡선 튜닝 (예: 5연패 +5%p, 10연패 +10%p, 캡 +15%p)

**Step 2.3 — StressService (T3+ 활성)**
- `scripts/services/stress_service.gd`
- `data/stress_config.tres` Tier별 (10/15/20 누적, 40/50/60% Abort 확률, 300/700/1500 Repair Cost)
- `_process(delta)` 5초 idle 후 초당 -2 자연 감쇠

**Step 2.4 — Overload / Abort 로직**
- `value >= 100` 시 Overload 진입 → 다음 발사에 Abort 확률 적용
- Abort 발생 시 Credit 차감 (`spend_credit_clamped`) + 자동 발사 중단
- `EventBus.abort_triggered` 시그널 발화

**Step 2.5 — Stress UI (T3 진입 시 노출)**
- `scenes/ui/stress_gauge.tscn` 하단 좌측
- T1/T2에서는 숨김, T3 진입 첫 발사 시 등장 + 툴팁 1회

**Step 2.6 — AbortScreen 모달**
- `scenes/ui/abort_screen.tscn`
- 차감된 Credit 표시 + "다시 도전" / "Shield 구매(Phase 6)" / "광고 시청(Phase 6)" 버튼 자리

**Step 2.7 — Phase 2 검증**
- Headless: `smoke_stress_overload.gd` (T3 목적지 강제 100회 실패 → Abort 발생)
- F5: T1~T3까지 자연 진행 시 Stress UI 등장, T3에서 1회 이상 Abort 경험

**Phase 2 종료 게이트**: T3 진입 후 연속 실패 시 Stress 누적 → Overload → Abort → AbortScreen 노출 + Credit 차감 정상.

---

### Phase 3 — Sky Transition (2D) + VFX + 마일스톤 영상 (2주)

**목표**: 단계/목적지 전환 시 시각 임팩트 + 핵심 마일스톤 영상.

**Step 3.1 — SkyProfile Resource + 11 Zone 배경 텍스처**
- `scripts/resources/sky_profile.gd` (`class_name SkyProfile`)
- `data/sky_profiles/zone_01_earth.tres ~ zone_11_deep_space.tres` (Zone 핵심 11개)
- 임시 placeholder 배경 → 본 아트는 외부 작업

**Step 3.2 — ParallaxBackground 레이어 시스템**
- `scenes/main/sky_layer.tscn` (전경/중경/원경/별 4 레이어)
- Tier별 Tween 1.5~3초로 레이어 알파 크로스페이드

**Step 3.3 — SkyProfileApplier 서비스**
- `scripts/services/sky_profile_applier.gd`
- `EventBus.destination_completed` 구독 → 목적지 변경 시 자동 보간
- `CanvasModulate.color` Tween 동시 진행

**Step 3.4 — Camera2D zoom + shake 헬퍼**
- `scripts/util/screen_shake.gd`
- 발사 시작 시 zoom 1.0→1.05 (50ms), 단계별 미세 shake, 실패 시 강한 shake

**Step 3.5 — 4종 GPUParticles2D 프리셋**
- `scenes/launch/launch_vfx.tscn`
- EngineTrail / StageSeparation / AtmosphereBreach / Explosion
- 단계별 시그널에 자동 연결

**Step 3.6 — 풀스크린 플래시 오버레이**
- `scenes/ui/flash_overlay.tscn` (CanvasLayer 100, ColorRect)
- 성공 / 실패 / Abort별 색상 + 0.20~0.40s

**Step 3.7 — 사전 렌더 영상 인프라**
- `scenes/transitions/milestone_video_overlay.tscn`
- `VideoStreamPlayer` 풀스크린 + 스킵 버튼
- `data/cinematic_videos/` 16종 placeholder (실제 영상은 외부 작업, 일단 검은 화면 5초)
- `seen_cinematics` SaveSystem 필드 + 2회차 자동 스킵

**Step 3.8 — Phase 3 검증**
- F5: T1 → T2 → T3 진행 시 배경/색조/BGM 자연 전환
- D_010 첫 도달 시 영상 placeholder 재생 + 스킵 가능

**Phase 3 종료 게이트**: 발사 시 화면 흔들림/줌, 성공/실패별 플래시, Tier 변경 시 배경 보간, D_010/D_025 등 마일스톤 영상 재생 (placeholder OK).

---

### Phase 4 — Auto Launch + Offline + Meta 시스템 (2주)

**목표**: 손 떼고도 진행 + 비접속 시 누적 + 도감/뱃지/미션 메타 루프.

**Step 4.1 — AutoLaunchService**
- `scripts/services/auto_launch_service.gd`
- T1 첫 클리어 또는 누적 10회 발사 시 자동 해금
- `await get_tree().create_timer(...).timeout` 기반 루프
- 메인 화면 우하단 토글 (해금 후 노출)

**Step 4.2 — OfflineProgressService**
- `scripts/services/offline_progress_service.gd`
- 종료 시 `last_saved_unix` 기록 → 재진입 시 델타 시뮬
- 캡 8h (자동 발사 미해금 시 1h)
- `scenes/ui/offline_summary_modal.tscn` (이미 있음, 갱신)

**Step 4.3 — DiscoveryService (Codex)**
- `scripts/services/discovery_service.gd`
- `data/codex_config.tres` 12 엔트리 (Lite B)
- `EventBus.destination_completed` 구독 → 자동 해금
- 시그널 4종 (`codex_entry_unlocked` / `_updated` / `_section_unlocked` / `_completed`)

**Step 4.4 — BadgeService + Achievement 매핑**
- `scripts/services/badge_service.gd`
- `data/badge_config.tres` 19종 (Win 5 + 첫도달 14)
- 플랫폼 어댑터 (`platform_service.gd`):
  - Steam: `Steam.setAchievement()` (godotsteam)
  - Android: Google Play Games (V1은 stub, V1.1 정식)
  - iOS: Game Center (V1.1)

**Step 4.5 — MissionService (일일 + 주간)**
- `scripts/services/mission_service.gd`
- `data/mission_config.tres` 풀 7종
- 매일 00:00 디바이스 로컬 자정 리셋 + 결정적 시드 추첨
- 일일 캡 50 / 주간 캡 500 (구독자 750)

**Step 4.6 — BestRecordsService (로컬)**
- `scripts/services/best_records_service.gd`
- TotalWins / HighestTechLevel / BestTier 단조 증가
- V2 외부 리더보드 hook 자리

**Step 4.7 — 100 목적지 데이터 완성**
- `data/destinations/d_011.tres ~ d_100.tres` 90개
- `docs/contents.md` 콘텐츠 그대로 적용
- 외주 가능 (Excel 시트 → 자동 생성 스크립트)

**Step 4.8 — Phase 4 검증**
- F5: 자동 발사 ON 후 1분 방치 → 누적 발사 확인
- 앱 종료 후 재시작 → 오프라인 요약 모달
- T1 클리어 → Earth Region Codex / Badge 잠금 해제

**Phase 4 종료 게이트**: 자동 발사 작동 + 오프라인 진행 누적 + Codex/Badge/Mission 자동 갱신.

---

### Phase 5 — UI Shell + Theme + 사운드 + 다국어 (2주)

**목표**: 출시 가능한 UX 품질.

**Step 5.1 — Theme + StyleBox 시스템**
- `theme/main_theme.tres`
- `theme/stylebox/*.tres` (button / panel / popup)
- `data/palette.tres` (`docs/ui_design_guide.md` §2 컬러 팔레트)

**Step 5.2 — MainScreen 최종 레이아웃**
- 모바일 16:9 / 19.5:9 / 폴더블 / Steam Deck 16:10 안전 영역 대응
- `AspectRatioContainer` + `MarginContainer` 활용

**Step 5.3 — 7개 화면 완성**
- `scenes/ui/upgrade_panel.tscn` (Launch Tech + Facility 두 탭)
- `scenes/ui/codex_panel.tscn` (12 엔트리 갤러리)
- `scenes/ui/mission_panel.tscn` (일일/주간)
- `scenes/ui/best_records_panel.tscn`
- `scenes/ui/settings_panel.tscn` (사운드 / 그래픽 / 자동 스킵 / 데이터 초기화)
- `scenes/ui/daily_reward_modal.tscn` (Phase 6과 공동)
- `scenes/ui/offline_summary_modal.tscn` (Phase 4 갱신)

**Step 5.4 — 사운드 디자인**
- `scripts/autoload/audio_bus.gd` + 버스 라우팅 (Master / SFX / BGM)
- SFX: 점화 / 가속 / 단계 통과 / 폭발 / 자유낙하 / UI 클릭 (placeholder OK, 외부 작업)
- BGM: Tier별 5곡 크로스페이드 (`AudioStreamPlayer`)
- 모바일 햅틱 (`Input.vibrate_handheld`) 단계 통과 시

**Step 5.5 — 다국어 (한/영)**
- `tr()` 호출로 모든 UI 텍스트 래핑
- `translation/ko.po`, `translation/en.po`
- `data/destinations/*.tres`의 `name`은 키 (`tr("D_001_NAME")`)

**Step 5.6 — Steam Deck / 모바일 안전 영역**
- `DisplayServer.get_display_safe_area()` 활용
- 노치 / 폴더블 / Steam Deck 720p 가독성 검증

**Step 5.7 — Phase 5 검증**
- F5: 모든 메뉴 진입 가능 + 한국어/영어 토글 동작
- Android 에뮬레이터 또는 실기 빌드 → 다양한 화면비 확인

**Phase 5 종료 게이트**: V1 출시 가능한 UX 품질 (placeholder 아트/사운드 허용).

---

### Phase 6 — IAP + Subscription + Battle Pass + 광고 (2주)

**목표**: 모바일 + Steam 결제 정식 동작.

**Step 6.1 — IAPService 베이스 + 어댑터 통합**
- 기존 `scripts/iap/*.gd` 활용 (이미 4종 백엔드 존재)
- `scripts/services/iap_service.gd` 정합성 검증
- `data/iap_config.tres` 13개 IAP 정의 (`docs/bm.md` §3 기준)

**Step 6.2 — Google Play Billing (Android)**
- `addons/GodotGooglePlayBilling` 활성 검증
- 영수증 검증 + `acknowledgePurchase()` 3일 내 호출
- 테스트 트랙 등록 (Internal Testing)

**Step 6.3 — Apple StoreKit (iOS)**
- iOS plugin 빌드 환경 확인 (Xcode 필요)
- `inappstore` 모듈 통합
- StoreKit Configuration File로 로컬 테스트

**Step 6.4 — GodotSteam 영구 IAP**
- `Steam.purchaseStart()` API 활용
- Steamworks Microtransactions 등록 (DLC 8종 + Cosmetic 4종)

**Step 6.5 — Steam Achievements 연동**
- 19 Badge → Steamworks Achievements 등록
- `Steam.setAchievement()` 호출 검증

**Step 6.6 — Steam Cloud Save**
- Auto-Cloud `*.json` 패턴 등록
- 충돌 시 최신 timestamp 채택

**Step 6.7 — Daily Reward + Subscription + Battle Pass**
- `scripts/services/daily_reward_service.gd` (Phase 4 미완 부분)
- `scripts/services/subscription_service.gd`
- `scripts/services/battle_pass_service.gd`
- 시즌 1 (`S01_LUNAR`) 데이터 (`data/seasons/s01_lunar.tres`)

**Step 6.8 — Rewarded Ads (모바일 한정)**
- `addons/godot-admob` 또는 동등 플러그인 통합
- Abort 회피 / Win 보상 +50% / Daily 2배 / Auto-Fuel 충전

**Step 6.9 — Phase 6 검증**
- Mock 백엔드: 모든 IAP 구매 / 복원 동작
- Steam: Steamworks 테스트 환경에서 1회 실제 구매
- Android: Internal Testing 트랙에서 1회 실제 구매

**Phase 6 종료 게이트**: 3 플랫폼 모두 IAP 결제 → 효과 적용 → 영수증 검증 통과.

---

### Phase 7 — QA + 출시 빌드 + 제출 (2주)

**목표**: 3 플랫폼 동시 출시.

**Step 7.1 — 밸런스 튜닝 시뮬**
- `tools/balance_simulator.gd` 헤드리스 스크립트
- T1 첫 클리어 ~3분, T5 마지막 클리어 ~120시간 목표
- 상수 조정 → 재시뮬 반복

**Step 7.2 — 첫 2시간 튜토리얼 보장**
- Steam 환불 정책 방어 (14일/2시간)
- T1 첫 목적지 30분 내 클리어 보장
- 첫 2~3발 100% 보정

**Step 7.3 — 부하 / 메모리 테스트**
- 100시간 누적 플레이 시뮬 (헤드리스)
- 메모리 누수 체크 (`Performance.get_monitor()`)
- 세이브 파일 크기 < 100KB 유지

**Step 7.4 — 다국어 키 누락 검증**
- 모든 `tr(...)` 호출이 `ko.po` / `en.po`에 존재하는지 자동 검증

**Step 7.5 — 플랫폼별 빌드 검증**
- Windows Steam (.exe) — Steam Deck 컨트롤러 입력
- Linux Steam (.x86_64) — Steam Deck 호환 인증
- Android (APK + AAB) — Pixel / Galaxy / 폴더블 / 저사양
- iOS (IPA) — iPhone SE ~ Pro Max + iPad

**Step 7.6 — 출시 자산 준비**
- Steam Capsule (Header / Library / Featured)
- Google Play / App Store 스크린샷 (5종)
- 게임 설명 (한/영)
- 마케팅 영상 60초

**Step 7.7 — 출시 제출**
- Steam Direct $100 + Build Submission
- Google Play Console: Internal → Closed → Open → Production
- App Store Connect: TestFlight → App Review → Production

**Phase 7 종료 게이트**: 3 플랫폼 출시 또는 심사 대기.

---

### Post-Launch (V1.1+, 지속)

| 항목 | 시점 |
|---|---|
| 클라우드 세이브 V2 (GPG Saved Games + iCloud) | 출시 후 1개월 |
| Battle Pass S02 (Mars Era) | 분기 |
| Expansion DLC `Interstellar Frontier` (Steam) | 6개월 |
| Steam Workshop (mod 지원) | 12개월 |
| 시즌 이벤트 (실제 우주 이벤트 연동) | 분기 |

---

## 3. 위험 관리

| 위험 | 영향 | 완화 |
|---|---|---|
| iOS plugin 빌드 환경 (Xcode 필수) | 🔴 높음 | Phase 0에서 macOS 빌드 환경 PoC 선행 |
| Steam IAP 영수증 검증 복잡도 | 🟡 중간 | godotsteam 공식 예제 활용 + Phase 6 첫 Step에 PoC |
| 마일스톤 영상 16종 외주 일정 | 🟡 중간 | Phase 3 시작 시 발주 → Phase 6 마감 |
| 다국어 키 누락 | 🟡 중간 | Phase 7 자동 검증 스크립트 + 영어 fallback |
| 모바일 저사양 디바이스 성능 | 🟡 중간 | Phase 5 안전 영역 + 파티클 동적 조절 |
| 100 목적지 데이터 작성 부담 | 🟢 낮음 | Excel → `.tres` 자동 생성 스크립트 |
| 출시 심사 거절 | 🟡 중간 | 13세 미만 가드 / 확률 표기 / 환불 정책 사전 준수 |

---

## 4. 산출 디렉토리 트리 (V1 완성 기준)

```
star-reach/
├── project.godot                    # Autoload 5종 + Steam app_id
├── scripts/
│   ├── autoload/                    # event_bus, game_state, save_system, time_manager, iap_service
│   ├── services/                    # launch_*, stress_*, sky_*, auto_launch_*, discovery_*, badge_*, mission_*, daily_*, subscription_*, battle_pass_*, ad_reward_*, telemetry_*, platform_*, season_*, meta_bonus_*
│   ├── resources/                   # destination, tier_segment, sky_profile, codex_entry, badge_def, mission_def, iap_product, season, battle_pass_tier
│   ├── ui/                          # main_screen, global_hud, upgrade_panel, codex_panel, mission_panel, settings_panel, daily_reward_modal, offline_summary_modal, abort_screen, win_screen
│   ├── util/                        # screen_shake, audio_bus, format_number
│   ├── iap/                         # backend_base, mock, android, ios, steam (기존)
│   └── tests/                       # smoke_*, balance_simulator, perf_test
├── scenes/
│   ├── splash/                      # 부팅
│   ├── main_menu/                   # 메인 메뉴
│   ├── main/                        # main_screen, sky_layer, rocket_view
│   ├── launch/                      # launch_vfx, rocket_animation
│   ├── ui/                          # 모든 패널 / 모달
│   └── transitions/                 # milestone_video_overlay, sky_transition
├── data/
│   ├── launch_balance_config.tres
│   ├── stress_config.tres
│   ├── codex_config.tres
│   ├── badge_config.tres
│   ├── mission_config.tres
│   ├── iap_config.tres
│   ├── dlc_config.tres
│   ├── meta_bonus_config.tres
│   ├── season_collection_config.tres
│   ├── battle_pass_config.tres
│   ├── subscription_config.tres
│   ├── daily_reward_config.tres
│   ├── ad_reward_config.tres
│   ├── destinations/                # d_001.tres ~ d_100.tres
│   ├── sky_profiles/                # zone_01_*.tres ~ zone_11_*.tres
│   ├── seasons/                     # s01_lunar.tres ~
│   └── cinematic_videos/            # 16종 .ogv
├── theme/
│   ├── main_theme.tres
│   ├── palette.tres
│   └── stylebox/                    # button, panel, popup
├── translation/
│   ├── ko.po
│   └── en.po
├── assets/
│   ├── sprites/
│   ├── particles/
│   ├── sfx/
│   └── bgm/
└── addons/
    ├── godotsteam/                  # PC Steam
    ├── GodotGooglePlayBilling/      # Android
    └── (iOS plugins via gradle)
```

---

## 5. 즉시 다음 액션

**Phase 0 Step 0.1 — Tetris 잔재 제거**부터 시작.

1. `scenes/tetris/` 삭제
2. `scripts/tetris/` 삭제
3. `project.godot`에서 `tetris_*` 입력 매핑 제거
4. F5 검증 후 commit

사용자 동의 후 Phase 0 진행하겠습니다.
