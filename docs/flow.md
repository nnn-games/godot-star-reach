# Star Reach 게임 흐름 및 장면 구성 (Gameplay Flow & Scene Composition)

이 문서는 플레이어의 생애 주기(User Journey)에 따른 게임의 흐름, 각 단계별 장면 구성, 그리고 Godot 4.6 싱글 오프라인 빌드에서의 구현 요소를 정의합니다.

> **전제**: 본 문서는 **싱글 오프라인** (Android / iOS / PC Steam) 기준입니다. 모든 게임 로직은 클라이언트 단독에서 결정됩니다.

---

## 1. 진입 및 메인 화면 (Entry / Main Screen)

### 1.1 흐름 (Flow)
1. 앱 시작 → 스플래시 (`SplashScreen.tscn`, 1~2초)
2. `SaveSystem` 오토로드가 `user://savegame.json` 로드 (없으면 신규 프로필 생성)
3. **오프라인 진행 계산**: 마지막 저장 시각과 현재 시각의 델타로 자동 발사 시뮬 (캡 8h, 자동 발사 미해금 시 캡 1h 또는 0)
4. **오프라인 요약 모달** 노출 (자동 발사 N회 / Credit +X / XP +Y)
5. 메인 화면 (`MainScreen.tscn`) 진입 — 발사 패널이 즉시 노출됨

### 1.2 장면 구성 (Scene Composition)
- **카메라**: 고정 `Camera2D` (스무딩 비활성). 발사 시에만 미세 쉐이크.
- **배경**: 현재 도전 중인 목적지의 Tier에 맞는 `ParallaxBackground` 레이어 활성. `CanvasModulate`로 색조 적용.
- **UI** (`CanvasLayer`):
  - 상단 좌측: XP / Credit / TechLevel 3화폐 패널
  - 상단 중앙: 현재 목적지명 + 진행 단계 표시 (예: `D_023 화성 올림푸스 산 — 0 / 7`)
  - 상단 우측: 메뉴 (Upgrade / Codex / Settings)
  - 하단 중앙: **🚀 LAUNCH 대형 원형 버튼** (0.8초 펄스)
  - 하단 좌측: Stress 게이지 (T3+ 활성화 시에만 표시)
  - 하단 우측: 자동 발사 토글 (해금 후 표시)

### 1.3 구현 요소 (Implementation)
- 오토로드 싱글톤: `SaveSystem`, `GameState`, `EventBus`
- 메인 씬: `scenes/main/main_screen.tscn`
- 오프라인 요약: `scenes/ui/offline_summary_modal.tscn` (PopupPanel)

---

## 2. 발사 트리거 (Launch Trigger)

### 2.1 흐름 (Flow)
1. 플레이어가 LAUNCH 버튼 탭 (또는 자동 발사 타이머 발화)
2. `LaunchSessionService.start_launch()` 호출 → `GameState.is_launching = true`
3. `LaunchService`가 현재 목적지의 `requiredStages`만큼 단계별 확률 판정 시작
4. UI는 `EventBus.launch_started` 시그널을 받아 LAUNCH 버튼 비활성화 + 단계 표시기 표시

### 2.2 장면 구성 (Scene Composition)
- **카메라**: 발사 시작 시 `tween`으로 50ms 동안 약한 줌인 (1.0 → 1.05)
- **로켓 스프라이트**: 화면 중앙 하단에서 1단계 통과 시마다 일정 픽셀 위로 이동하는 `AnimationPlayer` 트랙 재생
- **단계 표시기**: 우측 세로 점 표시 (Stage 1 / 2 / 3 ... / N) — 통과 시 점등

### 2.3 구현 요소 (Implementation)
- `scripts/services/launch_service.gd` — 단계 확률 판정 + 결과 시그널 발화
- `scenes/launch/rocket_view.tscn` — 로켓 스프라이트 + `AnimationPlayer`
- `scenes/launch/stage_indicator.tscn` — 단계 표시 UI

---

## 3. 단계별 상승 / 결과 분기 (Stage Ascent / Result Branch)

### 3.1 흐름 (Flow)
1. 각 Stage `i`에 대해:
   - `chance_i = LaunchBalanceConfig.compute_chance(tier, base_modifiers)` 계산
   - `randf() < chance_i` 판정
   - **성공**: XP 즉시 지급 → `EventBus.stage_succeeded.emit(i)` → 2초 상승 연출 → 다음 단계
   - **실패**: `EventBus.stage_failed.emit(i)` → 자유낙하 연출 → 발사 종료
2. 모든 단계 통과 시 `EventBus.launch_completed.emit()` → 목적지 완료 처리로

### 3.2 장면 구성 (Scene Composition)
- **성공 연출**: 로켓 트레일 파티클(`GPUParticles2D`) 활성, `Camera2D.shake_amplitude` 약한 펄스, 효과음 (점화 / 가속)
- **실패 연출**: 트레일 즉시 소멸 + 검은 연기 파티클 + `Camera2D` 강한 쉐이크 0.5초 + 효과음 (배기/폭발)
- **배경**: 단계별로 `ParallaxBackground.scroll_offset.y` 보간 → 배경이 아래로 스크롤되며 상승감
- **UI**: 단계 표시기 점등, XP 카운트업 텍스트 애니메이션

### 3.3 구현 요소 (Implementation)
- `scripts/services/launch_service.gd` — 핵심 판정 로직
- `scripts/util/screen_shake.gd` — `Camera2D` 쉐이크 헬퍼
- `scenes/launch/launch_vfx.tscn` — 파티클 프리셋 모음

---

## 4. 추락 (Crash / Fail)

### 4.1 흐름 (Flow)
1. 단계 실패 → `EventBus.stage_failed` 발화
2. 로켓 스프라이트 회전 + 자유낙하 `Tween` 0.4초
3. (T3+) `StressService.add_stress(tier_value)` 호출 → Stress 게이지 갱신
4. (Stress > 100) `OverloadService` 활성 → 다음 발사 시 Abort 확률 적용
5. LAUNCH 버튼 즉시 재활성화 (체감 쿨타임 ≤ 0.8초)

### 4.2 장면 구성 (Scene Composition)
- 짧고 임팩트 있는 자유낙하 + 화면 하단 충돌 시 먼지 파티클 1회
- 화면 중앙 짧은 토스트 ("Stage 5 — Failed")
- (T3+) Stress 게이지 빨간색 펄스 1회

### 4.3 구현 요소 (Implementation)
- `scripts/services/stress_service.gd` — 누적 / 자연 감쇠 (`_process`에서 5초 idle 이상이면 초당 감쇠)
- `scenes/launch/crash_anim.tscn` — 추락 애니메이션 노드

---

## 5. 목적지 완료 / 환경 전환 (Destination Complete / Environment Transition)

### 5.1 흐름 (Flow)
1. 모든 단계 통과 → `DestinationService.complete_destination(d_id)` 호출
2. 보상 지급 (Credit + TechLevel) → `EventBus.destination_completed` 발화
3. Region 첫도달 / Codex 갱신 / Badge 평가
4. **환경 전환**: 새 목적지의 Tier가 변경되었으면 Sky Profile 보간 시작 (1.5~3초)
5. **사전 렌더 영상 분기**: 마일스톤(10/25/50/75/100) 또는 첫도달 영상이 등록된 목적지면 `VideoStreamPlayer` 풀스크린 재생 (스킵 가능, 2회차부터 자동 스킵)
6. TechLevel 충족 시 다음 목적지 자동 해금 → 자동으로 다음 발사로 복귀

### 5.2 장면 구성 (Scene Composition)
- **연출**: 짧은 화이트 페이드 (0.3초) → 새 배경 페이드인
- **환경 전환**:
  - `ParallaxBackground` 레이어 텍스처 교체 (좌→우 슬라이드 트랜지션 또는 페이드)
  - `CanvasModulate.color` Tween (예: 푸른 대기 → 칠흑 우주)
  - Tier별 BGM `AudioStreamPlayer.stream` 크로스페이드
- **사전 렌더 영상** (해당 목적지에 한정): `VideoStreamPlayer` 풀스크린 → 종료 후 메인 화면 복귀

### 5.3 구현 요소 (Implementation)
- `scripts/services/destination_service.gd` — `complete_destination()` 단일 보상 파이프라인
- `scripts/services/sky_profile_applier.gd` — Tier별 `SkyProfile.tres` 참조 + Tween 보간
- `data/sky_profiles/*.tres` — Tier별 색조 / 배경 텍스처 / 파티클 프리셋
- `scenes/transitions/destination_complete_overlay.tscn` — 페이드 + 영상 재생 컨트롤러
- `data/cinematic_videos/*.ogv` — 사전 렌더 마일스톤 영상

---

## 6. 업그레이드 화면 (Upgrade Screen)

### 6.1 흐름 (Flow)
1. 메인 화면 우상단 메뉴 → "Upgrade" 탭
2. 두 개 탭으로 분리:
   - **Launch Tech** (XP 소비, 5종, 세션형 — 목적지 변경 시 리셋)
   - **Facility Upgrades** (Credit 소비, 5종, 영구형)
3. 항목 탭 → 효과 미리보기 → 구매 버튼
4. 구매 시 화폐 차감 + 즉시 효과 적용 + `EventBus.upgrade_purchased` 발화
5. 닫기 시 메인 화면 복귀 — LAUNCH 버튼 즉시 재사용 가능

### 6.2 장면 구성
- 풀스크린 `Control` 패널, 좌측 카테고리 탭 / 우측 항목 리스트 / 하단 효과 설명
- 구매 가능 항목은 강조 색, 불가능 항목은 회색 + 부족한 화폐 표시

### 6.3 구현 요소
- `scripts/services/launch_tech_service.gd`
- `scripts/services/facility_upgrade_service.gd`
- `data/launch_tech_config.tres`, `data/facility_upgrade_config.tres`
- `scenes/ui/upgrade_panel.tscn`

---

## 7. 자동 발사 / 오프라인 진행

### 7.1 자동 발사 (Auto Launch)
- T1 첫 클리어 또는 누적 10회 발사 시 무료 해금
- IAP `Auto Launch Pass` 구매 시 속도 상한 +0.35 launches/s
- 메인 화면 우하단 토글로 ON/OFF
- ON 상태에서는 LAUNCH 버튼이 0.5~1.0초 주기로 자동 발화

### 7.2 오프라인 진행 (Offline Progress)
- 종료 시 `SaveSystem.save_now()` → `last_saved_unix` 기록
- 재개 시 `delta = Time.get_unix_time_from_system() - last_saved_unix`
- `delta = min(delta, OFFLINE_CAP_SEC)` (자동 발사 미해금 시 OFFLINE_CAP_SEC = 0)
- `simulated_launches = floor(delta * effective_launch_rate)` — 결정적 시뮬 (확률 기댓값 기반)
- 보상은 캡과 비례 — UI 모달로 요약 표시

### 7.3 구현 요소
- `scripts/autoload/save_system.gd` — `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` + 10초 주기 저장
- `scripts/services/auto_launch_service.gd`
- `scripts/services/offline_progress_service.gd`
- `scenes/ui/offline_summary_modal.tscn`

---

## 8. 데이터·이벤트 흐름 요약

```
[User Input: LAUNCH 탭]
   ↓
[LaunchSessionService.start_launch()]
   ↓
[LaunchService — N단계 확률 판정 (LaunchBalanceConfig.tres 참조)]
   ↓ (각 단계마다)
[EventBus.stage_succeeded / stage_failed]   →  [UI / VFX / Audio 구독자들]
   ↓ (모든 단계 통과 시)
[EventBus.launch_completed]
   ↓
[DestinationService.complete_destination()]
   ↓
[GameState.add_credit() / add_tech_level()]
   ↓
[EventBus.destination_completed / region_first_visited / codex_updated]
   ↓
[SkyProfileApplier — 환경 전환 Tween]
   ↓
[(선택) VideoStreamPlayer — 사전 렌더 영상 1회]
   ↓
[메인 화면 복귀 — 다음 LAUNCH 가능]
```

---

## 9. 관련 문서
- `docs/prd.md` — v6.0 PRD
- `docs/design/game_overview.md` — 풀 개요
- `docs/launch_balance_design.md` — 확률·보상 곡선
- `docs/systems/INDEX.md` — 시스템 카탈로그
- `docs/systems/4-1-seat-cinematic.md`, `4-2-sky-transition.md`, `4-3-launch-vfx.md` — 연출 시스템 상세
