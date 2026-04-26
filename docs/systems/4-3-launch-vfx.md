# 4-3. Launch VFX / Result Overlay — 파티클 + 마일스톤 영상

> 카테고리: Cinematic / Visual
> 구현: `scenes/launch/launch_vfx.tscn`, `scripts/services/launch_vfx_director.gd`, `data/vfx_presets.tres`, `theme/main_theme.tres`

## 1. 시스템 개요

발사/단계 통과/성공/실패 순간의 **풀스크린/포커스 VFX**를 담당하는 레이어. 두 종류로 분리:

1. **`GPUParticles2D` 프리셋** — 짧은 임팩트 (불꽃 트레일, 단계 분리, 폭발, 대기 돌파 섬광). 매 발사마다 재생.
2. **`VideoStreamPlayer` 마일스톤 영상** — 첫 도달, Tier 승급, Region 클리어 등 드물게 발생하는 큰 보상 순간 전용. 사전 렌더된 짧은 클립(2~4s)을 풀스크린 오버레이로 재생.

**책임 경계**
- `EventBus.launch_stage_resolved` 수신 → 통과/실패 파티클 트리거.
- `EventBus.destination_completed` 수신 → 성공 플래시 + (마일스톤이면) 영상 큐.
- 영상 재생 중에는 LAUNCH 버튼 입력 차단.

**책임 아닌 것**
- 카메라 zoom/shake (→ 4-1)
- Sky 색조 전환 (→ 4-2)
- 보상 요약 모달(`WinScreen`) — 영상 종료 후 표시.

## 2. 코어 로직

### 2.1 `launch_vfx.tscn` 노드 트리

```
launch_vfx.tscn (CanvasLayer, layer = 50)
├─ ParticlesRoot (Node2D)
│  ├─ EngineTrail (GPUParticles2D)         # 발사 시작 ~ landed
│  ├─ StageSeparation (GPUParticles2D)     # 단계 통과 시 1회 emit
│  ├─ AtmosphereBreach (GPUParticles2D)    # 대기 돌파 게이트(progress 0.35) 진입 시
│  └─ FailureExplosion (GPUParticles2D)    # 실패 시 1회 burst
├─ FlashOverlay (ColorRect)                # 성공/실패 풀스크린 플래시
└─ MilestoneVideo (VideoStreamPlayer)      # 마일스톤 영상 (기본 비활성)
```

> `CanvasLayer.layer = 50` 으로 메인 UI(`layer = 10`)보다 위, 모달 다이얼로그(`layer = 100`)보다 아래.

### 2.2 파티클 프리셋 (`data/vfx_presets.tres`)

| 프리셋 키 | `ProcessMaterial` 핵심 파라미터 | 트리거 |
|---|---|---|
| `engine_trail` | `emission_shape = POINT`, `direction = (0, 1)`, `initial_velocity = 280`, `scale_min/max = 0.6/1.4`, `color = orange→red` | `launch_started` 시 `emitting = true`, `landed` 시 `false` |
| `stage_separation` | `one_shot = true`, `amount = 24`, `lifetime = 0.45`, `spread = 80°` | `launch_stage_resolved.stage_passed = true` 시 `restart()` |
| `atmosphere_breach` | `one_shot = true`, `amount = 60`, `color = white`, `scale = 2.0`, `lifetime = 0.6` | Sky gate index가 `LOW_ORBIT`(idx 2) 도달 시 (Sky controller가 EventBus 신호 발행) |
| `failure_explosion` | `one_shot = true`, `amount = 80`, `color = yellow→red`, `lifetime = 0.7`, `gravity = (0, -200)` | `launch_stage_resolved.stage_passed = false` 시 |

### 2.3 풀스크린 플래시 (`FlashOverlay`)

```gdscript
func flash_success() -> void:
    _flash_overlay.color = theme_colors.launch_success_flash    # Color(0.85, 1.0, 0.9, 0.0)
    var tween: Tween = create_tween()
    tween.tween_property(_flash_overlay, "color:a", 0.55, 0.08)
    tween.tween_property(_flash_overlay, "color:a", 0.0, 0.22)

func flash_failure() -> void:
    _flash_overlay.color = theme_colors.launch_fail_flash       # Color(1.0, 0.4, 0.3, 0.0)
    var tween: Tween = create_tween()
    tween.tween_property(_flash_overlay, "color:a", 0.65, 0.06)
    tween.tween_property(_flash_overlay, "color:a", 0.0, 0.20)
```

전체 0.3s 이내. 시네마틱 카메라 shake와 동시에 발생해도 어색하지 않은 길이.

### 2.4 마일스톤 영상 (`VideoStreamPlayer`)

마일스톤 판정은 `destination_completed` 페이로드에서 즉석 판단:

```gdscript
func _on_destination_completed(data: Dictionary) -> void:
    if not data.get("region_first_arrival_badge", "").is_empty():
        _queue_video("res://assets/video/region_first_arrival.ogv")
    elif data.get("mastery_level_up", 0) > 0:
        _queue_video("res://assets/video/mastery_levelup.ogv")
    elif data.get("tier", 0) == 5 and data.get("destination_id", "") == "FINAL":
        _queue_video("res://assets/video/credits_intro.ogv")
    else:
        flash_success()
```

영상 재생 시:
- `MilestoneVideo.stream` 교체 → `play()`
- `EventBus.input_lock_requested.emit("milestone_video")` 발행 → MainScreen이 LAUNCH 버튼 잠금
- `finished` 시그널 수신 → `EventBus.input_lock_released.emit("milestone_video")`
- `WinScreen`은 영상 종료 후 표시 (4-1의 `landed` 상태 + 영상 종료 둘 다 만족 시)

> 영상 포맷은 Godot 기본 지원 `Theora/.ogv`. Steam 빌드는 추가로 H.264 변형도 가능하나 단일 포맷 유지가 단순.

### 2.5 LAUNCH 버튼 텍스트 (참고)

`MainScreen`은 4-1의 `launch_anim_changed` 상태별로 라벨을 바꾼다 (4-1에 명시):

| 상태 | 버튼 텍스트 |
|---|---|
| `idle` | `LAUNCH` |
| `ascending` | `STAGE x/y` |
| `holding` | `RESULT` |
| `pullback` | `PULL BACK` |
| `landed` | `RESETTING...` |
| `auto-launch` | `AUTO` |

VFX 디렉터는 이 라벨을 직접 조작하지 않음 — 상태만 EventBus로 broadcast.

### 2.6 사운드 연결

각 파티클/플래시 트리거 시 `AudioStreamPlayer` 노드에서 SFX 재생. 사운드 카탈로그는 `data/sfx_presets.tres`에서 키-스트림 매핑으로 관리. (싱글 오프라인이라 라이선스 처리는 단일.)

| 이벤트 | SFX 키 |
|---|---|
| 발사 시작 | `launch_ignition` |
| 단계 통과 | `stage_pass` |
| 단계 실패 | `stage_fail_explosion` |
| 대기 돌파 | `atmos_boom` |
| 성공 플래시 | `success_chime` |
| 마일스톤 영상 | (영상 자체에 사운드 포함) |

## 3. 정적 데이터 — `data/*.tres`

| 리소스 | 용도 |
|---|---|
| `data/vfx_presets.tres` | 위 §2.2 파티클 프리셋 4종 (`ParticleProcessMaterial` 묶음) |
| `data/sfx_presets.tres` | SFX 키-스트림 매핑 |
| `theme/main_theme.tres` | `launch_success_flash`, `launch_fail_flash` 색 (Theme `Color` 상수) |

`launch_success_flash`, `launch_fail_flash`는 Theme의 커스텀 색 상수로 보관해 다른 UI(`WinScreen` 헤더 등)와 톤을 공유.

## 4. 플레이어 영속 데이터

없음.

## 5. 런타임 상태

`launch_vfx_director.gd` 내부:

| 필드 | 용도 |
|---|---|
| `_engine_trail: GPUParticles2D` | 발사 트레일 (long-lived) |
| `_flash_overlay: ColorRect` | 플래시 |
| `_milestone_video: VideoStreamPlayer` | 영상 |
| `_video_queue: Array[String]` | 동시 마일스톤 다수 발생 시 직렬 재생 큐 |
| `_active_flash_tween: Tween` | 진행 중 플래시 Tween (재진입 시 `kill()`) |

## 6. 시그널 (EventBus)

**수신**:
- `EventBus.launch_started` — `engine_trail.emitting = true`
- `EventBus.launch_stage_resolved(stage_passed: bool, stage_idx: int)` — `stage_separation` 또는 `failure_explosion` 트리거
- `EventBus.sky_gate_changed(gate_index: int)` — `LOW_ORBIT` 도달 시 `atmosphere_breach`
- `EventBus.destination_completed(data: Dictionary)` — 플래시 또는 마일스톤 영상
- `EventBus.launch_anim_changed("idle")` — `engine_trail.emitting = false`

**발행**:
- `EventBus.input_lock_requested(reason: String)` — 영상 재생 시 LAUNCH 버튼 잠금
- `EventBus.input_lock_released(reason: String)` — 영상 종료

## 7. 의존성

**의존**:
- `EventBus`, `GameState`
- `theme/main_theme.tres` (플래시 색)
- 영상 에셋 (`res://assets/video/*.ogv`)

**의존받음**:
- `MainScreen` — `input_lock_*` 시그널 구독해서 버튼 잠금
- `WinScreen` (→ 8-4) — 영상 종료 후 표시 시점 결정

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scenes/launch/launch_vfx.tscn` | CanvasLayer + 파티클/플래시/영상 노드 트리 |
| `scripts/services/launch_vfx_director.gd` | EventBus 시그널 수신 → VFX 트리거 |
| `data/vfx_presets.tres` | 파티클 프리셋 4종 |
| `data/sfx_presets.tres` | SFX 키-스트림 매핑 |
| `theme/main_theme.tres` | 플래시 색 상수 |
| `assets/video/*.ogv` | 마일스톤 영상 (Theora) |
