# 1-1. LaunchSession — 메인 화면 발사 컨텍스트

> 카테고리: Launch Core
> 정본 문서: `docs/launch_balance_design.md`
> 구현: `scripts/services/launch_session_service.gd`

## 1. 시스템 개요

메인 화면에서 LAUNCH 탭 진입 시 "현재 발사 컨텍스트"를 구성·유지하는 서비스. 어떤 목적지를 어떤 Tier에서, 어떤 base modifier로 발사할지를 한곳에 모아 1-2 확률 엔진과 1-3 Auto Launch 루프에 제공한다.

**책임 경계**
- 현재 목적지(`current_destination_id`), 해당 Tier, base_modifiers 스냅샷 보관.
- 메인 화면 진입/이탈 시그널 발행 (`session_started` / `session_ended`).
- `LaunchService.launch_rocket()`의 **전제 조건** 게이트: 활성 컨텍스트가 없으면 발사 요청 거절.
- 컨텍스트 종료 시 `AutoLaunchService.stop_auto_launch()` 호출.

**책임 아닌 것**
- 확률 판정(→ 1-2), 스트레스 판정(→ 1-4), 카메라/연출(→ 4-1).
- 영속 저장 (컨텍스트는 메모리 휘발성 — 다음 실행 시 마지막 목적지로 자동 복원).

## 2. 코어 로직

### 2.1 컨텍스트 구성

메인 화면 `scenes/main/main_screen.tscn`이 활성화되면 `LaunchSessionService.start_session(destination_id)`를 호출. 서비스는 `DestinationService`에서 목적지 메타를 조회해 컨텍스트 객체를 구성한다.

```gdscript
class LaunchContext:
    var destination_id: StringName
    var tier: int
    var required_stages: int
    var base_modifiers: Dictionary  # { "xp_mult": 1.0, "credit_mult": 1.0, ... }
```

### 2.2 컨텍스트 상태 전이

```
[NONE]
  └─ start_session(destination_id)
       → _active_context = LaunchContext.new(...)
       → EventBus.launch_session_started.emit(destination_id, tier)
       ↓
[ACTIVE]
  ├─ LaunchService.launch_rocket()  ← 조건: is_session_active()
  ├─ AutoLaunchService 루프 (옵션)
  └─ 종료 트리거:
       - 사용자가 메인 화면 이탈 (씬 전환)
       - change_destination(new_id) → 컨텍스트 교체
       ↓
[ENDING]
  └─ end_session()
       → AutoLaunchService.stop_auto_launch()
       → _active_context = null
       → EventBus.launch_session_ended.emit()
       ↓
[NONE]
```

### 2.3 목적지 변경

플레이어가 다른 목적지로 전환 시 `change_destination(new_id)`는 기존 컨텍스트를 `end_session()`으로 정리한 뒤 새 컨텍스트로 `start_session(new_id)`을 호출한다. `sessionFlips` 카운터(→ 1-3)는 이 시점에 0으로 리셋된다.

### 2.4 공용 API

| 함수 | 반환 | 호출자 |
|---|---|---|
| `is_session_active()` | `bool` | `LaunchService.launch_rocket`, `AutoLaunchService.toggle_auto_launch`, `_start_auto_launch_loop` |
| `get_current_context()` | `LaunchContext` | `LaunchService`, UI 표시 |
| `get_current_destination_id()` | `StringName` | UI, `DestinationService` |

## 3. 정적 데이터 (Config)

**없음.** 이 서비스는 별도의 `.tres`를 읽지 않는다. 컨텍스트 구성은 `DestinationService`가 보유한 `data/destinations/*.tres`를 참조한다.

## 4. 플레이어 영속 데이터 (`user://savegame.json`)

| 필드 | 타입 | 용도 |
|---|---|---|
| `last_destination_id` | `String` | 다음 실행 시 자동으로 복원할 목적지. SaveSystem 로드 시 `start_session(last_destination_id)` 자동 호출. |

> 컨텍스트 자체는 저장하지 않는다 (실행마다 재구성). 마지막 목적지 ID만 저장해 사용자 의도를 보존한다.

## 5. 런타임 상태

| 필드 | 위치 | 타입 | 용도 |
|---|---|---|---|
| `_active_context` | `LaunchSessionService` (Autoload) | `LaunchContext` 또는 `null` | 현재 컨텍스트. `null`이면 발사 불가. |

## 6. 시그널 (EventBus)

| 시그널 | 페이로드 | 용도 |
|---|---|---|
| `EventBus.launch_session_started` | `(destination_id: StringName, tier: int)` | UI가 발사 패널/HUD를 활성화 |
| `EventBus.launch_session_ended` | `()` | UI가 발사 패널 비활성화, 카메라 복귀 |
| `EventBus.launch_destination_changed` | `(old_id: StringName, new_id: StringName)` | UI가 목적지 정보 갱신, Stress 게이지 표시 갱신 |

## 7. 의존성

**의존:**
- `DestinationService` — 목적지 메타 조회
- `AutoLaunchService` — 컨텍스트 종료 시 `stop_auto_launch` 호출
- `SaveSystem` — `last_destination_id` 로드/저장

**의존받음:**
- `LaunchService.launch_rocket` — `is_session_active()`로 발사 요청 게이트
- `AutoLaunchService.toggle_auto_launch`, `_start_auto_launch_loop` — 컨텍스트 유지 여부 확인

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/launch_session_service.gd` | 서비스 본체 (Autoload `LaunchSessionService`) |
| `scripts/autoload/event_bus.gd` | `launch_session_started` 등 시그널 정의 |
| `scenes/main/main_screen.tscn` | LAUNCH 탭, 목적지 선택 UI, `start_session` 호출 진입점 |
| `scripts/main/main_screen.gd` | 메인 화면 컨트롤러, `EventBus` 시그널 구독 |
| `scripts/services/launch_service.gd` | 발사 시 `is_session_active` 검사 |
| `project.godot` § `[autoload]` | `LaunchSessionService` 등록 |
