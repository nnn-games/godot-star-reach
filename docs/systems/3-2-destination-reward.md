# 3-2. Destination Reward — 목적지 완료 보상 파이프라인

> 카테고리: Economy
> 구현: `scripts/services/destination_service.gd::complete_destination()`

## 1. 시스템 개요

목적지 완료 이벤트에서 **Facility Upgrade 보정을 합산해 Credit과 TechLevel을 지급**하는 보상 계산 파이프라인. `destination_service.gd` 내부의 `complete_destination()` 단일 함수가 보상 계산 + 부수 효과(완료 마킹 / 자동 진행 / 도감 / 뱃지 / 텔레메트리)를 모두 처리한다.

**책임 경계**
- `reward_credit` / `reward_tech_level` → 최종 지급량 계산.
- `Facility Upgrades` 보정 적용 (`mission_reward` +5%/Lv 최대 +100%, `tech_reputation` +5%/Lv 최대 +50%).
- 지급 후 `GameState` 잔고 갱신 + 도감/뱃지 체크.

**책임 아닌 것**
- XP 지급 (→ 1-2 `launch_service.gd` 스테이지별 실시간).
- Credit 잔고 소유 (→ 3-1 `GameState`), Credit 차감 경로 (→ 1-4 Stress, 2-5 Facility, 7 Shop).
- Mission 보상 (→ 5-3, 별도 경로로 `add_tech_level` 호출).

## 2. 코어 로직

### 2.1 보상 공식

```gdscript
# Credit
var credit_base: int = destination.reward_credit
var credit_bonus: float = FacilityUpgradeService.get_credit_gain_bonus()
    # = facility_levels.mission_reward * 0.05   # max +1.00 at Lv.20
var credit_gain: int = roundi(credit_base * (1.0 + credit_bonus))
GameState.add_credit(credit_gain)

# TechLevel
var tech_base: int = destination.reward_tech_level
var tech_bonus: float = FacilityUpgradeService.get_tech_level_gain_bonus()
    # = facility_levels.tech_reputation * 0.05  # max +0.50 at Lv.10
var tech_gain: int = roundi(tech_base * (1.0 + tech_bonus))
var total_tech_level: int = GameState.add_tech_level(tech_gain)
```

> 모든 보너스는 개인 영속 데이터(`facility_levels`) + 시간제 IAP 부스터에서만 결정된다.

### 2.2 보상 스케일 예시

**기본 보상 (보정 없음)**:

| Tier | Credit 범위 | TechLevel 범위 |
|---|---:|---:|
| 1 | 5~15 | 3~8 |
| 2 | 18~45 | 10~20 |
| 3 | 50~110 | 25~40 |
| 4 | 130~280 | 40~60 |
| 5 | 320~800 | 60~100 |

**최대 보정 (Facility 만렙)**:

| Tier | Credit (×2.0) | TechLevel (×1.5) |
|---|---:|---:|
| 1 | 10 ~ 30 | 4.5 ~ 12 |
| 5 | 640 ~ 1,600 | 90 ~ 150 |

> 최대 배수 = `(1 + 1.0) = 2.0x` Credit, `(1 + 0.5) = 1.5x` TechLevel.

### 2.3 전체 보상 파이프라인 순서 (`complete_destination`)

```
1. 보상 계산 (위 §2.1)
2. GameState.add_credit(credit_gain)
   GameState.add_tech_level(tech_gain)
3. GameState.increment_wins() -> total_wins
4. GameState.set_highest_completed_tier(max(current, destination.tier))
   └─ 사이드 이펙트: 다음 발사부터 해당 티어 이하 스테이지 상한 자동 적용 (→ 1-2)
5. GameState.mark_destination_completed(destination.id)
   └─ Region Mastery 계산에 영향 (→ 2-2)

6. Region 첫도달 체크 → BadgeService → region_first_arrival_badge
7. Region Mastery 레벨업 체크 → mastery_level_up
8. BadgeService.check_and_award("win")
9. DiscoveryService.on_destination_complete() → discovery_change

10. 자동 진행 판정 (TechLevel 충족 시 current_target_id 변경)
11. advanced == true → LaunchTechService.reset_session() + StressService.reset_session()

12. TelemetryService.log_event("destination_complete", {...})
13. EventBus.destination_completed.emit(payload)   ← 최종 fan-out
```

> 보상 지급은 메타 이벤트 발행 이전에 완료. 이 순서 덕분에 Badge/Discovery 체크 시 이미 `tech_level`, `completed_destinations`가 갱신된 상태.

### 2.4 타 시스템과의 관계

| 시스템 | 이 파이프라인에 영향 주는 방식 |
|---|---|
| `facility_upgrade_service.gd` (2-5) | `mission_reward`, `tech_reputation` 레벨 → 보상 배율 |
| `game_state.gd` (3-1) | 지급 대상 (Credit/TechLevel 잔고) |
| `badge_service.gd` (5-2) | Win 카운트 뱃지 + Region 첫도달 뱃지 |
| `discovery_service.gd` (5-1) | 도감 엔트리/섹션/완성 업데이트 |

이 함수는 **게임의 가장 중요한 fan-out 지점**. `destination_completed` 시그널 페이로드가 가장 큰 이유.

## 3. 정적 데이터 — `data/*.tres`

| 리소스 | 필드 |
|---|---|
| `data/destinations/*.tres` | `reward_credit`, `reward_tech_level`, `tier`, `region_id`, `required_tech_level` |
| `data/facility_upgrades.tres` | `mission_reward.bonus_per_level` (= 0.05), `tech_reputation.bonus_per_level` (= 0.05) |

> 목적지마다 1개의 `.tres`로 분리하면 데이터 추가/제거가 git diff에서 깔끔.

## 4. 플레이어 영속 데이터 — `user://savegame.json`

이 파이프라인이 쓰는 필드:

```json
{
  "version": 1,
  "credit": 0,
  "tech_level": 0,
  "total_wins": 0,
  "highest_completed_tier": 0,
  "completed_destinations": {},
  "visited_regions": {},
  "current_target_id": ""
}
```

| 필드 | 기여 방식 |
|---|---|
| `credit` | `add_credit(credit_gain)` |
| `tech_level` | `add_tech_level(tech_gain)` |
| `total_wins` | `increment_wins()` |
| `highest_completed_tier` | `set_highest_completed_tier(max)` |
| `completed_destinations` | `mark_destination_completed(id)` |
| `visited_regions` | (첫도달 시) `mark_region_visited(region_id)` |
| `current_target_id` | (자동 진행 시) `set_current_target_id(next_id)` |

## 5. 런타임 상태

없음. 모든 상태는 `GameState`(영속) + 인자로 받은 `Destination` 리소스로 충분.

## 6. 시그널 (EventBus)

| 시그널 | 페이로드 |
|---|---|
| `destination_completed(data: Dictionary)` | `{ total_launches, total_wins, credit_gain, credit_balance, tech_level_gain, tech_level_total, destination_id, destination_name, tier, next_destination_id, region_first_arrival_badge?, mastery_level_up?, discovery_change_type?, discovery_entry_name?, discovery_new_sections?, discovery_progress? }` |

이 파이프라인의 **단일 출력 채널**. 모든 사이드 이펙트 결과를 이 하나의 시그널에 담아 broadcast → `WinScreen`/`HUD`/`MissionPanel` 등이 구독.

## 7. 의존성

**이 파이프라인이 호출**:
- `FacilityUpgradeService.get_credit_gain_bonus()` / `get_tech_level_gain_bonus()`
- `GameState.add_credit` / `add_tech_level` / `increment_wins` / `set_highest_completed_tier` / `mark_destination_completed` / `mark_region_visited` / `set_current_target_id`
- `BadgeService.check_and_award`
- `DiscoveryService.on_destination_complete`
- `LaunchTechService.reset_session` / `StressService.reset_session`
- `RegionConfig.get_region`, `RegionMasteryConfig.compute_mastery`

**호출 시점**:
- `launch_service.gd::launch_rocket()` 승리 분기에서 1회 호출

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/destination_service.gd` | 보상 계산 파이프라인 전체 |
| `scripts/services/facility_upgrade_service.gd` | `mission_reward` / `tech_reputation` 보정 게터 |
| `data/destinations/*.tres` | 목적지별 base 보상 |
| `data/facility_upgrades.tres` | bonus_per_level 곡선 |
| `scenes/ui/win_screen.tscn` | `destination_completed` 시그널 수신 → 보상/뱃지/마스터리 표시 |
