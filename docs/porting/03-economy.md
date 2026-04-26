# 03. Economy — 3화폐 경제 기획서

> **문서 유형**: 게임 플레이 기획서 (Gameplay Design Document)
> **작성일**: 2026-04-24
> **정본 근거**: `docs/systems/3-1-currency.md`, `3-2-destination-reward.md`
> **대상 독자**: 이코노미 디자이너 / BM 기획자 / QA

---

## 0. 개요

Star Reach의 경제는 **3가지 화폐**와 **단일 보상 파이프라인**으로 구성된다. Launch Core가 발사를 만들고, Progression이 투자처를 제공하는 사이, Economy는 "무엇이 교환되고 무엇이 교환되지 않는지"의 규칙을 규정한다.

**2개 하위 시스템**:

| ID | 시스템 | 역할 |
|---|---|---|
| 3-1 | Currency | 3화폐 정의 / 계좌 관리 / 교환 금지 원칙 |
| 3-2 | Destination Reward | 목적지 완료 → Credit/TechLevel 지급의 단일 파이프라인 |

---

## 1. 3화폐 체계 (3-1)

### 1.1 디자인 철학

**"역할이 다른 세 화폐는 서로 교환되지 않는다."**

한 게임에 여러 화폐를 두는 전형적 이유는 "소비처 분리로 인플레이션 통제". 본 게임은 이를 더 엄격하게 적용해:

```
XP        → 세션 내부에서만 순환 (목적지 변경 시 리셋)
Credit    → 영구 성장 + Stress 리스크 정산
TechLevel → 해금 축 + 미션 장기 축 (직접 판매 IAP 절대 금지)
```

**금지된 교환 경로** (보존해야 할 경계):
- ❌ XP → Credit 변환
- ❌ Credit → TechLevel 변환
- ❌ **TechLevel 직접 판매 IAP** (단조 증가축은 P2W 방어선)

이 경계가 무너지면:
- IAP 상품의 가치가 가려짐 ("돈 내면 즉시 TechLevel 500 받음" 같은 단축키가 장기 성장을 무력화).
- 세션 투자의 긴장감 상실 (영구 성장으로 세션 난이도가 녹아버림).

### 1.2 3화폐 상세

| 표시 | GameState 필드 | 역할 | 획득 | 소비 |
|---|---|---|---|---|
| **XP** | `launch_tech_session.xp` | 세션 성장 연료 | 스테이지 1개 성공 | Launch Tech 5종 구매 |
| **Credit** | `credit` | 영구 성장 + 리스크 | 목적지 완료 / Daily Reward / IAP Credit Pack | Facility Upgrades / Stress Repair |
| **TechLevel** | `tech_level` | 해금 + 미션 보상 | 목적지 완료 + 미션 | **소비 없음** (read-only 게이트) |

### 1.3 Credit 차감의 두 가지 모드

| 메서드 | 동작 | 사용처 |
|---|---|---|
| `GameState.spend_credit(amount) -> bool` | 잔고 부족 시 false 반환 (상태 불변) | 자발적 구매 (Facility, IAP 보너스 적용) |
| `GameState.spend_credit_clamped(amount) -> int` | 가진 만큼만 차감 (실제 차감액 반환) | **Stress Abort 벌금 전용** |

**`spend_credit_clamped`의 의도**: 가난한 플레이어도 Abort 처벌은 받아야 함. 잔고 0이어도 이벤트는 발생하고, 차감액은 실제 가진 만큼만 기록 → `last_abort_fine`로 보존 (Launch Fail-safe IAP 환불 상품이 이 값을 사용).

### 1.4 XP 리셋의 의도

XP는 `launch_tech_session` 하위에 저장 → **목적지 변경 시 전부 0으로**. 이 리셋이 만드는 플레이 감각:

- "이 목적지에 얼마나 투자할지" 전략 선택 (목적지 변경 기회비용).
- XP 쌓기만 하는 무의미함 방지 — 쌓인 XP는 즉시 Launch Tech에 소비해야 가치 있음.
- 장기 화폐(Credit, TechLevel)와의 역할 분리.

### 1.5 증감 경로 맵

**증가**:

| 화폐 | 증가 이벤트 | 최종 배율 |
|---|---|---|
| XP | 스테이지 성공 | base(5 + telemetry) × fuel_optimization × (1 + data_collection) × IAP 배수 (VIP/Boost) |
| Credit | 목적지 완료 / Daily / IAP Credit Pack | reward_credit × (1 + mission_reward) |
| TechLevel | 목적지 완료 + 미션 | reward_tech_level × (1 + tech_reputation) / 미션은 가산 (일일 캡 50, 주간 캡 500/750) |

**감소**:

| 화폐 | 감소 이벤트 | 방식 |
|---|---|---|
| XP | Launch Tech 구매 | `spend_xp` (부족 시 실패) |
| Credit | Facility Upgrade | `spend_credit` |
| Credit | Stress Abort | `spend_credit_clamped` (가진 만큼) |
| TechLevel | **없음** | 단조증가 |

### 1.6 플레이어 체감 — UI 노출

| 화폐 | 노출 위치 | 업데이트 트리거 |
|---|---|---|
| XP | LaunchTechPanel (세션 UI) | 스테이지 결과, 구매 |
| Credit | GlobalHUD 상단, FacilityUpgradePanel | `EventBus.destination_completed`, 구매 |
| TechLevel | GlobalHUD 상단, DestinationPanel, MissionPanel | `destination_completed`, 미션 클레임 |

### 1.7 디자인 주의점

- **단일 클라이언트 동시성 안전**. 싱글 클라이언트이므로 race condition 없음. `await` 경계를 넘는 순서만 주의.
- **음수 방지 가드**. `add_credit(-x)` 같은 호출 차단 — `assert(amount >= 0)`로 방어.
- **정수 Credit 가정**. 소수점 Credit은 설계상 없음 — 모든 공식 마지막에 `floor(x + 0.5)` 반올림.

---

## 2. Destination Reward — 목적지 완료 보상 파이프라인 (3-2)

### 2.1 디자인 의도

**"목적지 완료 한 번 = 게임에서 가장 크고 복잡한 이벤트."**

이 게임에서 플레이어가 "보상을 받는" 유일한 큰 사건은 목적지 완료 순간이다. 이 한 함수는:

- Credit / TechLevel 지급
- 보정 (Facility) 적용
- Region 첫도달 / Mastery 판정
- Best Records 갱신
- Badge 체크 (+ Steam/GPG/iOS Achievement 매핑)
- Discovery 엔트리 갱신
- 자동 진행 판정
- 세션 리셋
- 마일스톤 영상 트리거 (10/25/50/75/100)

...을 **단일 트랜잭션**처럼 처리하고, 그 결과를 `EventBus.destination_completed` 시그널 하나로 발화한다. UI / VFX / Audio / Codex / Badge 등은 이 시그널을 구독해 자체 반응.

### 2.2 보상 공식

```gdscript
var credit_gain := floor(
    destination.reward_credit
    * (1.0 + facility.mission_reward * 0.05)
    + 0.5
) as int

var tech_level_gain := floor(
    destination.reward_tech_level
    * (1.0 + facility.tech_reputation * 0.05)
    + 0.5
) as int
```

**개인 한정 부스터 모델**: 싱글 게임이므로 모든 부스터는 개인 단위. IAP `Trajectory Surge`(시간제 +3%p 확률) / `Boost 2x`(XP 2배) 같은 시간제 IAP로 가속.

### 2.3 보상 스케일

**기본 보상 (보정 없음)**:

| 티어 | Credit 범위 | TechLevel 범위 |
|---:|---:|---:|
| 1 | 5~15 | 3~8 |
| 2 | 18~45 | 10~20 |
| 3 | 50~110 | 25~40 |
| 4 | 130~280 | 40~60 |
| 5 | 320~800 | 60~100 |

**최대 보정 (Facility 만렙)**:

| 티어 | Credit 최대 (×2) | TechLevel 최대 (×1.5) |
|---:|---:|---:|
| 1 | 10~30 | 4.5~12 |
| 5 | 640~1,600 | 90~150 |

### 2.4 파이프라인 순서 (중요)

```
1. 보상 계산 (Credit, TechLevel)
2. GameState에 즉시 반영 (add_credit, add_tech_level, increment_total_wins)
3. highest_completed_tier 갱신
4. completed_destinations[d_id] = true
5. Region 첫도달 체크 → Badge (+ Achievement 매핑)
6. Mastery 레벨업 체크 (이전/이후 비교)
7. Best Records 업데이트
8. Win 카운트 Badge 체크
9. Discovery 갱신 (`EventBus.codex_*` 시그널 연쇄 발화)
10. 자동 진행 판정 (advanced=true if next required_tech_level <= tech_level)
11. (advanced=true 시) Launch Tech / Stress 세션 리셋
12. Telemetry 기록 (옵션 — 로컬 + Steam User Stats / GPG Events / Firebase Analytics)
13. EventBus.destination_completed.emit(d_id, reward_dict)
14. 마일스톤 카운트 충족 시 VideoStreamPlayer 영상 트리거
```

**순서가 중요한 이유**: Badge/Discovery 체크 시점에는 이미 `tech_level`, `completed_destinations`가 갱신된 상태. 이 순서가 뒤집히면 "이번 완료로 언락된 Badge"를 놓칠 수 있음.

### 2.5 자동 진행 vs 반복 선택권

완료 직후 **다음 목적지의 required_tech_level 충족 여부**로 자동 진행 판정:
- 충족 → `current_destination_id` 자동 변경 + 세션 리셋
- 미충족 → 현재 목적지 유지 → 반복 플레이 가능

**플레이어 측면**: 자동 진행이 강제되는 것이 아니라, "이 목적지를 더 파고 싶다"면 수동으로 이전 목적지를 `DestinationPanel`에서 선택할 수 있다.

### 2.6 Wins vs CompletedDestinations 구분

| 카운터 | 성격 | 증가 조건 |
|---|---|---|
| `total_wins` | 단순 증가 카운터 | 완료 1회마다 +1 |
| `completed_destinations` | 고유 집합 | 이미 true면 불변 |

같은 목적지를 100번 반복 클리어하면 `total_wins = 100`이지만 `completed_destinations`는 1개. Best Records (TotalWins 트랙)는 `total_wins`를 기준으로 사용.

---

## 3. EventBus 시그널 페이로드 — Economy의 단일 출력

목적지 완료의 **모든 결과**가 하나의 시그널 페이로드에 담긴다 (네트워크 패킷 폐기):

```gdscript
# scripts/autoload/event_bus.gd
signal destination_completed(d_id: String, payload: Dictionary)

# payload 예시
{
    "total_launches": 1234,
    "total_wins": 89,
    "credit_gain": 660,
    "credit_balance": 5430,
    "tech_level_gain": 60,
    "total_tech_level": 720,
    "destination_id": "D_036",
    "destination_name": "Mars Flyby Probe",
    "tier": 3,
    "next_destination_id": "D_037",
    "region_first_arrival_badge_id": "BADGE_MARS_PATHFINDER",  # 옵션 (있으면 첫도달)
    "mastery_level_up": "M2 Explorer",                           # 옵션 (이번에 오른 단계)
    "discovery_change_type": "section_unlocked",                 # 옵션
    "discovery_entry_id": "BODY_MARS",
    "discovery_new_section_id": "surface",
    "milestone_video_id": null                                   # 옵션 (10/25/50/75/100 도달 시 영상 ID)
}
```

**설계 이점**: UI / VFX / Audio / Codex / Badge 모두 단일 시그널 구독으로 모든 결과를 동기화. WinScreen UI는 이 페이로드 하나를 받아 렌더링.

마일스톤 영상 (10/25/50/75/100 첫도달) 시 `payload.milestone_video_id`가 채워져 `VideoStreamPlayer`가 풀스크린 재생.

---

## 4. 경제 밸런스 — 플레이어의 자원 흐름 모델

### 4.1 신규 플레이어 첫 30분

```
[0~5분]   T1 목적지 도전
  - XP 획득 → Launch Tech 초기 1~2단계 구매
  - T1 완료 → Credit 5~15, TechLevel 3~8
[5~15분]  T1 반복 + T2 해금
  - Credit → Facility 첫 레벨 (engine_tech 또는 mission_reward)
  - TechLevel 20~50 → T2 해금
  - Daily Reward 첫 노출 (T1 완료 후)
[15~30분] T2~T3 진입
  - Facility engine_tech 3~5레벨 도달
  - TechLevel 100~200 → T3 해금
  - VIP / Auto Launch Pass IAP CTA 첫 노출
```

### 4.2 중기 성장 (수십 시간 플레이)

- Credit 누적 → Facility data_collection 풀업 → XP 획득량 3배
- XP 풀 공급 → Launch Tech 즉시 풀업 가능
- TechLevel 지속 상승 → 상위 목적지 해금 연쇄
- Auto Launch + Offline Progress로 비접속 진행 누적 (캡 8h)

### 4.3 IAP 영향 지점

| IAP | 가격 | 경제 레이어 | 기여 |
|---|---|---|---|
| VIP / Boost 2x | $2.99 / $1.49 | XP 증가 | 세션 가속 |
| Auto Launch Pass | $4.99 | 발사 rate +0.35 | 루프 속도 |
| Auto Fuel | $0.99 / 60분 | 발사 rate +0.50 | 일시 가속 |
| Guidance Module | $5.99 | 성공률 +5%p | 영구 보정 |
| Trajectory Surge | $1.99 / 30분 | 성공률 +3%p | 일시 보정 |
| System Purge | $0.99 | Stress -30 | 리스크 완화 |
| Launch Fail-safe T3/T4/T5 | $2.99/$4.99/$9.99 | Abort Repair Cost 면제 | 리스크 완화 |
| Credit Pack S/M/L | $0.99/$4.99/$9.99 | +500/+3000/+7500 Credit | Facility 가속 |
| Subscription Orbital Ops Pass | $4.99/월 | 광고 제거 + 일일/주간/월간 부스터 + 보너스 | 종합 |

**모두 가속 / 편의 / 리스크 완화 / 경제 보조**이며, "TechLevel 즉시 지급" 같은 직접 보상은 영원히 금지 (P2W 방어선).

---

## 5. 알려진 이슈 / 포팅 시 주의

1. **단일 함수의 과도한 책임**. `complete_destination()`이 지급 + Region + Mastery + Best Records + Badge + Discovery + 자동 진행 + Telemetry를 모두 담당. 시그널 발화 후 각 서비스가 **자체 구독**으로 분리 구현 권장.
2. **`ai_navigation` Facility 보정 V1 활성**. 오프라인 자동 발사 효율 보너스로 정의 (→ 02 §5).
3. **TechLevel 리셋/프레스티지 없음**. 단조증가만 있음. 장기 플레이어 시뮬레이션 시 인플레이션 관찰 필요.
4. **음수 amount 방어 코드**. `add_credit(-x)` `assert` 가드 필요.
5. **마일스톤 영상 5종 제작** — 10/25/50/75/100 영상 작업 (5~12초, 720p, ≤1.5Mbps OGV).

---

## 6. 관련 원본 문서

- `docs/systems/3-1-currency.md`
- `docs/systems/3-2-destination-reward.md`
- `docs/game_term_alignment_review.md` §6.2, §6.6 (용어 정렬)
- `docs/post_landing_bm_plan.md` §2~3 (경제 원칙)
- `docs/destination_config.md` §9 (보상 스케일)
- `docs/bm.md` §3 (IAP 정의 + 가격)
