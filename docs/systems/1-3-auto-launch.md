# 1-3. Auto Launch — 자동 발사 루프

> 카테고리: Launch Core
> 정본 문서: `docs/launch_balance_design.md`, `docs/monetization_plan.md`
> 구현: `scripts/services/auto_launch_service.gd`

## 1. 시스템 개요

LAUNCH 컨텍스트가 활성화된 상태에서 토글을 켜면 일정 간격으로 `LaunchService.launch_rocket()`을 자동 호출하는 루프. 쿨다운 기반 수동 발사와 달리 **`rate (launches/sec)` 기반 간격 제어**.

**책임 경계**
- 자동 발사 해금 판정 (T1 첫 클리어 또는 누적 10회 발사).
- 루프 `rate` 계산 (Auto Launch Pass IAP, Auto Fuel, Auto-Checklist).
- 수동 발사 쿨다운 계산 (`get_launch_cooldown`) — 이 서비스가 **수동 발사 쿨다운도 소유**.
- 발사 카운터(`session_flips`, `total_launches`) 증감.

**책임 아닌 것**
- 실제 확률 판정(→ 1-2), 컨텍스트 검증(→ 1-1).
- IAP 효과 판정(→ 7-1/7-2, IAPService).

## 2. 코어 로직

### 2.1 해금 판정 (`is_auto_launch_unlocked`)

다음 중 하나라도 만족하면 해금:
1. `GameState.highest_completed_tier >= 1` — T1 첫 클리어
2. `GameState.total_launches >= 10` — 누적 10회 발사 (`LaunchConstants.AUTO_LAUNCH_UNLOCK_LAUNCHES`)

해금되면 무료 사용 (1.0 launches/s 기본). IAP `Auto Launch Pass` 구매 시 +0.35 launches/s.

### 2.2 Rate 계산 (`get_auto_launch_rate`)

```gdscript
func get_auto_launch_rate() -> float:
    if not is_auto_launch_unlocked():
        return 0.0

    var rate: float = 1.0                                                # 기본 1.0 launches/s
    if IAPService.has_auto_launch_pass():       rate += 0.35             # LAUNCH_AUTO_PASS_BONUS
    if IAPService.has_active_auto_fuel():       rate += 0.50             # AUTO_FUEL_RATE_BONUS

    # 배수 보정
    var auto_checklist_reduction: float = LaunchTechService.get_auto_checklist_reduction()  # 0~0.5
    rate = rate / max(1.0 - auto_checklist_reduction, 0.5)

    return min(rate, MAX_AUTO_LAUNCH_RATE)                               # cap 2.5
```

최대 도달 가능 rate (조건 만점):
- `(1.0 + 0.35 + 0.50) / 0.5 = 3.7 launches/s` → **cap 2.5로 제한**.
- 실용상 대부분의 조합이 cap에 금방 도달함.

### 2.3 수동 발사 쿨다운 (`get_launch_cooldown`)

```gdscript
func get_launch_cooldown() -> float:
    var auto_checklist_reduction: float = LaunchTechService.get_auto_checklist_reduction()
    var cooldown: float = BASE_COOLDOWN * (1.0 - auto_checklist_reduction)
    return max(MIN_COOLDOWN, cooldown)
```

- Auto-Checklist 만렙(50% 감소) 조합 시 `3.0 * 0.5 = 1.5s`.

### 2.4 토글 (`toggle_auto_launch`)

```
조건 검사:
  1. LaunchSessionService.is_session_active()
     └─ false → { success = false, message = "No active launch context" }
  2. is_auto_launch_unlocked()
     └─ false → { success = false, message = "Complete T1 or launch N more times" }
  3. get_auto_launch_rate() > 0
     └─ false → { success = false, message = "No auto-launch available" }

토글 실행:
  var new_enabled: bool = not GameState.auto_launch_enabled
  GameState.auto_launch_enabled = new_enabled
  if new_enabled: _start_auto_launch_loop()
  else:           stop_auto_launch()

반환: { success, auto_launch_enabled, auto_launch_rate }
```

### 2.5 루프 (`_start_auto_launch_loop`)

```gdscript
func _start_auto_launch_loop() -> void:
    _loop_running = true
    while _loop_running:
        if not GameState.auto_launch_enabled: break
        var rate: float = get_auto_launch_rate()
        if rate <= 0.0: break
        if not LaunchSessionService.is_session_active():
            GameState.auto_launch_enabled = false
            break

        await get_tree().create_timer(1.0 / rate).timeout

        # 재검사 (await 중 상태 변경 가능)
        if not GameState.auto_launch_enabled: break
        if not LaunchSessionService.is_session_active(): break

        var result: Dictionary = await LaunchService.launch_rocket()
        EventBus.auto_launch_result.emit(result)
    _loop_running = false
```

**중단 조건:**
1. 사용자가 수동 토글 OFF
2. LAUNCH 컨텍스트 종료 (씬 이탈/목적지 변경)
3. 목적지 클리어 (`LaunchService`가 승리 분기에서 `stop_auto_launch` 호출)
4. Stress Abort (`LaunchService`가 Abort 분기에서 `stop_auto_launch` 호출)

### 2.6 카운터 증감 (`increment_launches`)

```gdscript
func increment_launches(amount: int) -> int:
    GameState.session_flips += amount   # 세션 내 발사 수 (목적지 변경 시 0)
    GameState.total_launches += amount  # 평생 누적 (자연 해금 추적, 영속)
    return GameState.session_flips
```

## 3. 정적 데이터 (Config)

### `data/launch_constants.tres`

```gdscript
@export var base_cooldown: float = 3.0
@export var min_cooldown: float = 0.5
@export var max_auto_launch_rate: float = 2.5
@export var auto_launch_unlock_launches: int = 10
@export var launch_auto_pass_bonus: float = 0.35
```

### `data/iap_config.tres`

```gdscript
@export var auto_fuel_rate_bonus: float = 0.5
```

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

| 필드 | 타입 | 용도 |
|---|---|---|
| `auto_launch_enabled` | `bool` | 다음 실행 시 자동 재시작 기준 |
| `session_flips` | `int` | 세션 내 발사 수 (목적지 변경 시 리셋) |
| `total_launches` | `int` | 평생 누적 발사 (자연 해금 조건) |

## 5. 런타임 상태

| 필드 | 위치 | 타입 | 용도 |
|---|---|---|---|
| `_loop_running` | `AutoLaunchService` | `bool` | 자동 발사 루프 활성 플래그 (await 안에서 break 처리) |

## 6. 시그널 (EventBus)

| 시그널 | 방향 | 페이로드 | 용도 |
|---|---|---|---|
| `EventBus.auto_launch_toggle_requested` | UI → Service | `()` | 메인 화면 AUTO 버튼 → 서비스 호출 |
| `EventBus.auto_launch_state_changed` | Service → UI | `(enabled: bool, rate: float, message: String)` | 토글 결과 |
| `EventBus.auto_launch_result` | Service → UI | `(result: Dictionary)` | 자동 발사 루프 한 사이클 결과 |

## 7. 의존성

**의존:** `GameState`, `IAPService`, `LaunchTechService`, `LaunchService`, `LaunchSessionService`.

**순환 의존성 주의:**
- `LaunchService` → `AutoLaunchService` (`stop_auto_launch` 호출)
- `AutoLaunchService` → `LaunchService` (`launch_rocket` 호출)
- 둘 다 Autoload로 등록되어 `_ready()`에서 서로 참조 가능. 직접 참조 대신 `EventBus` 시그널 경유를 권장하나, 결과 반환값을 사용해야 하는 경우 직접 호출.

**의존받음:**
- `LaunchService` — 승리 분기, Abort 분기에서 `stop_auto_launch` 호출.
- `LaunchSessionService.end_session` — 컨텍스트 종료 시 `stop_auto_launch` 호출.
- `scripts/main/main_screen.gd` — 토글 버튼, 수동 발사 쿨다운 게이트.

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `scripts/services/auto_launch_service.gd` | 루프 로직, 해금 조건, rate 공식 |
| `data/launch_constants.tres` | 쿨다운/rate/보너스 수치 |
| `scripts/main/main_screen.gd` | AUTO 버튼, 상태 표시, 수동 발사 쿨다운 게이트 |
| `scenes/main/main_screen.tscn` | AUTO 토글 버튼 UI |
| `scripts/autoload/event_bus.gd` | Auto Launch 관련 시그널 정의 |
