# 게임 주요 용어 정합성 검토

> **문서 유형**: 용어 리뷰 / BM 선행 검토
> **작성일**: 2026-04-24
> **관련 문서**: `docs/bm.md`, `docs/social_bm.md`, `docs/game_concept_rocket_launch.md`
> **검토 기준 파일**: `data/launch_tech_config.tres`, `data/facility_upgrade_config.tres`, `data/iap_config.tres`, `data/stress_config.tres`, `scripts/ui/*.gd`

---

## 1. 문서 목적

게임에 랜딩한 유저 대상 BM을 기획하기 전에, 현재 정의된 주요 게임 요소의 용어가 `로켓 발사 / 우주 개척` 컨셉에 맞게 정리되어 있는지 점검한다.

이 문서의 목적은 두 가지다.

1. 플레이어가 보는 용어가 컨셉과 충돌하지 않는지 확인
2. 이후 BM 상품명, 이벤트명, 보상명 설계에 쓸 기준 용어 체계를 정리

---

## 2. 총평

현재 용어 체계는 **부분 적합** 상태다.

정리하면 다음과 같다.

1. 코어 플레이 용어는 대체로 이해 가능하고 컨셉과도 맞는다.
2. 다만 상점 상품명, 리스크 시스템 용어, 일부 업그레이드 명칭은 톤이 섞여 있다.
3. 내부 코드에는 이전 장르의 잔재가 많이 남아 있어, 지금은 숨겨져 있어도 운영/BM 문서 단계에서 혼선을 만든다.

즉, 지금 상태는 "당장 플레이가 불가능할 정도로 어색하지는 않지만, BM을 본격 설계하기에는 용어 정리가 덜 된 상태"다.

---

## 3. 현재 용어의 적합성 평가

### 3.1 유지해도 되는 용어

아래 용어는 현재 컨셉과 비교적 잘 맞는다.

| 분류 | 현재 용어 | 판단 |
|---|---|---|
| 코어 액션 | `Launch`, `Stage`, `Destination` | 직관적이고 컨셉 적합 |
| 진행 구분 | `Tier`, `Low Orbit`, `Lunar`, `Planetary`, `Deep Space` | 이해 쉽고 구조 명확 |
| 자동화 | `Auto Launch` | 기능 의미가 명확 |
| 세션 기술 | `Engine Precision`, `Telemetry`, `Fuel Optimization`, `Auto-Checklist` | 발사 게임 톤에 맞음 |
| 영구 기술 | `Engine Tech`, `Data Collection`, `Mission Reward`, `Tech Reputation`, `AI Navigation` | 무난하고 설명 가능 |
| 보상 재화 | `Credit`, `Tech Level` | 다소 일반적이지만 이해는 쉬움 |
| 리스크 상태 | `Stress`, `Overload`, `Abort` | 우주 장비/시스템 문맥으로 수용 가능 |

이 용어들은 굳이 과도하게 바꾸기보다 유지하는 편이 좋다.

### 3.2 더 좋아질 수 있는 용어 확정안

아래 용어는 기존 표현도 틀리지는 않지만, BM과 운영 문구까지 고려해 최종적으로 아래 이름으로 확정한다.

| 현재 용어 | 확정 용어 | 확정 이유 |
|---|---|---|
| `Mission Tech` | `Launch Tech` | 세션 성장의 성격이 더 직접적으로 전달됨 |
| `Base Tech` | `Facility Upgrades` | 영구 성장과 기지/프로그램 확장 감각이 더 강함 |
| `XP` | `XP` | 학습 비용이 가장 낮고 모바일/Steam 유저 모두에게 익숙함 |
| `Tech Lv.` | `Program Lv.` | 전체 우주 발사 프로그램의 성장이라는 의미가 더 분명함 |
| `Legendary` | `Interstellar` | RPG 톤보다 우주 개척 컨셉에 직접적으로 맞음 |

즉, 이 영역은 전면 개명보다 `직관성 + 컨셉 정합성 + 구현 부담`을 함께 고려해 확정했다.

### 3.3 즉시 정리가 필요한 용어 확정안

아래 항목은 실제 플레이어 경험과 BM 문구에서 혼선을 만들 수 있으므로 수정 용어를 확정한다.

| 현재 용어 | 확정 용어 | 우선순위 |
|---|---|---|
| `Specialization` / `Stress Bypass` | `Stress Bypass` | P0 |
| `Lucky Charm` | `Guidance Module` | P0 |
| `Lucky Surge` | `Trajectory Surge` | P0 |
| `Stress Wiper` | `System Purge` | P0 |
| `Prestige Pass` | `Mission Control Pass` | P1 |
| `Auto Master` | `Launch Automation Pass` | P1 |
| `Emergency Shield` | `Launch Fail-safe` | P1 |
| `Tier 5 - Legendary` | `Tier 5 - Interstellar` | P1 |

---

## 4. 핵심 문제 상세

### 4.1 업그레이드 명칭 일관성 부족

가장 대표적인 문제는 `MissionTechConfig`의 `Specialization`이 UI에서는 `Stress Bypass`로 보인다는 점이다.

이 문제는 단순 번역 문제가 아니다.

1. 플레이어는 같은 업그레이드가 무엇인지 바로 대응하기 어렵다.
2. 가이드 문서와 실제 UI가 어긋난다.
3. 이후 BM 상품 설명이나 공략 문구 작성 시 혼선이 생긴다.

이 항목은 반드시 하나로 통일해야 한다.

최종 확정:

1. 플레이어 노출 용어는 `Stress Bypass`
2. 설명 문구는 `System stress reduction`

즉, 이름은 효과 중심으로 단순화하고 설명에서 시스템 맥락을 보강한다.

### 4.2 BM 상품명이 게임 컨셉보다 일반 모바일 게임 톤에 가깝다

현재 상점 상품명은 기능은 전달하지만 게임 고유성이 약하다.

대표적으로:

1. `Lucky Charm`
2. `Lucky Surge`
3. `Prestige Pass`
4. `Auto Master`
5. `Social Booster`
6. `Stress Wiper`

이 용어들은 이해는 쉽지만, 발사/궤도/엔진/관제/시스템 같은 우주 테마보다 `모바일 RPG` 또는 `일반 F2P 게임` 톤에 가깝다.

BM을 본격 설계할수록 이 문제는 더 커진다.  
유저가 돈을 쓰는 순간에는 시스템명보다 `상품명`이 더 강하게 기억되기 때문이다.

### 4.3 리스크 시스템 용어는 방향은 맞지만 잔재가 남아 있다

현재 유저가 보는 용어는 `Stress`, `Overload`, `Abort`, `Repair Cost`로 비교적 괜찮다.  
하지만 내부에는 `ARREST`, `TRACE`, `tracewipe`, `ExploitSession`, `clues` 같은 이전 장르 용어가 남아 있다.

이 잔재는 지금 당장 플레이어에게 크게 보이지 않을 수 있다.  
하지만 아래 지점에서 계속 문제를 만들 수 있다.

1. 운영용 로그
2. 관리자 명령어
3. 텔레메트리 이벤트 명
4. 내부 기획 문서
5. 향후 UI 확장 시 누출

즉, 당장 화면보다 `팀 내부 언어`를 오염시키는 문제다.

### 4.4 진행 계층 명칭이 부분적으로 섞여 있다

현재 시스템은 `Destination`, `Target`, `Tier`, `Tech Level`을 함께 쓴다.

문제는 다음과 같다.

1. 플레이어 UI는 `Destination`
2. 데이터는 `currentTargetId`
3. 상위 구분은 `Tier`
4. 해금 조건은 `Tech Level`

구조상 큰 문제는 아니지만, 이후 BM 문구에서는 가능한 한 다음처럼 고정하는 편이 좋다.

1. 플레이어 노출: `Destination`
2. 데이터 용어: 내부에서만 `Target` 사용 가능
3. 티어 이름: `Orbit / Lunar / Planetary / Deep Space / Interstellar`

즉, 플레이어-facing 텍스트에서는 한 축으로 통일해야 한다.

---

## 5. BM 관점에서 특히 위험한 용어

BM을 붙일 때 가장 먼저 문제 되는 것은 `돈을 쓰는 요소의 이름`이다.

### 5.1 확정 상품명

| 현재 이름 | 확정 이름 | 판단 |
|---|---|---|
| `Lucky Charm` | `Guidance Module` | 상시 성공률 보정형 IAP에 적합 |
| `Lucky Surge` | `Trajectory Surge` | 시간제 성공률 부스트에 적합 |
| `Stress Wiper` | `System Purge` | 시스템 스트레스 제거 기능과 맞음 |
| `Prestige Pass` | `Mission Control Pass` | 후반 QoL/편의 IAP에 적합 (V2 — 분석 패널 구현 후) |
| `Auto Master` | `Auto Launch Pass` | 자동화 기능과 직접 연결됨 |
| `Emergency Shield` | `Launch Fail-safe` | 발사 실패 보호 장치라는 의미가 분명함 |

### 5.2 유지 가능한 BM 용어

| 용어 | 판단 |
|---|---|
| `VIP` | 일반적이지만 모바일 / Steam 유저 모두에게 이해가 쉬워 유지 가능 |
| `Auto Launch` | 기능 의미가 분명해 유지 권장 |
| `Credits` | BM 재화 용어로 안정적 |
| `Tier` | 내부/외부 모두 무난 |

즉, 모든 용어를 억지로 SF화할 필요는 없다.  
**문제는 "일반적임"이 아니라 "컨셉과 부딪히거나 서로 다르게 불리는 용어"**다.

---

## 6. 확정 용어 체계

현재 게임은 아래 계층으로 용어를 통일하는 것으로 확정한다.

### 6.1 코어 루프

1. `Launch`
2. `Stage`
3. `Destination`
4. `Tier`

### 6.2 성장

1. 세션 성장: `Launch Tech`
2. 영구 성장: `Facility Upgrades`
3. 재화: `XP`, `Credits`, `Program Lv.`

즉, 플레이어가 보는 성장 용어는 `Launch Tech / Facility Upgrades / Program Lv.` 축으로 고정한다.

### 6.3 리스크

1. `Stress`
2. `Overload`
3. `Abort`
4. `Repair Cost`
5. `Launch Fail-safe`

### 6.4 메타 보너스 (Single-Player Retention)

1. `Daily Login Reward` (1~7일 스트릭)
2. `Daily Mission` (3개/일, 구독자 +1)
3. `Region Mastery` (지역 모든 목적지 클리어)
4. `Codex Progress Bonus` (도감 25/50/75/100%)
5. `Playtime Title` (10/50/100/500/1000시간 누적)
6. `Season Collection` (분기별 한정 코스메틱)

### 6.5 BM 상품

1. `VIP` (영구 IAP)
2. `Auto Launch Pass` (영구 IAP)
3. `Guidance Module` (영구 IAP)
4. `Trajectory Surge` (소모 IAP, 30분)
5. `Auto Fuel` (소모 IAP, 60분)
6. `2x Boost` (소모 IAP, 30분)
7. `System Purge` (소모 IAP)
8. `Launch Fail-safe T3/T4/T5` (소모 IAP)
9. `Credit Pack S/M/L` (소모 IAP)
10. `Orbital Operations Pass` (월 구독)
11. `Battle Pass — Premium` (시즌 IAP)
12. Steam DLC: `Standard Edition`, `Deluxe Edition`, `Interstellar Frontier Expansion`, `Cosmetic DLC`

### 6.6 내부 코드 용어 (Godot GDScript)

플레이어에게 직접 보이지 않더라도 아래 내부 변수/시그널/리소스 용어를 통일한다 (snake_case 표기).

| 영역 | 확정 내부 용어 |
|---|---|
| 세션 화폐 (`GameState`) | `xp`, `credit`, `tech_level` |
| 세션 컨텍스트 | `launch_tech_session` |
| Launch Tech 5종 | `engine_precision_level`, `telemetry_level`, `fuel_optimization_level`, `auto_checklist_level`, `stress_bypass_level` |
| Facility Upgrade 5종 | `engine_tech_level`, `data_collection_level`, `mission_reward_level`, `tech_reputation_level`, `ai_navigation_level` |
| 리스크 상태 | `STRESS_NORMAL`, `STRESS_OVERLOAD`, `LAUNCH_ABORT` |
| 진행 추적 | `highest_completed_tier`, `total_launches`, `cleared_tiers` |
| EventBus 시그널 | `stage_succeeded`, `stage_failed`, `launch_completed`, `destination_completed`, `region_first_visited`, `iap_purchased` |

---

## 7. 우선순위 제안

### 7.1 P0

1. `Stress Bypass` 명칭 통일
2. `Guidance Module`, `Trajectory Surge`, `System Purge` IAP 반영
3. `Tier 5 - Interstellar` 용어 통일

### 7.2 P1

1. `Auto Launch Pass`, `Launch Fail-safe T3/T4/T5` 반영
2. 리스크 시스템 관련 `ABORT` / `OVERLOAD` 내부 잔재 정리
3. `Orbital Operations Pass` 월 구독 + `Battle Pass` 시즌 IAP 반영

### 7.3 P2

1. `Launch Tech` 전환 반영
2. `Facility Upgrades` 전환 반영
3. `Program Lv.` 표기 반영
4. `Mission Control Pass` (V2, 분석 패널 구현 후)

---

## 8. 최종 판단

현재 용어 체계는 "로켓 발사 게임으로서 완전히 틀린 상태"는 아니다.  
하지만 BM을 붙일수록 아래 문제가 커진다.

1. 상점 상품명이 게임 고유성을 약하게 만든다.
2. 일부 핵심 시스템이 서로 다른 이름으로 불린다.
3. 내부 장르 잔재가 운영과 문서 단계에서 계속 섞여 나온다.

따라서 다음 단계 BM 기획 전에 가장 현실적인 목표는 이렇다.

1. 코어 루프 용어는 유지
2. 상점/리스크/업그레이드 핵심 명칭은 이번 확정안으로 정리
3. 내부 잔재 용어는 점진적으로 제거

즉, **지금 필요한 것은 전면 개명보다 "유저가 돈을 쓰고, 이해하고, 반복하게 되는 핵심 명칭"을 이번 확정안 기준으로 먼저 통일하는 작업**이다.
