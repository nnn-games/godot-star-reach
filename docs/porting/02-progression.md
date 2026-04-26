# 02. Progression — 성장 축 기획서

> **문서 유형**: 게임 플레이 기획서 (Gameplay Design Document)
> **작성일**: 2026-04-24
> **정본 근거**: `docs/systems/2-1-destination.md` ~ `2-5-facility-upgrades.md`
> **대상 독자**: 디자이너 / 콘텐츠 기획자 / 밸런스 담당

---

## 0. 개요

**Progression**은 "발사 루프를 **어디로**, **얼마나 깊게**, **어떤 속도로** 반복할 것인가"를 결정하는 5개의 성장 축이다. Launch Core가 "한 판"을 만들고, Progression은 "왜 또 누르게 되는가"를 만든다.

**5개 하위 시스템**:

| ID | 축 | 성격 | 리셋 여부 |
|---|---|---|---|
| 2-1 | Destination | 100개 목적지 — 콘텐츠 볼륨 | 개별 클리어 지속 |
| 2-2 | Region | 11개 지역 — 첫도달·마스터리 | 누적 |
| 2-3 | Program Lv. (TechLevel) | 단일 누적 스칼라 — 해금 축 | 누적 (리셋 없음) |
| 2-4 | Launch Tech | 세션형 5종 업그레이드 (XP) | **목적지 변경 시 리셋** |
| 2-5 | Facility Upgrades | 영구형 5종 업그레이드 (Credit) | 누적 (리셋 없음) |

### 0.1 성장 축 구분 철학

```
  [단기]                [중기]                  [장기]
  XP → Launch Tech     Credit → Facility       TechLevel → Destination 해금
  ↓                    ↓                       ↓
  한 목적지 안에서만     영구 경제                게임 전체 진행
  의미                                          해금 게이트
  ↓
  목적지 변경 시
  전부 사라짐
```

**설계 원칙**: 세 축은 **교환되지 않는다**.
- XP로 Credit을 살 수 없다.
- Credit으로 TechLevel을 살 수 없다.
- **TechLevel 직접 판매 IAP 금지** (단조 증가축은 P2W 방어선).

이 경계가 무너지면 IAP 가치가 가려지고, 장기 성장이 과금에 밀림.

---

## 1. Destination — 100목적지 콘텐츠 축 (2-1)

### 1.1 디자인 의도

**"플레이어는 항상 한 곳을 향한다."**

단일 선형 경로(D_01 → D_100)에 100개의 목적지를 깔아 **엔드게임 없는 장기 콘텐츠 볼륨**을 확보. 100개는 지역별로 묶여 있으며(→ 2-2), 티어별로 난이도가 배열되어 있다.

V1 활성 범위는 D_01~D_100 (T1~T5). D_101~D_105 (T6 성간 추가)는 DLC `Interstellar Frontier`로 분리.

### 1.2 목적지 스키마 (Godot Resource)

```gdscript
# data/destinations/d_036.tres 의 기반 클래스
class_name Destination extends Resource

@export var id: String = "D_036"
@export var name: String = "Mars Flyby Probe"
@export var tier: int = 3                              # 확률 구간 결정
@export var region_id: String = "REGION_MARS"          # 지역 그룹 (마스터리 축)
@export var required_stages: int = 7                   # 확률 판정 반복 횟수
@export var reward_credit: int = 50                    # 영구 화폐
@export var reward_tech_level: int = 25                # 해금 화폐
@export var required_tech_level: int = 200             # 선택/자동진행 조건
```

### 1.3 티어 × 스테이지 × 지역

| 티어 | 스테이지 | D_## 범위 | 주요 지역 |
|---:|---:|---|---|
| 1 | 3~4 | D_01~D_20 | Earth Region (20개) |
| 2 | 5~6 | D_21~D_35 | Lunar & NEO (15개) |
| 3 | 7~8 | D_36~D_55 | Inner Solar / Asteroid Belt |
| 4 | 9 | D_56~D_75 | Jovian / Saturnian / Ice Giants |
| 5 | 10 | D_76~D_100 | Pluto / Kuiper / Interstellar / Milky Way / Deep Space (25개) |

> **순차 진행과 지역 그룹은 일치하지 않는다**. T3 내부에서 Venus/Mars/Mercury가 섞여 있어, 순서대로 하나씩 밀고 나가는 과정 자체가 "태양계 투어" 서사가 된다.

### 1.4 선택 / 자동 진행 흐름

**선택 (Destination Panel)**:
```
1. 플레이어가 목적지 ID 지정
2. DestinationService가 required_tech_level <= GameState.tech_level 확인
3. 통과 시 GameState.current_destination_id = d_id
4. Launch Tech 세션 XP/업그레이드 전부 리셋
5. Stress 게이지 리셋
```

**자동 진행 (목적지 완료 직후)**:
```
1. 다음 목적지(D_++1)의 required_tech_level 확인
2. 충족 시 자동으로 current_destination_id 변경 → 새 목적지 시작
3. 미충족 시 현재 목적지 반복 가능 (TechLevel 파밍 루프)
```

**의도된 플레이 패턴**: "다음 목적지의 TechLevel이 부족하면 현재 목적지를 반복해서 TechLevel을 쌓고 자연 진행". 강제 이동이 아닌 **자발적 반복 루프**.

### 1.5 목적지 완료 = 게임의 클라이맥스 이벤트

완료 1회는 아래 모든 사이드 이펙트를 **단일 트랜잭션**처럼 일으킨다:

```
1. Credit / TechLevel 지급 (Facility 보정 적용)
2. total_wins ++
3. highest_completed_tier = max(현재, destination.tier)   ← 확률 구간 상한 갱신
4. completed_destinations[id] = true
5. Region 첫도달 체크 → Badge (→ 2-2)
6. Region Mastery 레벨업 체크 → 명칭 획득 (→ 2-2)
7. Best Records 업데이트 (TotalWins / TechLevel / Best Tier)
8. Win 카운트 기반 Badge 체크
9. Discovery / Codex 엔트리 갱신
10. 자동 진행 판정 → current_destination_id 갱신
11. (advanced 시) Launch Tech / Stress 세션 리셋
12. Telemetry 기록 (옵션 — 로컬 + Steam User Stats / GPG / Firebase)
13. EventBus.destination_completed 시그널 발화 (위 모든 결과가 한 페이로드)
```

마일스톤 목적지(10/25/50/75/100) 완료 시 사전 렌더 영상 1회 재생 (`VideoStreamPlayer`).

### 1.6 연출

- 완료 순간 로켓이 **성공 추가 상승 → 카메라 풀백** (→ 04 Cinematic).
- `WinScreen` 모달: 보상 수치, 새 Badge, 마스터리 레벨업, 도감 신규 엔트리.
- 환경 전환 (`Tween` 1.5~3초로 다음 Tier `SkyProfile` 보간).

---

## 2. Region — 11지역 마스터리 (2-2)

### 2.1 디자인 의도

**"같은 태양계 안에서도 탐험은 달라야 한다."**

100개 목적지를 11개 **지역**으로 묶어:
- **첫도달 Badge** — "처음으로 그 지역에 도달한 순간" 서사
- **마스터리 레벨(M1~M5)** — 지역을 "얼마나 깊게" 탐험했는가의 축
- **반복 동기** — 자연 진행으로는 M3까지만, M4~M5는 의도적 반복 필요

### 2.2 11개 지역

`docs/contents.md`의 11 Zone과 1:1 매핑.

| ID | 이름 | 난이도 | 목적지 수 | 첫도달 Badge |
|---|---|---:|---:|---|
| REGION_EARTH | Earth Region | 1 | 10 | Atmospheric Pioneer |
| REGION_LUNAR_NEO | Lunar & NEO | 2 | 10 | Lunar Explorer |
| REGION_INNER_SOLAR | Inner Solar System | 3 | 10 | Mars Pathfinder |
| REGION_ASTEROID_BELT | Asteroid Belt & Ceres | 3 | 10 | Belt Navigator |
| REGION_JOVIAN | Jovian System | 4 | 10 | Jovian Voyager |
| REGION_SATURNIAN | Saturnian System | 4 | 10 | Ringmaster |
| REGION_ICE_GIANTS | Ice Giants | 4 | 10 | Cryosphere Explorer |
| REGION_PLUTO_KUIPER | Pluto & Kuiper Belt | 5 | 10 | Outer Bound |
| REGION_INTERSTELLAR | Interstellar | 5 | 10 | Interstellar Pilot |
| REGION_MILKY_WAY | Milky Way Landmarks | 5 | 8 | Galactic Cartographer |
| REGION_DEEP_SPACE | Deep Space (T5/V1) | 5 | 7 | Cosmic Frontier |

> 합계 105개 목적지 (D_01~D_105). V1 활성은 D_01~D_100. D_101~D_105는 DLC `Interstellar Frontier` 또는 `Deep Space Edge`에 포함.

### 2.3 마스터리 — 지역 크기별 동적 임계값

**5단계 (M1~M5)**:

| 레벨 | 이름 | 완료율 |
|---:|---|---:|
| M1 | Surveyed | 15% |
| M2 | Explorer | 35% |
| M3 | Specialist | 55% |
| M4 | Veteran | 80% |
| M5 | Master | 100% |

**지역 크기에 맞춘 임계값 예시**:

| 지역 크기 | M1 | M2 | M3 | M4 | M5 |
|---:|---:|---:|---:|---:|---:|
| 10 (대부분) | 2 | 4 | 6 | 8 | 10 |
| 8 (Milky Way) | 2 | 3 | 5 | 7 | 8 |
| 7 (Deep Space) | 2 | 3 | 4 | 6 | 7 |

### 2.4 플레이어 경험

**첫도달 (1회성)**: 한 지역의 첫 목적지 클리어 순간 → Badge 획득 이펙트 + 이름 노출 + Steam Achievement / GPG Achievement / iOS Game Center Achievement 동기 등록. 같은 지역에서는 다시 발생하지 않음.

**마스터리 레벨업**: 완료마다 "이번 클리어로 레벨이 올랐는가"를 판정. 오른 경우에만 WinScreen에 `mastery_level_up` 배지 강조.

**M5 도달**: 지역 마스터리 보상 (칭호 + 누적 Credit + 코스메틱) 지급. 메타 보너스 시스템과 연동 (→ `docs/social_bm.md` §3.5).

### 2.5 디자인 의사결정

- **`exploration_difficulty` 필드는 현재 미사용**. 지역별 마스터리 무게를 차등 적용하는 아이디어는 있으나 V1에서는 보류 (단순성 우선).
- **마스터리 보상 V1 활성**: 칭호 + Credit + 코스메틱 (트레일 / 발사대). 영구 효과 / 파워 보너스는 부여하지 않음 (코어 밸런스 보호).

---

## 3. Program Lv. (TechLevel) — 해금 축 (2-3)

### 3.1 디자인 의도

**"게임 전체의 '레벨'. 플레이어의 전체 우주 발사 프로그램 누적 성장."**

단일 스칼라로 표현되는 단조증가 축. **목적지 해금 게이트**이자 **로컬 Best Records의 주 축**이자 **주간 미션의 보상 단위**.

### 3.2 GameState 필드

```gdscript
# scripts/autoload/game_state.gd
var tech_level: int = 0
```

플레이어 표시: **Program Lv.** / **Tech Level** (번역 키: `tr("STAT_TECH_LEVEL")`).

### 3.3 획득 경로

| 경로 | 기본 | 보정 | 의미 |
|---|---|---|---|
| 목적지 완료 | `reward_tech_level` (3~100) | × (1 + tech_reputation 0~50%) | 주 획득 경로 |
| 일일 미션 | 가변 | — | 일일 캡 50 |
| 주간 미션 | 가변 | — | 주간 캡 500 (비구독) / 750 (구독) |

### 3.4 기본 보상 스케일

| 티어 | reward_tech_level 범위 |
|---:|---:|
| 1 | 3~8 |
| 2 | 10~20 |
| 3 | 25~40 |
| 4 | 40~60 |
| 5 | 60~100 |

### 3.5 해금 게이트 — 수동/자동 동일 조건

```
목적지 선택 / 자동 진행 공통:
  GameState.tech_level >= destination.required_tech_level
```

미충족 시:
- **수동 선택**: "Need N Tech Level" 에러
- **자동 진행**: 현재 목적지에 머물러 반복

### 3.6 주요 디자인 주의점

1. **단조증가 (리셋/프레스티지 없음)**.
2. **highest_completed_tier와 독립**. TechLevel은 해금 축이고, highest_completed_tier는 확률 구간 축이다. 한쪽만 오르는 상황 가능 (T1 반복으로 TechLevel만 쌓기).
3. **주간 미션 캡**. 500(비구독) / 750(구독). 캡 초과 지급 차단.
4. **직접 판매 절대 금지**. "TechLevel 500 즉시 지급" 같은 IAP는 P2W 방어선이라 영원히 출시하지 않음.

---

## 4. Launch Tech — 세션형 5종 업그레이드 (2-4)

### 4.1 디자인 의도

**"이 목적지에서만 유효한 5개의 레버."**

XP를 지불해 구매하는 5종의 세션 업그레이드. 목적지 변경 시 **전부 리셋**되어 새 목적지에서 처음부터 투자하는 구조. 이 리셋이 있어서:

- **매 목적지에 "이 세션에서 얼마까지 올릴까" 전략 선택**이 생김.
- **영구 업그레이드(Facility)와 역할 분리** — 세션 성장이 영구 경제를 흐리지 않음.
- **XP 소비처 확보** — XP가 쌓이기만 하면 가치 하락.

### 4.2 5종 업그레이드 테이블

| tech_id | 이름 | 효과 | max_level | 레벨당 | 최대 효과 | cost_base / growth |
|---|---|---|---:|---|---|---|
| engine_precision | Engine Precision | 성공률 +x%p | 20 | +2%p | **+40%p** | 5 / 1.4 |
| telemetry | Telemetry | 기본 XP +x | 10 | +1 | **+10** | 6 / 1.4 |
| fuel_optimization | Fuel Optimization | XP 배율 | 10 | +5% | **×1.5** | 8 / 1.5 |
| auto_checklist | Auto-Checklist | 쿨다운 감소 / Auto rate | 10 | -5% | **-50%** | 7 / 1.4 |
| stress_bypass | Stress Bypass | 스트레스 누적 감소 | 10 | -3% | **-30%** | 10 / 1.5 |

### 4.3 비용 공식

```gdscript
func cost(current_level: int) -> int:
    return floor(cost_base * pow(cost_growth, current_level) + 0.5)
```

지수 증가. Engine Precision Lv.20까지 풀업하려면 약 5 × 1.4^19 ≈ 2,350 XP (최종 1레벨 비용만). 누적은 훨씬 더.

### 4.4 플레이어의 전략 선택

**목적지 초반 (XP 부족 시)**:
- `engine_precision` 우선 투자 (성공률 직접 기여)

**중반 (안정화)**:
- `fuel_optimization` + `telemetry` → XP 수급 가속

**T3+ 진입 시**:
- `stress_bypass` 추가 (T1/T2에서는 효과 0이므로 UI에서 가리거나 추천 플래그 필요)

**수동 연타 선호**:
- `auto_checklist` 먼저 (쿨다운 감소는 수동 발사에도 유효)

### 4.5 리셋 타이밍

목적지 변경 시 이 세션 전체가 사라진다:
- `select_destination` (수동 변경)
- `complete_destination` advanced 분기 (자동 진행)

**예외**: 같은 목적지 반복 클리어 시에는 리셋 안 됨 → TechLevel 부족으로 반복 플레이 시 세션 업그레이드가 자연스럽게 누적됨. 의도된 "파밍 루프".

### 4.6 디자인 주의점

- **Engine Precision만 max_level 20, 나머지 10**. 가장 중요한 축이 가장 깊게 투자 가능하도록.
- **5종 보너스 모두 타 서비스가 getter로 호출**. Launch Tech는 "버튼만 누르는 상점" 역할.

---

## 5. Facility Upgrades — 영구형 5종 업그레이드 (2-5)

### 5.1 디자인 의도

**"발사장(Facility) 자체를 영구히 업그레이드한다."**

Credit을 지불해 구매하는 5종의 영구 업그레이드. **리셋 없음**. 이 축이 흔들리면 "영구 투자로 세션 난이도가 사라지는" 밸런스 붕괴 위험이 있으므로, XP/Credit 지출처를 엄격히 분리.

### 5.2 5종 업그레이드 테이블

| upgrade_id | 이름 | 효과 | max_level | 레벨당 | 최대 효과 |
|---|---|---|---:|---|---|
| engine_tech | Engine Tech | 성공률 +x%p | 10 | +1%p | **+10%p** |
| data_collection | Data Collection | XP 획득량 | 20 | +10% | **+200% (3x)** |
| mission_reward | Mission Reward | Credit 획득량 | 20 | +5% | **+100% (2x)** |
| tech_reputation | Tech Reputation | TechLevel 획득량 | 10 | +5% | **+50%** |
| ai_navigation | AI Navigation | 오프라인 진행 효율 보정 | 10 | +2% | **+20%** |

### 5.3 비용 공식 — 모든 업그레이드 공통

```gdscript
const COST_BASE = 8
const COST_GROWTH = 1.20

func cost(next_level: int) -> int:
    return floor(COST_BASE * pow(COST_GROWTH, next_level - 1) + 0.5)
```

| level | Credit 비용 | 누적 |
|---:|---:|---:|
| 1 | 8 | 8 |
| 5 | 17 | 58 |
| 10 | 41 | 207 |
| 20 | 254 | 1,585 |

**전체 만렙까지 총 비용**: 약 3,791 Credit — T3 클리어 보상(50~110 C) 기준 수십 회 수준.

### 5.4 우선순위 가이드

모든 업그레이드가 같은 비용 곡선 → **효과 효율**이 우선순위 결정.

1. **`data_collection` 먼저**. XP 3배는 이후 모든 Launch Tech 투자를 가속.
2. **`mission_reward`**. Credit 2배는 이 축 자체를 가속.
3. **`tech_reputation`**. TechLevel 가속 → 해금 흐름 촉진.
4. **`engine_tech`**. 성공률 +10%p는 누적 효과가 크지만 Launch Tech `engine_precision`(+40%p)에 비해 작음.
5. **`ai_navigation`**. **오프라인 자동 발사 시뮬 효율**에 작용 — Auto Launch + Offline Progress 사용자에게 의미 있음.

### 5.5 디자인 주의점

- **Credit 경제 안전장치**. Credit Pack S/M/L IAP는 존재하지만 가격대($0.99~$9.99) + 노출 게이트(T2~T4)로 초기 경제 보호.
- **Facility는 단조 누적**. 한 번 산 업그레이드는 영원히 유지 — 재구매 / 다운그레이드 없음.

---

## 6. 성장 축 통합 — 한 번의 발사에서 일어나는 일

한 번의 발사에서 Progression 전체가 어떻게 교차하는지:

```
[발사 전]
  - 현재 목적지 = GameState.current_destination_id
  - 확률 = 구간 base + Launch Tech.engine_precision + Facility.engine_tech + IAP Guidance Module + (Surge 활성 시 +3%p)
  - XP 배수 = Launch Tech.fuel_optimization × (1 + Facility.data_collection) × IAP 배수 (VIP/Boost)
  - 스트레스 증가율 = base × (1 - Launch Tech.stress_bypass)

[스테이지 N 성공]
  - XP 가산 (위 공식)
  - 해당 XP로 Launch Tech 즉시 추가 구매 가능 (Upgrade 메뉴)

[목적지 완료]
  - Credit 가산 = reward_credit × (1 + Facility.mission_reward)
  - TechLevel 가산 = reward_tech_level × (1 + Facility.tech_reputation)
  - highest_completed_tier 갱신 → 다음 발사부터 아래 구간 상한 자동 적용
  - Region 첫도달 / Mastery 체크 → Steam/GPG/iOS Achievement 등록
  - 자동 진행 가능 여부는 TechLevel >= 다음 목적지 required_tech_level로 판정
  - advanced=true 시 Launch Tech / Stress 세션 리셋

[오프라인 복귀]
  - delta = current_unix - last_saved_unix (캡 8h)
  - simulated_launches = floor(delta * effective_rate × (1 + Facility.ai_navigation))
  - 결정적 시뮬 → Credit / XP 누적 → 모달 요약
```

---

## 7. 밸런스 튜닝 시트

**완전 풀업 플레이어의 성공률/보상 스케일 예시**:

| 티어 | 구간 base | 풀업 성공률 (구간 상한) | Credit 기본 | Credit 최대 배수 (×2) | TechLevel 기본 | TechLevel 최대 배수 (×1.5) |
|---:|---:|---:|---:|---:|---:|---:|
| T1 | 50% | 85% | 5~15 | 10~30 | 3~8 | 4.5~12 |
| T3 | 36% | 72% | 50~110 | 100~220 | 25~40 | 37.5~60 |
| T5 | 22% | 60% | 320~800 | 640~1,600 | 60~100 | 90~150 |

> 최대 배수 = (1 + Facility 만렙). Credit은 ×2, TechLevel은 ×1.5 상한.

---

## 8. 알려진 이슈 / 포팅 시 주의

1. **`ai_navigation` 효과 연결** — V1에서 오프라인 자동 발사 효율 +x%로 정의. 코드 구현 + 보너스 곡선 튜닝 필요.
2. **Region Mastery M5 코스메틱** — 트레일 / 발사대 디자인 작업 11종 필요.
3. **마일스톤 영상 트리거** — D_010 / D_025 / D_050 / D_075 / D_100 완료 시 `VideoStreamPlayer` 재생 + 5종 영상 작업.
4. **Daily/Weekly Mission TechLevel 캡** — 일일 50, 주간 500/750 (구독자) 게이트 검증 필요.
5. **목적지 반복 시 Launch Tech 누적**. advanced=false 분기에서 리셋 안 됨 → 의도된 "파밍 루프"이지만 밸런스 사이드 이펙트 관찰 필요.

---

## 9. 관련 원본 문서

- `docs/systems/2-1-destination.md`
- `docs/systems/2-2-region.md`
- `docs/systems/2-3-program-level.md`
- `docs/systems/2-4-launch-tech.md`
- `docs/systems/2-5-facility-upgrades.md`
- `docs/destination_config.md` (목적지 / 도감 / 뱃지 / 마스터리 구조)
- `docs/contents.md` (105 목적지 + 11 Zone 콘텐츠)
- `docs/prd.md` §11.2, §11.3 (Launch Tech / Facility 구조)
- `docs/game_term_alignment_review.md` §6.2 (용어 정렬)
