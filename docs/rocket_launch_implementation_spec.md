# Star Reach 발사 시스템 구현 사양 (Godot 4.6)

> 대상: 2D 우주 발사 증분 시뮬레이터 StarReach
> 엔진: Godot 4.6 / GDScript
> 플랫폼: Android, iOS, PC Steam (싱글 오프라인)
> 관련 문서: `docs/launch_balance_design.md`, `docs/rocket_launch_content_preparation.md`, `docs/launch_sky_transition_plan.md`

## 1. 시스템 개요

발사 시스템은 메인 화면에서 LAUNCH 버튼을 눌렀을 때 시작되어, N단계 확률 판정과 단계별 상승 연출을 거쳐 목적지 도달 또는 실패로 종결되는 단일 클라이언트 루프다. 모든 로직과 연출은 단일 프로세스 안에서 동작하며 네트워크 동기화는 존재하지 않는다.

### 1.1 책임 분담

| 모듈 | 책임 |
|---|---|
| `LaunchSessionService` (Autoload) | 발사 세션의 상태(idle / arming / launching / settling) 관리, 동시 발사 방지, 자동 저장 일시 정지 토글 |
| `LaunchService` (Autoload) | 단일 발사 트랜잭션 실행: 단계별 확률 굴림, 결과 적용, EventBus 시그널 송출, 목적지 완료 판정 |
| `MainSceneController` (메인 씬 루트 스크립트) | 메인 화면에서 LAUNCH 입력 수신, RocketView/StageIndicator/VFXLayer/SkyLayer 노드 오케스트레이션 |
| `RocketView` (Sprite2D + AnimationPlayer) | 단계별 상승 트윈, 흔들림, 성공/실패 분기 애니메이션 |
| `SkyProfileApplier` | 단계 통과 시점에 다음 sky profile 보간 적용 |
| `DestinationService` (Autoload) | 발사 완료 시 보상 지급, 다음 목적지 진입 처리 |
| `AutoLaunchService` (Autoload) | 해금 시 자동 발사 틱 |
| `EventBus` (Autoload) | 모든 시스템 간 결합을 끊는 시그널 허브 |

### 1.2 기본 원칙

- 발사 판정은 `LaunchService`가 단독으로 수행한다. UI/VFX/Audio는 EventBus 시그널을 구독해 반응만 한다.
- 발사 도중 자동 저장은 일시 정지된다. 발사가 idle로 돌아온 직후 1회 저장된다.
- 발사 진행 중 두 번째 `start_launch()` 호출은 거부된다(중복 트랜잭션 방지).
- 메인 화면이 곧 발사 화면 — 진입 의식 없이 즉시 LAUNCH 가능.

## 2. 씬 구조

`scenes/main/main_screen.tscn`이 발사 시스템의 진입 씬이다. 메인 화면이 곧 발사 화면이며, 별도의 모드 전환은 없다.

```text
MainScreen (Node2D)                              [main_scene_controller.gd]
├─ Camera2D                                       (zoom 1.0 기본, shake 헬퍼 부착)
├─ WorldLayer (Node2D)                            (월드 좌표 그룹)
│  ├─ SkyLayer (CanvasLayer, layer = -10)        [sky_profile_applier.gd]
│  │  ├─ SkyBackground (Sprite2D, fill)           (현재 profile 텍스처)
│  │  └─ SkyBackgroundNext (Sprite2D, alpha 0)    (cross-fade 타깃)
│  ├─ LaunchPad (Sprite2D)                        (정적 발사대)
│  └─ RocketView (Node2D)                         [rocket_view.gd]
│     ├─ RocketSprite (Sprite2D)
│     ├─ EngineFlameParticles (GPUParticles2D)
│     └─ AnimationPlayer
├─ VFXLayer (CanvasLayer, layer = 5)              [vfx_layer.gd]
│  ├─ ScreenFlash (ColorRect, modulate alpha 0)
│  └─ StageBurstParticles (GPUParticles2D)
└─ UILayer (CanvasLayer, layer = 10)              [ui_layer.gd]
   ├─ TopBar (Control)                            (목적지명, tier, stage 수, 성공률)
   ├─ StageIndicator (HBoxContainer)              [stage_indicator.gd]
   ├─ LogPanel (Control)
   ├─ LaunchButton (Button)
   ├─ AutoLaunchToggle (Button)
   ├─ TechPanel (Control)
   └─ ResultOverlay (Control, visible = false)
```

발사 전용 서브씬은 `scenes/launch/rocket_view.tscn` 하나만 존재한다. 메인 씬은 항상 RocketView를 자식으로 보유하고, 발사 트리거에 따라 그 내부 애니메이션만 갱신한다.

## 3. 데이터 흐름

```
[User Input: LaunchButton.pressed]
        │
        ▼
[MainSceneController._on_launch_pressed()]
        │
        ▼
[LaunchService.start_launch()]
        │ ─── 거부 시 EventBus.launch_rejected
        ▼
[EventBus.launch_started(total_stages, stage_duration, destination_tier, sky_route)]
        │
        ├──► [RocketView] : engine ignite, ascent loop 준비
        ├──► [SkyProfileApplier] : route 0번 profile 즉시 적용, 다음 profile 프리로드
        ├──► [VFXLayer] : 시작 플래시
        ├──► [Camera2D] : zoom 1.0 → 1.05 (50ms)
        └──► [UILayer] : 버튼 비활성화, StageIndicator 초기화
        │
        ▼
[stage loop: i = 0 .. total_stages - 1]
   │
   ├─ await LaunchService._judge_stage(i)        (0.3s)
   │   └─ 결과 = (success: bool)
   │
   ├─ await LaunchService._apply_stage_result(i, success)
   │     │
   │     ├─ success: EventBus.stage_succeeded(i, total_stages, sky_route)
   │     │     ├──► RocketView : 단계 상승 트윈 (1.4s)
   │     │     ├──► SkyProfileApplier : 다음 profile 미세 보간
   │     │     ├──► Camera2D : 짧은 펄스 zoom (1.05 → 1.07 → 1.05)
   │     │     ├──► StageIndicator : i번째 칸 ON
   │     │     └──► XP/통계 누적
   │     │
   │     └─ fail: EventBus.stage_failed(i, total_stages)
   │           ├──► RocketView : 흔들림 + 정지
   │           ├──► VFXLayer : 실패 플래시
   │           ├──► Camera2D : 강한 shake (0.3s)
   │           ├──► T3+ 목적지: StressService.apply_failure(i)
   │           └──► loop break
   │
   ▼
[모든 stage success]
        │
        ▼
[EventBus.launch_completed(destination_id, rewards)]
        ├──► DestinationService.grant_rewards()
        ├──► SkyProfileApplier : 마지막 profile fade-in
        ├──► UILayer : ResultOverlay 표시 (settling 상태)
        └──► (선택) cutscene 재생

[stage_failed 또는 launch_completed 후]
        ▼
[LaunchSessionService.set_state(SETTLING)]
        │ ── 0.5s 결과 hold
        ▼
[LaunchSessionService.set_state(IDLE)]
        ├──► EventBus.launch_ready
        ├──► SaveSystem.save_now()
        ├──► UILayer : LaunchButton 활성화
        └──► AutoLaunchService.tick(delta) 재개
```

## 4. LaunchService API

`scripts/services/launch_service.gd` (Autoload)

### 4.1 시그니처

```gdscript
class_name LaunchService
extends Node

const STAGE_JUDGE_DURATION: float = 0.3
const STAGE_ASCENT_DURATION: float = 1.4
const STAGE_RESULT_HOLD: float = 0.3
const STAGE_TOTAL_DURATION: float = 2.0  # 0.3 + 1.4 + 0.3

var _is_launching: bool = false
var _current_destination: DestinationData = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
    _rng.randomize()


func start_launch() -> bool:
    # 반환: 발사 시작 성공 여부. 거부 시 false.
    pass


func _judge_stage(stage_index: int) -> bool:
    # 단계별 성공 확률을 굴려 결과를 반환.
    pass


func _apply_stage_result(stage_index: int, success: bool) -> void:
    # 결과를 EventBus로 통지하고 단계 연출 시간만큼 await.
    pass


func _on_all_stages_succeeded() -> void:
    # 보상 산출 → DestinationService 호출 → launch_completed 송출.
    pass


func _on_stage_failed(failed_index: int) -> void:
    # 실패 통지 + (T3+) 스트레스 누적.
    pass
```

### 4.2 의사 구현

```gdscript
func start_launch() -> bool:
    if _is_launching:
        EventBus.launch_rejected.emit("already_launching")
        return false

    var destination: DestinationData = DestinationService.get_current()
    if destination == null:
        EventBus.launch_rejected.emit("no_destination")
        return false

    _is_launching = true
    _current_destination = destination
    LaunchSessionService.set_state(LaunchSessionService.State.LAUNCHING)
    SaveSystem.pause_autosave()

    EventBus.launch_started.emit(
        destination.required_stages,
        STAGE_TOTAL_DURATION,
        destination.tier,
        destination.sky_route_key
    )

    for i in destination.required_stages:
        await get_tree().create_timer(STAGE_JUDGE_DURATION).timeout
        var success: bool = _judge_stage(i)
        await _apply_stage_result(i, success)
        if not success:
            _on_stage_failed(i)
            _finalize_launch()
            return true

    _on_all_stages_succeeded()
    _finalize_launch()
    return true


func _judge_stage(stage_index: int) -> bool:
    var probability: float = LaunchBalance.get_stage_success_chance(
        _current_destination.tier,
        stage_index,
        UpgradeService.get_level("reliability")
    )
    return _rng.randf() < probability


func _apply_stage_result(stage_index: int, success: bool) -> void:
    if success:
        EventBus.stage_succeeded.emit(
            stage_index,
            _current_destination.required_stages,
            _current_destination.sky_route_key
        )
        StatsService.add_xp(LaunchBalance.get_stage_xp(stage_index))
        await get_tree().create_timer(STAGE_ASCENT_DURATION + STAGE_RESULT_HOLD).timeout
    else:
        EventBus.stage_failed.emit(stage_index, _current_destination.required_stages)
        await get_tree().create_timer(STAGE_RESULT_HOLD).timeout


func _finalize_launch() -> void:
    LaunchSessionService.set_state(LaunchSessionService.State.SETTLING)
    await get_tree().create_timer(0.5).timeout
    _is_launching = false
    _current_destination = null
    LaunchSessionService.set_state(LaunchSessionService.State.IDLE)
    SaveSystem.resume_autosave()
    SaveSystem.save_now()
    EventBus.launch_ready.emit()
```

### 4.3 외부에서 호출 가능한 진입점

| 호출자 | 호출 메서드 | 용도 |
|---|---|---|
| `MainSceneController._on_launch_pressed()` | `LaunchService.start_launch()` | 수동 발사 |
| `AutoLaunchService.tick()` | `LaunchService.start_launch()` | 자동 발사 |
| 그 외 | (호출 금지) | EventBus만 구독 |

## 5. 단계별 연출 타이밍

단계 1개의 길이는 **2.0초**로 고정한다. 내부 분배는 다음과 같다.

| 구간 | 길이 | 동작 |
|---|---|---|
| Judge | 0.3s | 확률 굴림 직전 짧은 텐션 (UI에서 Stage Indicator가 '판정 중' 펄스) |
| Ascent | 1.4s | 성공 시 RocketView가 `STAGE_ASCENT_HEIGHT`만큼 위로 트윈 (Quad.Out) |
| Result Hold | 0.3s | 결과 후 다음 단계 진입 전 호흡 |

발사 전체 길이는 `required_stages × 2.0s`이며, 현재 목적지 stage 범위는 다음과 같다.

| Tier | required_stages | 발사 총 길이 |
|---|---|---|
| 1 | 3~4 | 6~8s |
| 2 | 5~6 | 10~12s |
| 3 | 7~8 | 14~16s |
| 4 | 9 | 18s |
| 5 | 10 | 20s |

실패 분기는 Judge(0.3s) + Result Hold(0.3s) + Settling(0.5s) ≈ 1.1s 추가 후 idle로 복귀한다.

## 6. 카메라 연출

`scenes/main/main_screen.tscn`의 `Camera2D` 노드에 `scripts/camera/camera2d_shake.gd` 헬퍼를 부착한다.

### 6.1 헬퍼 시그니처

```gdscript
class_name Camera2DShake
extends Camera2D

var _shake_amount: float = 0.0
var _shake_decay: float = 0.0
var _base_position: Vector2 = Vector2.ZERO


func pulse_zoom(target: Vector2, duration: float) -> void:
    var tween: Tween = create_tween()
    tween.tween_property(self, "zoom", target, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "zoom", Vector2(1.05, 1.05), duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func shake(amount: float, decay: float) -> void:
    _shake_amount = amount
    _shake_decay = decay


func _process(delta: float) -> void:
    if _shake_amount > 0.01:
        offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amount
        _shake_amount = max(0.0, _shake_amount - _shake_decay * delta)
    else:
        offset = Vector2.ZERO
```

### 6.2 이벤트별 카메라 동작

| EventBus 시그널 | zoom 변화 | shake |
|---|---|---|
| `launch_started` | 1.0 → 1.05 (50ms, Quad.Out) | (없음) |
| `stage_succeeded` | 1.05 → 1.07 → 1.05 (200ms 펄스) | amount 2.0, decay 8.0 |
| `stage_failed` | 1.05 → 1.02 (300ms) | amount 12.0, decay 18.0 |
| `launch_completed` | 1.05 → 1.10 (600ms, Quad.InOut) | amount 4.0, decay 6.0 |
| `launch_ready` (idle 복귀) | 현재값 → 1.0 (400ms) | (없음) |

`MainSceneController`가 EventBus 시그널을 받아 `Camera2DShake.pulse_zoom()` / `shake()`를 호출한다.

## 7. Sky Transition 연동

`scripts/services/sky_profile_applier.gd`가 `EventBus.stage_succeeded`와 `EventBus.launch_started`를 구독한다. 단계 통과 진행률에 따라 다음 profile로 미세 보간한다.

### 7.1 적용 로직

```gdscript
func _on_launch_started(total_stages: int, _duration: float, _tier: int, sky_route_key: StringName) -> void:
    _current_route = SkyProfileConfig.get_route(sky_route_key)
    _total_stages = total_stages
    _apply_profile_immediate(_current_route.profiles[0])


func _on_stage_succeeded(stage_index: int, total_stages: int, _sky_route_key: StringName) -> void:
    var progress: float = float(stage_index + 1) / float(total_stages)
    var profile_index: int = _resolve_profile_index_for_progress(progress)
    var target_profile: SkyProfile = _current_route.profiles[profile_index]
    if target_profile == _last_applied:
        return
    _tween_profile(target_profile, 1.0)  # 1초 cross-fade
    _last_applied = target_profile
```

### 7.2 Sky Profile 리소스 (`scripts/resources/sky_profile.gd`)

```gdscript
class_name SkyProfile
extends Resource

@export var id: StringName
@export var background_texture: Texture2D
@export var top_color: Color = Color.BLACK
@export var bottom_color: Color = Color.BLACK
@export var star_density: float = 0.0
@export var ambient_modulate: Color = Color.WHITE
@export var bloom_intensity: float = 0.0
```

profile 자체는 `data/sky/SKY_*.tres`로 보관한다. 적용 대상은 SkyLayer의 ShaderMaterial uniform과 SkyBackground 텍스처 두 가지다.

### 7.3 Sky Route 매핑

| Destination Tier | Sky Route Key | Profile 순서 |
|---|---|---|
| 1 | `ROUTE_EARTH` | SPACEPORT → UPPER_ATMOS → LOW_ORBIT |
| 2 | `ROUTE_LUNAR` | SPACEPORT → UPPER_ATMOS → LOW_ORBIT → CISLUNAR |
| 3 | `ROUTE_MARS` | SPACEPORT → UPPER_ATMOS → LOW_ORBIT → CISLUNAR → MARS_APPROACH |
| 4 | `ROUTE_OUTER_SOLAR` | SPACEPORT → UPPER_ATMOS → LOW_ORBIT → ASTEROID_BELT → OUTER_SOLAR |
| 5 | `ROUTE_INTERSTELLAR` | SPACEPORT → UPPER_ATMOS → LOW_ORBIT → OUTER_SOLAR → INTERSTELLAR |

### 7.4 진행률 → profile index 매핑

`stage_index + 1` 기준으로 정규화된 progress를 다음 게이트에 매핑한다.

| Gate | Progress |
|---|---|
| 1 | 0.0 |
| 2 | 0.15 |
| 3 | 0.35 |
| 4 | 0.62 |
| 5 | 0.88 |

`_resolve_profile_index_for_progress(progress)`는 `progress`가 통과한 마지막 게이트의 인덱스를 route profile 배열 길이에 클램프해 반환한다.

## 8. 결과 분기

### 8.1 모든 단계 성공

1. `LaunchService._on_all_stages_succeeded()` → `EventBus.launch_completed(destination_id, rewards)` 송출.
2. `DestinationService`는 보상(credits, program_lv XP, 자동발사 진행도)을 적용하고 다음 목적지를 큐잉한다.
3. `SkyProfileApplier`가 마지막 profile을 fade-in한다.
4. `UILayer.ResultOverlay`가 표시된다 (성공 색상: `Theme.LAUNCH_SUCCESS_FLASH`).
5. (선택) 짧은 cutscene 재생: `scenes/launch/destination_arrival_cutscene.tscn`이 정의되어 있으면 instantiate해 1.5~2s 재생 후 free.
6. `_finalize_launch()`가 0.5s 후 idle로 복귀시킨다.

### 8.2 중간 실패

1. `EventBus.stage_failed(failed_index, total_stages)` 송출.
2. `RocketView`는 흔들림 + 정지(엔진 꺼짐) 애니메이션. 추락은 표현하지 않는다 (2D 인크리멘탈 톤에 부적합).
3. `VFXLayer.ScreenFlash`가 실패 색(`Theme.LAUNCH_FAIL_FLASH`)으로 0.15s 플래시.
4. 목적지 tier ≥ 3이면 `StressService.apply_failure(failed_index)` 호출 → 다음 발사 성공률에 디버프 누적.
5. `UILayer.ResultOverlay`가 실패 메시지를 1.0s 표시 후 자동 닫힘.
6. `_finalize_launch()`가 0.5s 후 idle로 복귀시켜 즉시 재발사 가능 상태가 된다.

### 8.3 보상 데이터 흐름

```
LaunchService._on_all_stages_succeeded()
    │
    └─► DestinationService.complete_current()
          │
          ├─ rewards = DestinationConfig.get_rewards(destination_id)
          ├─ Wallet.add_credits(rewards.credits)
          ├─ ProgramService.add_xp(rewards.xp)
          ├─ ProgressionService.advance_destination()
          └─ EventBus.launch_completed.emit(destination_id, rewards)
```

## 9. Auto Launch 연동

`scripts/services/auto_launch_service.gd` (Autoload)

자동 발사는 별도 큐잉 없이 `LaunchService.start_launch()`를 동일하게 호출한다. 따라서 EventBus 시그널 흐름은 수동 발사와 100% 같다.

### 9.1 시그니처

```gdscript
class_name AutoLaunchService
extends Node

@export var min_interval_seconds: float = 1.0
var _enabled: bool = false
var _accumulator: float = 0.0


func _process(delta: float) -> void:
    if not _enabled:
        return
    if LaunchSessionService.state != LaunchSessionService.State.IDLE:
        return  # 발사 중이면 누적 정지

    _accumulator += delta
    var interval: float = _resolve_current_interval()
    if _accumulator >= interval:
        _accumulator = 0.0
        LaunchService.start_launch()


func set_enabled(value: bool) -> void:
    _enabled = value
    EventBus.auto_launch_toggled.emit(value)


func _resolve_current_interval() -> float:
    var upgrade_level: int = UpgradeService.get_level("auto_launch_speed")
    return max(min_interval_seconds, BASE_AUTO_INTERVAL - upgrade_level * 0.05)
```

### 9.2 해금 조건

`AutoLaunchService.set_enabled(true)`는 다음 조건을 모두 만족할 때만 UI에서 호출 가능하다.

- `ProgramService.level >= AUTO_LAUNCH_UNLOCK_LEVEL` (기본 5)
- 현재 목적지가 한 번 이상 클리어 완료

UI(`AutoLaunchToggle`)는 `EventBus.auto_launch_toggled`를 구독해 시각 상태를 동기화한다.

## 10. 저장 / 오프라인 진행

### 10.1 저장 일시 정지

발사 도중 자동 저장이 발생하면 "단계 N에서 저장 → 단계 N+1 결과는 미저장" 같은 race가 생긴다. 따라서:

- `LaunchService.start_launch()` 진입 직후 `SaveSystem.pause_autosave()` 호출.
- `_finalize_launch()`에서 idle 복귀 시 `SaveSystem.resume_autosave()` + `SaveSystem.save_now()` 호출.

발사 1회는 최장 20s + 결과 hold 0.5s 이므로 저장 공백은 최대 ~21s다. 기본 자동 저장 주기(10s)보다는 길지만, 발사 자체가 결정적 트랜잭션이므로 손실 위험은 없다.

### 10.2 오프라인 진행과 발사

오프라인 진행은 발사가 아니라 자동 발사 누적 결과만 시뮬레이션한다.

- 저장 시점에 `last_play_unix = Time.get_unix_time_from_system()` 기록.
- 로드 시 델타 = `now - last_play_unix`, `OFFLINE_CAP_SECONDS`(기본 8h)로 클램프.
- `OfflineProgressService.simulate(delta)`는 자동 발사 활성/현재 목적지 stage 수/평균 성공률을 기반으로 발사 횟수를 산출하고 보상만 누적한다.
- 오프라인 시뮬레이션은 EventBus 시그널을 송출하지 않는다 (UI 폭주 방지). 대신 요약을 OfflineSummary 다이얼로그로 1회 표시한다.

### 10.3 저장 트리거 정리

| 트리거 | 조건 |
|---|---|
| 주기 자동 저장 | `_enabled = true`이고 발사 idle일 때 10s 마다 |
| 발사 종료 직후 1회 | `_finalize_launch()` 마지막에 `save_now()` |
| 윈도우 종료 | `NOTIFICATION_WM_CLOSE_REQUEST` 처리에서 `save_now()` |
| 수동 저장 | 설정 메뉴 버튼 |

## 11. 의존성 / 관련 파일 맵

### 11.1 코어 스크립트

| 경로 | 역할 |
|---|---|
| `scripts/autoload/event_bus.gd` | 발사 관련 시그널 정의 (§3 참조) |
| `scripts/services/launch_session_service.gd` | 발사 상태 머신 (`IDLE`, `LAUNCHING`, `SETTLING`) |
| `scripts/services/launch_service.gd` | 단일 발사 트랜잭션 |
| `scripts/services/auto_launch_service.gd` | 자동 발사 틱 |
| `scripts/services/destination_service.gd` | 목적지 진행/보상 |
| `scripts/services/sky_profile_applier.gd` | sky profile cross-fade |
| `scripts/services/upgrade_service.gd` | 신뢰도/속도 업그레이드 레벨 조회 |
| `scripts/services/save_system.gd` | 저장 일시 정지/재개 API |

### 11.2 메인 씬 / 발사 씬

| 경로 | 역할 |
|---|---|
| `scenes/main/main_screen.tscn` | 발사 시스템 진입 씬 |
| `scripts/main/main_scene_controller.gd` | UI 이벤트 → LaunchService 라우팅, EventBus 구독 |
| `scenes/launch/rocket_view.tscn` | 로켓 스프라이트 + 엔진 파티클 |
| `scripts/launch/rocket_view.gd` | 단계 상승 트윈, 흔들림, 성공/실패 분기 |
| `scripts/camera/camera2d_shake.gd` | Camera2D 줌 펄스 / 셰이크 헬퍼 |

### 11.3 UI

| 경로 | 역할 |
|---|---|
| `scripts/ui/ui_layer.gd` | UILayer 루트, 자식 위젯 신호 라우팅 |
| `scripts/ui/stage_indicator.gd` | 단계별 통과/실패 칸 |
| `scripts/ui/launch_button.gd` | LAUNCH 버튼 상태 머신 (LAUNCH / LAUNCHING / WAIT) |
| `scripts/ui/auto_launch_toggle.gd` | AUTO 토글 |
| `scripts/ui/log_panel.gd` | 단계 로그 |
| `scripts/ui/result_overlay.gd` | 성공/실패 결과 표시 |

### 11.4 데이터 리소스

| 경로 | 역할 |
|---|---|
| `data/destinations/*.tres` | `DestinationData` (id, tier, required_stages, sky_route_key, rewards) |
| `data/sky/SKY_*.tres` | `SkyProfile` |
| `data/sky/routes/ROUTE_*.tres` | `SkyRoute` (profile 배열) |
| `data/balance/launch_balance.tres` | tier별 stage 성공률 곡선 |
| `data/balance/launch_constants.tres` | STAGE_TOTAL_DURATION, AUTO 해금 레벨 등 |

### 11.5 EventBus 시그널 정의

`scripts/autoload/event_bus.gd`에 다음을 선언한다.

```gdscript
signal launch_started(total_stages: int, stage_duration: float, destination_tier: int, sky_route_key: StringName)
signal launch_rejected(reason: String)
signal stage_succeeded(stage_index: int, total_stages: int, sky_route_key: StringName)
signal stage_failed(stage_index: int, total_stages: int)
signal launch_completed(destination_id: StringName, rewards: Dictionary)
signal launch_ready
signal auto_launch_toggled(enabled: bool)
```

### 11.6 Autoload 등록 (project.godot)

```ini
[autoload]
EventBus="*res://scripts/autoload/event_bus.gd"
SaveSystem="*res://scripts/services/save_system.gd"
LaunchSessionService="*res://scripts/services/launch_session_service.gd"
LaunchService="*res://scripts/services/launch_service.gd"
AutoLaunchService="*res://scripts/services/auto_launch_service.gd"
DestinationService="*res://scripts/services/destination_service.gd"
UpgradeService="*res://scripts/services/upgrade_service.gd"
StatsService="*res://scripts/services/stats_service.gd"
ProgramService="*res://scripts/services/program_service.gd"
StressService="*res://scripts/services/stress_service.gd"
```

로드 순서는 `EventBus` → `SaveSystem` → 나머지 서비스 → `Launch*` 순서를 권장한다(서비스가 EventBus 시그널을 `_ready()`에서 connect하기 때문).
