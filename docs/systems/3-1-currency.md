# 3-1. Currency — XP / Credit / TechLevel 3축 경제

> 카테고리: Economy
> 구현: `scripts/autoload/game_state.gd`(잔고 본체) + 각 기능 서비스가 증감 요청

## 1. 시스템 개요

Star Reach의 3종 플레이어 화폐를 **단일 오토로드 `GameState`로 관리**하는 축. 별도 서비스 노드는 두지 않고 `GameState`가 단일 진실의 원천(source of truth)이며, 각 기능 서비스(`launch_service.gd` / `destination_service.gd` / `facility_upgrade_service.gd` / `stress_service.gd` 등)가 메서드 호출로 증감을 요청한다.

**3화폐 체계**:

| 표시 이름 | 내부 필드 | 역할 | 획득 경로 | 소비 경로 |
|---|---|---|---|---|
| **XP** | `launch_tech_session.xp` | 세션 성장 (`Launch Tech` 구매) | 스테이지 성공 | Launch Tech 구매 |
| **Credit** | `credit` | 영구 성장 + 리스크 정산 | 목적지 완료 | Facility Upgrades 구매, Stress Repair Cost |
| **TechLevel** | `tech_level` | 해금 축 + 미션 보상 축 | 목적지 완료 + Mission | 직접 소비 없음 (read-only 게이트, 단조증가) |

**책임 경계**
- 3화폐의 잔고 저장/조회/증감.
- 지출 실패 판정(`spend_credit`은 부족 시 `false` 반환).
- 음수 잔고 방지 (`deduct_credit`은 0까지만 차감).

**책임 아닌 것**
- 증감 트리거 로직 (→ 각 기능 서비스가 호출).
- UI 포맷팅 (→ 8-4 UI Shell, `scripts/util/number_formatter.gd`).

## 2. 코어 로직

### 2.1 잔고 API 패턴

GDScript 타입 힌트 기반 일관 패턴:

```gdscript
# XP (세션형, launch_tech_session 하위) — LaunchTechService가 위임 호출
LaunchTechService.get_xp() -> int
LaunchTechService.add_xp(amount: int) -> int                      # newBalance
LaunchTechService.spend_xp(amount: int) -> Dictionary             # { ok: bool, balance: int }

# Credit — GameState 직접
GameState.get_credit() -> int
GameState.add_credit(amount: int) -> int                          # newBalance
GameState.spend_credit(amount: int) -> Dictionary                 # { ok: bool, balance: int }
GameState.deduct_credit(amount: int) -> Dictionary                # { balance: int, deducted: int }

# TechLevel — GameState 직접 (감소 API 없음)
GameState.get_tech_level() -> int
GameState.add_tech_level(amount: int) -> int                      # newBalance
```

### 2.2 증가 경로

| 화폐 | 증가 이벤트 | 배율 적용 |
|---|---|---|
| **XP** | 스테이지 1개 성공 (`launch_service.gd`) | `base(5) + telemetry + fuel_opt * data_collection * shop_xp_mult * party_bonus` |
| **Credit** | 목적지 완료 (`destination_service.gd`) | `reward_credit * (1 + mission_reward_bonus)` |
| **TechLevel** | 목적지 완료 + Mission 클레임 | `reward_tech_level * (1 + tech_reputation_bonus)` (목적지) / Mission은 가산 (캡 500/주) |

### 2.3 감소 경로

| 화폐 | 감소 이벤트 | 방식 |
|---|---|---|
| **XP** | Launch Tech 구매 | `spend_xp` (부족 시 실패) |
| **Credit** | Facility Upgrade 구매 | `spend_credit` (부족 시 실패) |
| **Credit** | Stress Abort Repair Cost | `deduct_credit` (부족 시 가진 만큼만) |
| **TechLevel** | **없음** (단조증가) | — |

### 2.4 `spend_credit` vs `deduct_credit` 구분

- **`spend_credit(amount)`**: 검증 후 차감. 잔고 < amount 이면 `{ ok = false }` 반환, 상태 불변. 자발적 구매 액션 전용.
- **`deduct_credit(amount)`**: 강제 차감. 잔고 부족 시 가진 만큼만 차감하고 실제 차감된 값을 반환. **Stress Abort 벌금 전용** (가난한 플레이어도 Abort 페널티가 적용되어야 하므로).

### 2.5 3화폐 역할 분리 원칙

```
XP        → 세션 내부에서만 순환 (목적지 변경 시 리셋)
Credit    → 영구 성장 + Stress 리스크 정산
TechLevel → 해금 축 + 미션 장기 축 (직접 판매 금지)
```

**금지된 교환 경로**:
- XP → Credit 변환 없음
- Credit → TechLevel 변환 없음
- **TechLevel 직접 판매 IAP 금지** (BM 무결성)

이 경계가 무너지면 IAP 상품 가치가 가려지거나 장기 성장이 과금에 밀릴 수 있음.

### 2.6 UI 노출 규칙

| 화폐 | 노출 위치 | 업데이트 트리거 (EventBus signal) |
|---|---|---|
| XP | `launch_tech_panel.tscn` | `xp_changed`, `launch_stage_resolved` |
| Credit | `global_hud.tscn` 상단, `facility_upgrade_panel.tscn` | `credit_changed`, `destination_completed` |
| TechLevel | `global_hud.tscn` 상단, `destination_panel.tscn`, `mission_panel.tscn` | `tech_level_changed`, `destination_completed`, `mission_claimed` |

(→ 8-4 `GameState`가 시그널 발행, UI는 구독만)

## 3. 정적 데이터 — `data/*.tres`

화폐 정의 자체는 코드 상수. 튜닝 값은 각 기능 Resource로 분리:

| 리소스 | 필드 |
|---|---|
| `data/launch_tech.tres` | `xp_base_gain` |
| `data/destinations/*.tres` | `reward_credit`, `reward_tech_level` |
| `data/facility_upgrades.tres` | `cost_base`, `cost_growth` (Credit 비용 곡선) |
| `data/missions/*.tres` | `reward_tech_level` |
| `data/stress.tres` | `repair_cost` (Credit 차감) |

> 모든 곡선은 `base * pow(growth, level)` 기본형. `Curve` 리소스로 대체 가능.

## 4. 플레이어 영속 데이터 — `user://savegame.json`

3화폐 관련 필드:

```json
{
  "version": 1,
  "credit": 0,
  "tech_level": 0,
  "launch_tech_session": {
    "xp": 0,
    "engine_precision_level": 0
  },
  "mission_data": {
    "weekly_program_level": 0
  }
}
```

> **XP는 세션 리셋 대상**. 목적지 변경 시 `LaunchTechService.reset_session()` → `launch_tech_session` 전체가 DEFAULT로 돌아감 → XP도 0.

저장은 `GameState`의 자동 저장 루프(10s 주기) + `NOTIFICATION_WM_CLOSE_REQUEST` + 수동 저장 버튼에서 트리거.

## 5. 런타임 상태

없음. `GameState` 필드를 직접 조회.

## 6. 시그널 (EventBus)

3화폐 변동은 `EventBus` 오토로드의 시그널로 broadcast. UI는 이 시그널만 구독.

| 시그널 | 페이로드 | 발행 시점 |
|---|---|---|
| `xp_changed(new_balance: int, delta: int)` | balance, delta | `add_xp` / `spend_xp` 직후 |
| `credit_changed(new_balance: int, delta: int)` | balance, delta | `add_credit` / `spend_credit` / `deduct_credit` 직후 |
| `tech_level_changed(new_balance: int, delta: int)` | balance, delta | `add_tech_level` 직후 |
| `launch_stage_resolved(stage_passed: bool, xp_gain: int, xp_balance: int)` | — | 스테이지 결과 처리 시 |
| `destination_completed(payload: Dictionary)` | `credit_gain`, `credit_balance`, `tech_level_gain`, `tech_level_total`, ... | 목적지 완료 파이프라인 종료 시 (→ 3-2) |
| `stress_aborted(credit_balance: int)` | balance after deduction | Abort 처리 후 |

> 노드 간 직접 참조 체인을 만들지 않기 위해 모든 화폐 변동은 EventBus로만 전파.

## 7. 의존성

**증가 호출 측**: `launch_service.gd`, `destination_service.gd`, `mission_service.gd`
**감소 호출 측**: `launch_tech_service.gd`, `facility_upgrade_service.gd`, `stress_service.gd`, `shop_service.gd`(IAP 영수증 후)
**조회 측**: 모든 UI 패널 (EventBus 시그널 구독으로 lazy 갱신)

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/autoload/game_state.gd` | 3화폐 본체 + `get/add/spend/deduct_credit`, `get/add_tech_level`, `get/reset_launch_tech_session` |
| `scripts/autoload/event_bus.gd` | `xp_changed` / `credit_changed` / `tech_level_changed` 시그널 정의 |
| `scripts/services/launch_tech_service.gd` | `get_xp` / `add_xp` / `spend_xp` (세션 하위 위임) |
| `scripts/services/save_system.gd` | `savegame.json` 직렬화/역직렬화, 스키마 마이그레이션 훅 |
| `scripts/util/number_formatter.gd` | UI 표시용 SI/과학 표기 포맷터 |
