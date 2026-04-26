# 4-1. Main Scene Camera — 메인 화면 발사 연출

> 카테고리: Cinematic / Visual
> 구현: `scripts/services/main_scene_controller.gd`, `scripts/services/launch_camera_director.gd`, `data/launch_camera_profile.tres`

## 1. 시스템 개요

메인 화면에서 LAUNCH 버튼을 눌러 발사를 진행하는 동안의 **2D 카메라 연출** 전담 모듈. 메인 화면이 곧 발사대 화면이고, `Camera2D`가 직접 발사 단계마다 미세 zoom + shake를 적용한다. 결과(성공/실패)에 따라 카메라가 풀백/되돌아오는 짧은 시퀀스를 재생한다.

**핵심 성격**:
- 모든 연출은 **2D Camera2D + Tween 기반**.
- 미세 zoom (`1.00 → 1.05`, 50ms 단위)으로 단계 전환 임팩트만 강조 — 화면 전환 비용 0.
- 마일스톤 보상이나 큰 임팩트가 필요한 순간에만 사전 렌더 영상(`VideoStreamPlayer`)을 오버레이 (4-3에서 관리).
- 단일 클라이언트 단독 시뮬 — 동기화 고려 없음.

**책임 경계**
- 발사 시작 시 카메라 zoom-in 바인딩.
- 단계별 결과(`launch_stage_resolved`) 시 미세 zoom pulse + shake.
- 결과별 분기: 성공 → 짧은 풀백 → idle / 실패 → 강한 shake → idle.
- `EventBus.launch_anim_changed` 시그널로 상태 변경 broadcast (UI/Sky 동기화용).

**책임 아닌 것**
- 확률 판정(→ 1-2), 하늘/색조 전환(→ 4-2), 풀스크린 VFX(→ 4-3).

## 2. 코어 로직

### 2.1 카메라 상태머신

```
[idle]            기본 zoom = 1.00, shake = 0
   └─ EventBus.launch_started → ascending

[ascending]       단계 진행 중
   ├─ 단계 시작 시: Tween zoom 1.00 → 1.05 (50ms, TRANS_QUAD)
   ├─ 단계 통과 시: shake_pulse(0.4 amplitude, 0.18s decay)
   ├─ 마지막 단계 통과 + WinEvent → holding
   └─ 어느 단계든 실패 → holding

[holding]         결과 직후 0.5s 정지 (결과 확인 템포)
   └─ 0.5s 후 → pullback

[pullback]        Tween zoom 1.05 → 0.95 → 1.00 (0.95s, ease out)
   ├─ 성공: 부드러운 풀백 후 → landed
   └─ 실패: shake_burst(0.55, 0.35s) 후 → landed

[landed]          0.35s 대기 (영상 오버레이 트리거 가능)
   └─ 카메라 리셋 → idle
```

### 2.2 Camera2D 노드 트리

```
scenes/main/main_screen.tscn
└─ MainCamera (Camera2D)
   ├─ position = Vector2(0, 0)
   ├─ zoom = Vector2(1.0, 1.0)        # ascending 시 1.05
   └─ offset = Vector2(0, 0)          # shake가 매 프레임 갱신
```

> Z순서 안전성을 위해 카메라는 `MainScreen` 루트의 자식. UI(`CanvasLayer`)는 카메라 변형의 영향을 받지 않으므로 zoom 변화가 LAUNCH 버튼을 흔들지 않는다.

### 2.3 zoom / shake 수치 (`data/launch_camera_profile.tres`)

| 항목 | 값 |
|---|---|
| `idle_zoom` | `Vector2(1.00, 1.00)` |
| `ascending_zoom` | `Vector2(1.05, 1.05)` |
| `pullback_zoom` | `Vector2(0.95, 0.95)` |
| `zoom_in_duration` | `0.05` (50ms) |
| `pullback_duration` | `0.95` |
| `pullback_trans` | `Tween.TRANS_CUBIC, EASE_OUT` |
| `holding_delay` | `0.5` |
| `landed_delay` | `0.35` |

### 2.4 shake 수치

| 항목 | 값 |
|---|---|
| `pulse_amplitude` (단계 통과) | `0.4` |
| `pulse_decay` | `0.18` |
| `burst_amplitude` (실패) | `0.55` |
| `burst_decay` | `0.35` |
| `frequency_hz` | `12.0` |

### 2.5 Tween 사용 패턴

```gdscript
func zoom_in() -> void:
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(_camera, "zoom", profile.ascending_zoom, profile.zoom_in_duration)

func pullback(success: bool) -> void:
    var tween: Tween = create_tween()
    tween.set_trans(profile.pullback_trans).set_ease(Tween.EASE_OUT)
    tween.tween_property(_camera, "zoom", profile.pullback_zoom, profile.pullback_duration * 0.5)
    tween.tween_property(_camera, "zoom", profile.idle_zoom, profile.pullback_duration * 0.5)
```

shake는 `_process(delta)` 내부에서 `sin(time * freq)` 기반으로 amplitude 감쇄.

### 2.6 시그널 수신 플로우

```
EventBus.launch_started(total_stages: int, stage_duration: float)
   └─ _state = "ascending"
      _camera_director.zoom_in()
      EventBus.launch_anim_changed.emit("ascending")

EventBus.launch_stage_resolved(stage_passed: bool, stage_idx: int)
   └─ _camera_director.shake_pulse()
      if not stage_passed and _state == "ascending":
          _handle_failure()      # → holding → pullback(false) → landed → idle

EventBus.destination_completed(data: Dictionary)
   └─ if _state == "ascending":
          _handle_success()      # → holding → pullback(true) → landed → idle

EventBus.launch_session_ended
   └─ _state = "idle"
      _camera_director.reset()
      EventBus.launch_anim_changed.emit("idle")
```

### 2.7 `launch_anim_changed` Signal

상태 전이 시마다 `launch_anim_changed.emit(state: String)` broadcast — `state`는 `"idle" | "ascending" | "holding" | "pullback" | "landed"` 중 하나.

- `WinScreen` (→ 8-4): `idle` 상태 복귀 이후에만 표시 (연출 차단 방지).
- `SkyController` (→ 4-2): `idle` → Sky 복원, `ascending` → 진행률 기반 전환 시작.
- `MainScreen` (→ 8-4): 상태별 LAUNCH 버튼 라벨 변경 (LAUNCH / STAGE x/y / RESULT / PULL BACK / RESETTING...).

### 2.8 포커스/창 이벤트

```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        # 백그라운드로 빠지면 진행 중 시퀀스 강제 종료해 idle로 복원
        if _state != "idle":
            _camera_director.reset()
            _state = "idle"
            EventBus.launch_anim_changed.emit("idle")
```

모바일에서 잠금/스와이프 시에도 카메라가 zoom 상태로 멈춰 있지 않도록 안전망.

## 3. 정적 데이터 — `data/*.tres`

### `data/launch_camera_profile.tres` (`Resource`)
- zoom 4종 (`idle_zoom` / `ascending_zoom` / `pullback_zoom` / 보조)
- 템포 값 (`zoom_in_duration` / `pullback_duration` / `holding_delay` / `landed_delay`)
- shake 수치 (`pulse_amplitude` / `burst_amplitude` / `decay` / `frequency_hz`)
- `pullback_trans` (Tween enum 인덱스)

> 전부 코드 외부에서 튜닝. `class_name LaunchCameraProfile` 부여하여 인스펙터에서 편집.

## 4. 플레이어 영속 데이터

**없음** (클라이언트 카메라 연출 전용).

## 5. 런타임 상태

`launch_camera_director.gd` 내부:

| 필드 | 용도 |
|---|---|
| `_state: StringName` | 현재 상태 머신 상태 |
| `_camera: Camera2D` | 메인 카메라 참조 |
| `_profile: LaunchCameraProfile` | 튜닝 리소스 |
| `_active_tween: Tween` | 진행 중 zoom Tween (재진입 시 `kill()`) |
| `_shake_amplitude: float` | 현재 shake 세기 (감쇄 대상) |
| `_shake_time: float` | shake 누적 시간 (sin 입력) |

## 6. 시그널 (EventBus)

**수신**:
- `EventBus.launch_started(total_stages: int, stage_duration: float)`
- `EventBus.launch_stage_resolved(stage_passed: bool, stage_idx: int)`
- `EventBus.destination_completed(data: Dictionary)`
- `EventBus.launch_session_ended`

**발행**:
- `EventBus.launch_anim_changed(state: String)` — UI/Sky/VFX가 구독.

## 7. 의존성

**의존**:
- `EventBus` 오토로드
- `Camera2D` 노드 (씬 트리)
- `LaunchCameraProfile` 리소스

**의존받음**:
- `SkyController` (→ 4-2) — `launch_anim_changed` 구독
- `MainScreen` (→ 8-4) — LAUNCH 버튼 텍스트
- `WinScreen` (→ 8-4) — 표시 지연

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `scripts/services/main_scene_controller.gd` | EventBus 시그널 수신 → CameraDirector 위임 |
| `scripts/services/launch_camera_director.gd` | 카메라 상태머신, zoom Tween, shake 루프 |
| `data/launch_camera_profile.tres` | zoom/shake 튜닝 수치 |
| `scenes/main/main_screen.tscn` | `MainCamera` 노드 + `MainSceneController` 스크립트 부착 |
