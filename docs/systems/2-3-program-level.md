# 2-3. Program Lv. — TechLevel 해금 축

> 카테고리: Progression
> 구현: `GameState.tech_level` (오토로드 영속 필드), 다수 시스템에서 참조

## 1. 시스템 개요

플레이어의 **전체 우주 발사 프로그램** 누적 성장을 표현하는 단일 스칼라 값. `reward_tech_level` 보상을 통해 증가하며, 목적지 해금(`required_tech_level`) 및 콘텐츠 잠금 해제 조건의 판정축.

**책임 경계**
- 모든 성장 보상의 도착 지점 (`DestinationService` 완료 보상).
- 목적지 해금 게이트 (`select_destination` 조건).
- 통계/프로필 화면의 핵심 지표.

**책임 아닌 것**
- Stage별 성공률(→ 1-2, `highest_completed_tier`가 소유)
- 세션 XP(→ 2-4 Launch Tech)
- Credit 경제(→ 3-1)

> **별도 서비스 파일 없음**. 이 시스템은 `GameState`의 필드와 다수 서비스의 참조 경로로 구성된 **가로지르는 개념 축**이다.

## 2. 코어 로직

### 2.1 용어

| 표시 | 코드 필드 | 용도 |
|---|---|---|
| **Program Lv.** / **Tech Level** | `GameState.tech_level: int` | 누적 성장 축 (단조증가) |

### 2.2 증가 경로 (`DestinationService.complete_destination`)

```gdscript
var tech_level_base: int = dest.reward_tech_level                            # 3~100 (티어별)
var tech_level_bonus: float = FacilityUpgradeService.get_tech_level_gain_bonus()
                                                                             # techReputation: +5%/Lv, max +50%
var tech_level_gain: int = roundi(tech_level_base * (1.0 + tech_level_bonus))
GameState.add_tech_level(tech_level_gain)
```

`GameState.add_tech_level(amount: int)`는 단조증가 보장 + `tech_level_changed(new_value: int)` 시그널 발행.

### 2.3 목적지별 기본 보상 스케일

| Tier | reward_tech_level 범위 | 대표 목적지 |
|---|---:|---|
| 1 | 3~8 | D_01~D_20 (NEAR_EARTH) |
| 2 | 10~20 | D_21~D_35 (MOON) |
| 3 | 25~40 | D_36~D_55 (MARS/VENUS/...) |
| 4 | 40~60 | D_56~D_75 (JUPITER/SATURN/...) |
| 5 | 60~100 | D_76~D_100 (PLUTO/INTERSTELLAR) |

### 2.4 해금 게이트 (`DestinationService.select_destination`)

```gdscript
if GameState.tech_level < dest.required_tech_level:
    return { success=false, message="Need %d Tech Level (have %d)" % [dest.required_tech_level, GameState.tech_level] }
```

자동 진행(`complete_destination` 종료부)도 동일 조건:
```gdscript
if GameState.tech_level >= next_dest.required_tech_level:
    GameState.current_target_id = next_destination_id    # 자동 진행
else:
    pass    # 현재 목적지 반복 유지 (TechLevel 파밍)
```

### 2.5 Mission 보상도 TechLevel로 지급 (→ 5-3)

데일리/위클리 미션 보상은 `reward_credit`이 아니라 `reward_tech_level`로 지급. 이는 TechLevel을 "장기 미션 화폐"로도 활용하는 구조.

```gdscript
# MissionService.claim_reward
var tech_level_gain: int = mission.reward_tech_level
GameState.add_tech_level(tech_level_gain)
# 단, weekly_tech_level 캡 (기본 500) 체크
```

## 3. 정적 데이터 (Config)

### 보상 소스 (분산)

| Config | 필드 | 역할 |
|---|---|---|
| `data/destination_config.tres` | `destinations[].reward_tech_level` | 목적지 완료 기본 보상 |
| `data/destination_config.tres` | `destinations[].required_tech_level` | 선택/자동진행 해금 조건 |
| `data/facility_upgrade_config.tres` | `upgrades.tech_reputation.bonus_per_level` | 완료 보상 배율 (+5%/Lv) |
| `data/mission_config.tres` | `missions[].reward_tech_level` | 미션 보상 소스 |

> Config 분산 구조: "TechLevel은 기능 아닌 **데이터 축**"이라 중앙 Config 없이 여러 시스템에 필드로 퍼져있음.

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

| 필드 | 타입 | 용도 |
|---|---|---|
| `tech_level` | `int` | **TechLevel 본체** (Program Lv.) |
| `mission_data.weekly_program_level` | `int` | 주간 미션으로 획득한 TechLevel (캡 체크용) |

> `tech_level`은 단조증가 (감소 경로 없음). 리셋도 없음.

## 5. 런타임 상태

없음. `GameState`에서 직접 조회.

## 6. 시그널 (EventBus / GameState)

| 시그널 | 인자 | 발행자 | 의미 |
|---|---|---|---|
| `tech_level_changed` | `(new_value: int)` | `GameState` | TechLevel이 변경됨 (UI 갱신용) |
| `destination_completed` | `(data: Dictionary)` | `DestinationService` | 페이로드에 `tech_level_gain`, `total_tech_level` 포함 |

## 7. 의존성

**영향을 주는 시스템**:
- `DestinationService` — 목적지 해금 + 자동 진행 판정
- `MissionService` — 주간 캡 체크 + 보상 지급
- UI — `DestinationPanel`, `MissionPanel`, `StatsPanel`

**읽는 곳 (getter)**: `DestinationService`, `MissionService`, 다수 UI Hook (`tech_level_changed` 구독).

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `scripts/autoload/game_state.gd` | `tech_level` 필드, `add_tech_level`, `tech_level_changed` 시그널 |
| `scripts/services/destination_service.gd` | 보상 계산/해금 판정 |
| `scripts/services/mission_service.gd` | 미션 보상 지급/주간 캡 |
| `data/destination_config.tres` | 목적지별 `reward_tech_level`/`required_tech_level` 튜닝 |
| `data/facility_upgrade_config.tres` | `tech_reputation` 보정 |
| `scripts/ui/destination_panel.gd` | TechLevel 표시 |

## 9. 알려진 이슈 / 설계 주의점

1. **리셋 없음**: `tech_level`은 단조증가. Prestige/Rebirth 개념은 본 게임 설계에서 명시적으로 제외.
2. **TechLevel과 `highest_completed_tier`의 분리**: 두 축은 독립이다.
   - TechLevel: 목적지 해금 + 미션 보상
   - `highest_completed_tier`: 확률 구간 상한
   - 한쪽만 올라가는 상황이 가능 (예: T1 반복으로 TechLevel은 쌓이지만 `highest_completed_tier=1` 고정).
3. **Mission Weekly Cap**: 주간 미션으로 얻을 수 있는 TechLevel은 `WEEKLY_TECH_LEVEL_CAP = 500`. 캡 초과 시 지급되지 않음 — 이 제한은 `MissionService`에서 적용.
4. **TechLevel 직접 판매 금지 (P2W 방어선)**: TechLevel은 IAP/스토어로 직접 판매 불가. 모든 획득은 게임플레이(목적지 완료, 미션) 경유. 이 원칙은 본 게임 BM 설계의 절대적 안전장치.
5. **단조 증가 가정**: 다수 UI/통계가 `tech_level`이 줄어들지 않음을 가정. 디버그 명령으로도 감소 경로를 만들지 말 것.
