# 01. Launch Core — 발사 루프 기획서

> **문서 유형**: 게임 플레이 기획서 (Gameplay Design Document)
> **작성일**: 2026-04-24
> **정본 근거**: `docs/systems/1-1-launch-session.md` ~ `1-4-stress-abort.md`
> **대상 독자**: 디자이너 / QA / 밸런스 담당 / 신규 합류자

---

## 0. 개요

**Launch Core**는 Star Reach의 가장 근본적 플레이 루프이다. 플레이어가 메인 화면에서 LAUNCH 버튼을 탭했을 때 일어나는 **모든 판정과 결과**의 원천이며, 이후 Progression(업그레이드)과 Economy(보상)로 흘러가는 전류의 발전소이다.

**4개 하위 시스템**:

| ID | 시스템 | 한 줄 설명 |
|---|---|---|
| 1-1 | Launch Session | "발사 세션이 열렸다" 상태의 권위적 정의 (메인 화면 진입과 동시에 활성) |
| 1-2 | Multi-Stage Probability | N단계 확률 판정 — 실제 승패를 결정하는 엔진 |
| 1-3 | Auto Launch | 손을 놓아도 루프가 돌아가는 자동 발사 + 오프라인 진행 |
| 1-4 | Stress / Overload / Abort | 상위 티어 리스크 — 긴장과 처벌의 축 |

---

## 1. 코어 플레이 루프

```
[앱 진입]
  └─ SaveSystem 로드 + 오프라인 진행 시뮬
       └─ 메인 화면 진입 → LaunchSession 자동 활성 [1-1]
            ↓
[LAUNCH 탭]
  └─ Stress 사전 판정 (T3+) [1-4]
       ├─ Abort 발생 → Credit 차감, 자동 발사 중단, AbortScreen 모달
       └─ 통과
            ↓
       N단계 루프 (requiredStages 만큼) [1-2]
         ├─ 스테이지 시간 2초 대기
         ├─ randf() < stage_chance 판정
         │    ├─ 통과 → XP 지급, EventBus.stage_succeeded 발화, 계속
         │    └─ 실패 → 루프 즉시 중단, EventBus.stage_failed, 스트레스 누적
         ↓
[결과]
  ├─ 전 스테이지 성공 → EventBus.launch_completed → 목적지 완료 (→ 02 Progression)
  └─ 실패 → 다시 LAUNCH 가능 (체감 0.8초)
  └─ (옵션) Auto Launch 토글이 켜져 있으면 자동 재발사 [1-3]
```

**세션 길이 가이드** (스테이지 = 2초 고정):
- T1 목적지: 3~4스테이지 → **6~8초/회**
- T3 목적지: 7~8스테이지 → **14~16초/회**
- T5 목적지: 10스테이지 → **20초/회**

> 이 수치는 "한 판" 체감 시간의 기준선이다. 확률이 낮은 상위 티어일수록 실패 빈도가 잦으므로 실제 목적지 클리어까지의 평균 시도 수는 훨씬 많다.

---

## 2. Launch Session — 발사 세션 (1-1)

### 2.1 디자인 의도

**"발사 세션은 메인 화면에 들어오는 순간 자동으로 열린다."**

물리적 진입 의식 없이 **즉시 플레이 가능**한 모바일 / Steam 친화적 흐름. 한 손 조작과 짧은 세션을 위한 설계.

### 2.2 플레이어 흐름

| 단계 | 플레이어 행동 | 시스템 반응 |
|---|---|---|
| 1 | 앱 실행 / 메인 화면 진입 | `LaunchSessionService` 자동 활성, `current_destination_id` 로드 |
| 2 | LAUNCH 버튼 탭 | `LaunchService.start_launch()` 호출 |
| 3 | 발사 반복 | 세션 컨텍스트 유지 (현재 목적지, base_modifiers) |
| 4 | 메뉴 진입 (Upgrade / Codex / Settings) | 세션 유지, 발사만 일시 정지 |
| 5 | 앱 종료 / 백그라운드 | `SaveSystem.save_now()` + 세션 컨텍스트 저장 |
| 6 | 재진입 | 마지막 목적지로 자동 복귀 + 오프라인 진행 요약 |

### 2.3 규칙

- **단일 세션** — 싱글 플레이어이므로 항상 1세션이 메인 화면 진입과 동시에 활성.
- **자동 복구** — 종료 시점의 `current_destination_id` / `auto_launch.enabled` / `stress.value`가 그대로 복원.
- **목적지 변경 시 부분 리셋** — 선택 시 XP와 Launch Tech 레벨이 0으로 초기화 ("이 목적지 안에서 다 써라").

### 2.4 연출

- 메인 화면 진입 시 현재 Tier의 `SkyProfile` 적용 (배경 텍스처 + `CanvasModulate` 색조 + BGM).
- 목적지 변경 시 `Tween` 1.5~3초로 새 Tier 프로필 보간 (→ 04 Sky Transition).
- 발사 중 미세 카메라 zoom (`Camera2D.zoom` 1.0 → 1.05, 50ms).

---

## 3. Multi-Stage Probability — N단계 확률 엔진 (1-2)

### 3.1 디자인 의도

**"한 번 누르는 발사 = 여러 번의 작은 도박."**

단일 확률(70% 한 번)이 아니라 **다단계 연속 확률**을 채택한 이유:

1. **긴장 곡선 생성**: 스테이지가 거듭될수록 "여기까지 왔는데 이번 단계에서 실패하면..." 의 긴장감.
2. **부분 보상의 정당화**: 중간에 실패해도 그때까지의 XP는 유지 → "헛수고가 아니다".
3. **난이도 스케일링**: 스테이지 수(3~10)와 스테이지별 확률(50~85%)의 두 축으로 상위 티어의 난이도를 부드럽게 조절.

### 3.2 핵심 공식

```gdscript
# 스테이지 i의 성공 확률
if segment_tier <= GameState.highest_completed_tier:
    stage_chance = segment.max_chance         # 정복 보상
else:
    stage_chance = min(segment.base_chance + upgrade_bonus, segment.max_chance)
```

**구간(TierSegment) 테이블** — `data/launch_balance_config.tres`:

| 티어 | 구간 이름 | 스테이지 | base | max | 업그레이드로 상승 가능한 폭 |
|---:|---|---:|---:|---:|---|
| 1 | Atmosphere | 1~4 | 50% | 85% | +35%p |
| 2 | Cislunar | 5~6 | 44% | 78% | +34%p |
| 3 | Mars Transfer | 7~8 | 36% | 72% | +36%p |
| 4 | Outer Solar | 9 | 28% | 66% | +38%p |
| 5 | Interstellar | 10 | 22% | 60% | +38%p |

### 3.3 업그레이드로 확률 끌어올리기

플레이어는 다음 경로로 성공률을 높일 수 있다:

| 경로 | 소스 | 최대 기여 | 성격 |
|---|---|---:|---|
| Engine Precision (세션) | Launch Tech | +40%p | 목적지 변경 시 리셋 (세션형) |
| Engine Tech (영구) | Facility Upgrades | +10%p | Credit 투자, 영구 유지 |
| Guidance Module Pass | 영구 IAP ($5.99) | +5%p | 상시 적용 |
| Trajectory Surge | 소모 IAP ($1.99, 30분) | +3%p | 시간제 |
| **상시 합계 최대** | | **+55%p** | |
| **Surge 활성 중 일시 최대** | | **+58%p** | |

**결과**: T1의 구간 1은 기본 50% → 업그레이드 풀투자 시 이론상 105%이지만 구간 상한(85%)에 의해 잘림. T5의 구간 5는 기본 22% → 풀투자 시 60% 상한에 도달 가능.

### 3.4 "정복 보너스" — 티어 오름차순 자동 완화

한 번이라도 티어 N을 클리어했다면, 이후 어떤 발사에서든 **구간 1~N에 해당하는 스테이지는 바로 상한값(max)에서 시작**한다. 상위 티어에 도전할 때 아래 구간은 덜 고통스럽게 — "역행 감각" 제거.

### 3.5 XP 지급 — 실패해도 보존

각 스테이지 통과 시점에 즉시 XP 지급:

```gdscript
xp_gain = (XP_BASE_GAIN + telemetry_level)
       * fuel_optimization_multiplier   # 1.0 ~ 1.5
       * (1 + data_collection_bonus)    # Facility
       * iap_xp_multiplier              # VIP 2x / Boost 2x
```

이 XP는 **Launch Tech**(세션 업그레이드) 구매에만 쓰인다. 목적지 변경 시 리셋.

### 3.6 실패 시 처리

- 실패한 스테이지에서 루프 **즉시 중단** ("부분 클리어" 개념 없음).
- `current_streak = 0` 리셋.
- 그때까지 얻은 XP는 **보존**.
- T3+인 경우 스트레스 누적 (→ 1-4).

### 3.7 UI 표기 규칙

대기 상태에서 성공률을 표시할 때는 "현재 목적지에서 **아직 미정복인 첫 구간**"의 확률을 우선 노출한다. 상위 목적지에서 85% 구간만 보여주면 실제 난이도가 가려지기 때문.

---

## 4. Auto Launch — 자동 발사 (1-3)

### 4.1 디자인 의도

**"Incremental 장르의 정체성 — 손을 떼도 게임이 흘러간다."**

수동 발사만 있으면 플레이어는 "모바일에서 클릭 반복 노동"에 갇히게 된다. Auto Launch는:

- **AFK 루프 허용** → 장르 규약 충족
- **오프라인 자동 진행** → 장시간 비접속 → 복귀 시 보상 누적 (캡 8h)
- **IAP 상품의 실질 가치 전달** (Auto Launch Pass / Auto Fuel로 rate 가속)

### 4.2 해금 경로

다음 **중 하나**만 만족해도 해금 (소셜 의존 없음):

| 경로 | 조건 | 의도 |
|---|---|---|
| T1 클리어 | `highest_completed_tier >= 1` | 자연스러운 진행 해금 |
| 누적 10회 발사 | `total_launches >= 10` | T1 미달 시 최소 경로 |

### 4.3 발사 속도 (rate) 공식

```
rate(launches/sec) = 1.0
  + 0.35 (Auto Launch Pass — 영구 IAP $4.99)
  + 0.50 (Auto Fuel — 시간제 소모 IAP $0.99 / 60분)

/ (1 - auto_checklist_reduction[0~0.5])   ← 쿨다운 감소

→ cap: 2.5 launches/sec
```

**최대 조합**(모든 IAP)은 실질 cap인 2.5에 금방 도달. 즉 **"풀투자 이후에는 더 사지 않아도 된다"** 는 안전장치. cap이 없으면 IAP 인플레이션이 터짐.

### 4.4 수동 발사 쿨다운

같은 서비스가 **수동 발사의 쿨다운**도 소유한다 (이름이 오도하지만 의도적):

```
cooldown = BASE(0.8s) * (1 - auto_checklist_reduction)
         (최소 0.4s)
```

→ 쿨다운 감소 업그레이드로 수동 연타감을 가속 가능. Auto Launch 해금 전에도 이 업그레이드는 의미가 있다.

### 4.5 루프 중단 조건

아래 중 어떤 것이든 발생하면 즉시 루프 종료:

1. 플레이어가 수동 토글 OFF
2. 메뉴 진입 (Upgrade / Codex / Settings)
3. 앱 백그라운드
4. **목적지 클리어** (완료 이벤트 발행 후 자동 정지)
5. **Stress Abort** (티어 3+에서 Abort 발생 시 자동 정지)

### 4.6 오프라인 진행 (Offline Progress)

종료 시점부터의 시간 차로 자동 발사를 결정적으로 시뮬:

```gdscript
delta = Time.get_unix_time_from_system() - SaveSystem.last_saved_unix
delta = min(delta, OFFLINE_CAP_SEC)        # 8시간 캡
simulated_launches = floor(delta * effective_rate)
```

- 자동 발사 미해금 시 캡 0 (또는 1h 짧게)
- 결정적 시뮬 — 확률 기댓값 기반 (RNG seed는 SaveSystem에 저장)
- 복귀 시 모달: "오프라인 동안 자동 발사 N회 / Credit +X / XP +Y"

### 4.7 플레이어 체감

- 토글 ON → 메인 화면에 있어도 루프가 돈다.
- IAP `Auto Launch Pass` 구매자가 즉시 체감 (속도 +35%).
- 8시간 외출 후 복귀 → "오프라인 동안 +N회 발사" 요약 → 복귀 보상감.
- 목적지 변경 시에만 자동으로 꺼지고, 이외에는 계속 돌아감.

---

## 5. Stress / Overload / Abort — 상위 티어 리스크 (1-4)

### 5.1 디자인 의도

**"난이도는 확률만으로는 부족하다. 실패가 누적되는 감각이 필요하다."**

T3(Mars Transfer) 이상에서만 켜지는 **리스크 시스템**. 없었다면 상위 티어도 "확률만 높은 반복"이 되었을 것. Stress는:

- **누적 실패에 의미 부여** — 실패할수록 다음 발사가 더 위험해짐.
- **AFK 자연 감쇠** — 플레이어가 자리를 비우거나 다른 일을 하면 풀림.
- **IAP 접점 창출** — System Purge(즉시 정화), Launch Fail-safe(Abort 환불) 같은 상품의 존재 이유.
- **Abort 이벤트 = 미니 실패 시네마틱** — 화면 임팩트를 줄 기회.

### 5.2 티어별 수치

| 티어 | 실패 시 스트레스 누적 | Abort 확률 (Overload 시) | Repair Cost |
|---:|---:|---:|---:|
| 1 | 0 | 0% | 0 |
| 2 | 0 | 0% | 0 |
| **3** | **+10** | **40%** | **300 C** |
| **4** | **+15** | **50%** | **700 C** |
| **5** | **+20** | **60%** | **1,500 C** |

**공통**:
- MAX_GAUGE = 100 (100을 넘으면 `System Overload` 상태 진입)
- IDLE_THRESHOLD = 5초 후부터 초당 2씩 자연 감쇠

### 5.3 상태 전이

```
[IDLE]  게이지 0
  ↓ (발사 실패 1회)
[ACCUMULATING]  게이지 누적 중
  ↓ (게이지 ≥ 100)
[OVERLOAD]  다음 발사마다 Abort 확률 발동
  ↓ (Abort 판정 성공)
[ABORT]  발사 중단 + Credit 차감 + 스트레스 0 리셋
  ↓
[IDLE]
```

### 5.4 플레이어 경험

**낮은 티어 (T1~T2)**: 스트레스 시스템 존재를 인지하지 않아도 됨. UI에도 노출 안 함.

**T3 진입 시 온보딩**: 첫 실패 시 게이지 UI 등장. "이게 뭐지?" → 설명 툴팁.

**Overload 돌입**: 게이지 가득 차면 경고 색. 발사 버튼 누를 때마다 "40% 확률로 중단될 수 있음" 경고.

**Abort 발생**: 풀스크린 팝업 (`AbortScreen` — `scenes/ui/abort_screen.tscn`). 차감된 Credit 표시. 자동 발사 중단. "다시 도전" / "Shield 구매" / "광고 시청 → 50% 환불" 선택지.

### 5.5 감쇠 — AFK가 정화 행위

```
지난 발사 후 5초 초과 시점부터 초당 -2
```

`StressService._process(delta)`에서 누적 시간 측정. `last_launch_at`을 기준으로.

**의도된 플레이 패턴**:
- 과열되면 잠시 멈추고 업그레이드 메뉴를 둘러본다 → 자연 감쇠 → 게이지 리셋 → 다시 도전.
- 무한 연타로 "뚫고 지나가기"는 구조적으로 막혀 있음.

### 5.6 IAP 연결점

| 상품 | 가격 | 기능 | 디자인 의도 |
|---|---|---|---|
| System Purge | $0.99 | 스트레스 -30 즉시 감소 | 비상 탈출구, 가난한 플레이어도 선택 가능 |
| Launch Fail-safe T3 | $2.99 | 다음 T3 Abort Repair Cost 면제 | "이번 발사만은 포기 못해" 보험 |
| Launch Fail-safe T4 | $4.99 | T4 Abort Repair Cost 면제 | 고난도 도전 보호 |
| Launch Fail-safe T5 | $9.99 | T5 Abort Repair Cost 면제 | 엔드게임 보호 |
| Rewarded Ad (Mobile) | 무료 | 광고 시청 → 50% 환불 (일일 3회) | F2P 경로 |

### 5.7 디자인 주의점

- **Overload는 "락"이 아니다**. 플레이어가 계속 시도할 수는 있으며 매번 확률적으로 Abort. 이 선택지를 열어두는 이유: "운 좋게 한 번 뚫고 나가는" 스릴.
- **Abort도 스트레스 리셋 트리거**. 즉 처벌이자 동시에 정화 이벤트 — Repair Cost를 내면 스트레스가 0으로 돌아감.
- **오버슈트 허용 (최대 200 까지 누적)**. UI는 100 기준이지만 내부적으로 200까지 올라갈 수 있음 → 복잡한 버프 누산에도 안전.
- **Repair Cost는 가진 만큼만 차감** (`GameState.spend_credit_clamped()`) — 가난한 플레이어를 영원히 락인하지 않음.

---

## 6. 밸런스 튜닝 시트

**표준 플레이어(IAP 무과금, 풀 업그레이드) 기준 기대치**:

| 지표 | T1 | T3 | T5 |
|---|---:|---:|---:|
| 스테이지 수 | 3~4 | 7~8 | 10 |
| 평균 스테이지 성공률 (풀업) | 85% | 72% | 60% |
| 풀 클리어 확률 (최대 업그레이드 가정) | ~52% | ~8% | ~0.6% |
| 세션 내 평균 시도 수 | 2회 | 12회 | 166회 |
| 1회 세션 소요 시간 (2s × 스테이지) | 6~8초 | 14~16초 | 20초 |

> **T5가 0.6%라는 수치는 "확률만으로 가는 경우"의 바닥값**. Stress로 추가 제동이 걸리고, 플레이어는 반복으로 TechLevel/Facility를 축적해 기대치를 올린다.

---

## 7. 주요 디자인 의사결정

| 주제 | 결정 | 대안과 기각 이유 |
|---|---|---|
| 스테이지 시간 | 2.0s 고정 | 1초는 연출 부족, 3초는 템포 지루 |
| 실패 시 루프 중단 | 즉시 break | "마지막 스테이지만 재시도"는 확률 의미 퇴색 |
| Stress 시작 티어 | T3 | T1부터 켜면 신규 유저 이탈. T4는 너무 늦음 |
| Auto Launch 해금 | OR 조건 2개 (T1 클리어 / 10회 발사) | 강제 IAP 요구는 UX 저항 |
| Repair Cost 차감 | clamped (가진 만큼) | 강제 차감은 가난한 플레이어를 영원히 락인 |
| 확률 상한 (60~85%) | 100%로 가지 않음 | 확률 장르의 긴장감 유지 |
| 발사 진입점 | 메인 화면 직접 LAUNCH | 모바일 / Steam 한 손 조작에 최적화 |
| TechLevel 직접 판매 IAP | 절대 금지 | 단조 증가축은 P2W 방어선 |

---

## 8. 알려진 이슈 / 미연결

1. **Pity System** — 연속 실패 시 자동 확률 보정. 코드 구현 + 보정 곡선 튜닝 필요. UI에 노출하지 않음.
2. **Trajectory Surge 합산 검증** — `+3%p` 시간제 보너스가 실시간으로 합산되는지 코드 검증 필요.
3. **사전 렌더 영상 5종 + Zone 첫진입 11종** — 핵심 마일스톤 (10/25/50/75/100) + Zone 첫진입 영상 작업 (`VideoStreamPlayer`).

---

## 9. 관련 원본 문서

- `docs/systems/1-1-launch-session.md`
- `docs/systems/1-2-multi-stage-probability.md`
- `docs/systems/1-3-auto-launch.md`
- `docs/systems/1-4-stress-abort.md`
- `docs/rocket_launch_implementation_spec.md` (구현 사양)
- `docs/launch_balance_design.md` (확률 튜닝)
- `docs/post_landing_bm_plan.md` §5~8 (Stress / Auto IAP 노출 전략)
