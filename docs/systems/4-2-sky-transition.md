# 4-2. Sky Transition — 고도별 하늘/조명 전환

> 카테고리: Cinematic / Visual
> 구현: `scripts/services/sky_controller.gd`, `scripts/services/sky_profile_applier.gd`, `data/sky_profiles/*.tres`

## 1. 시스템 개요

발사 진행률(`elapsed / total_duration`)에 따라 **2D 배경(`ParallaxBackground`) 레이어 + `CanvasModulate` + 별 파티클을 순차 교체**하는 클라이언트 전용 시스템. 목적지 티어에 따라 route가 결정되고, route별로 2~5개의 `SkyProfile` 리소스가 순서대로 적용된다.

**책임 경계**
- `EventBus.launch_started` 수신 → route/프로파일 순서 결정.
- 매 `_process(delta)`에서 진행률 계산 → `gate_alphas` 기준 다음 프로파일로 Tween 보간(1.5~3.0s).
- 세션 시작 시 기본 배경 캐시, 종료 시 복원.
- `ParallaxLayer` 텍스처 / `CanvasModulate.color` / `GPUParticles2D`(별 밀도) 일괄 갱신.

**책임 아닌 것**
- 카메라/연출(→ 4-1)
- 풀스크린 플래시/마일스톤 영상(→ 4-3)
- WorldEnvironment 효과는 사용 가능하지만 2D 배경 구성을 1차로. WorldEnvironment는 보조 색조 보정 용도로만.

## 2. 코어 로직

### 2.1 Tier → Route 매핑 (`SkyProfileConfig.get_route_for_tier`)

| Destination Tier | Sky Route |
|---|---|
| 1 | `ROUTE_EARTH` |
| 2 | `ROUTE_LUNAR` |
| 3 | `ROUTE_MARS` |
| 4 | `ROUTE_OUTER_SOLAR` |
| 5 | `ROUTE_INTERSTELLAR` |

> 같은 tier 내 목적지는 같은 route. 목적지별 미세 차별화는 `Destination` 리소스의 `sky_route_override` 필드(선택)로 가능.

### 2.2 Route → Profile 순서

| Route | 프로파일 순서 |
|---|---|
| `ROUTE_EARTH` | `SPACEPORT → UPPER_ATMOS → LOW_ORBIT` |
| `ROUTE_LUNAR` | `SPACEPORT → UPPER_ATMOS → LOW_ORBIT → CISLUNAR` |
| `ROUTE_MARS` | `SPACEPORT → UPPER_ATMOS → LOW_ORBIT → CISLUNAR → MARS_APPROACH` |
| `ROUTE_ASTEROID` | `SPACEPORT → UPPER_ATMOS → LOW_ORBIT → ASTEROID_BELT` |
| `ROUTE_OUTER_SOLAR` | `SPACEPORT → UPPER_ATMOS → LOW_ORBIT → ASTEROID_BELT → OUTER_SOLAR` |
| `ROUTE_INTERSTELLAR` | `SPACEPORT → UPPER_ATMOS → LOW_ORBIT → OUTER_SOLAR → INTERSTELLAR` |

### 2.3 SkyProfile 정의 (`data/sky_profiles/*.tres`)

5개 Tier × 11개 Zone = **최대 55개 프로파일**. 기본 8종을 우선 작성하고 점진적으로 확장:

```
sky_00_spaceport.tres      # 발사장 기본 하늘 (밝은 푸른색)
sky_01_upper_atmos.tres    # 상층 대기 (보라/주황 그라데이션)
sky_02_low_orbit.tres      # 저궤도 (어두운 청색 + 별 등장)
sky_03_cislunar.tres       # 달 전이 (검은 우주 + 달 원경)
sky_04_mars_approach.tres  # 화성 접근 (적갈색 톤)
sky_05_asteroid_belt.tres  # 소행성대 (회색 톤 + 암석 파티클)
sky_06_outer_solar.tres    # 외태양계 (남청색 + 가스 거인 원경)
sky_07_interstellar.tres   # 성간 공간 (보라/검정 + 성운)
```

각 `SkyProfile` 리소스 필드 (`class_name SkyProfile`):

| 필드 | 타입 | 적용 대상 |
|---|---|---|
| `background_far` | `Texture2D` | `ParallaxLayer/Far/Sprite2D.texture` (가장 뒤, 별/성운) |
| `background_mid` | `Texture2D` | `ParallaxLayer/Mid/Sprite2D.texture` (행성/원경) |
| `background_near` | `Texture2D` | `ParallaxLayer/Near/Sprite2D.texture` (대기 그라데이션) |
| `modulate_color` | `Color` | `CanvasModulate.color` (씬 전체 색조) |
| `ambient_tint` | `Color` | `WorldEnvironment.environment.ambient_light_color` (보조) |
| `star_density` | `float` | 별 `GPUParticles2D.amount` 스케일 (0.0~1.0) |
| `parallax_speed_far/mid/near` | `Vector2` | `ParallaxLayer.motion_scale` |
| `particle_preset` | `String` | 추가 파티클 프리셋 키 (예: `"asteroid_dust"`) |

> **모바일 텍스처 가이드**: 1024x1024 이하, ASTC 4x4 압축, mipmap 생성. 메모리 절약을 위해 background_far는 512x512도 충분.

### 2.4 진행률 기반 게이트 판정

```gdscript
func _process(delta: float) -> void:
    if not _active:
        return
    var elapsed: float = Time.get_ticks_msec() / 1000.0 - _launch_start_time
    var progress: float = clampf(elapsed / _total_launch_duration, 0.0, 1.0)
    var gate_alphas: PackedFloat32Array = _config.gate_alphas  # [0.0, 0.15, 0.35, 0.62, 0.88]
    var target_gate: int = 0
    for i in range(min(_route_profiles.size(), gate_alphas.size())):
        if progress >= gate_alphas[i]:
            target_gate = i
    if target_gate > _current_gate_index:
        _apply_gate_profile(target_gate, true)   # Tween 보간 적용
```

**작동 예**: ROUTE_MARS (5개 프로파일), T3 목적지(stages=7, 총 14s):

| Gate | Alpha | elapsed | 프로파일 |
|---:|---:|---:|---|
| 0 | 0.00 | 0s | SPACEPORT |
| 1 | 0.15 | 2.1s | UPPER_ATMOS |
| 2 | 0.35 | 4.9s | LOW_ORBIT |
| 3 | 0.62 | 8.7s | CISLUNAR |
| 4 | 0.88 | 12.3s | MARS_APPROACH |

### 2.5 프로파일 보간 (Tween 1.5~3.0s)

```gdscript
func _apply_gate_profile(idx: int, animated: bool) -> void:
    var profile: SkyProfile = _route_profiles[idx]
    if not animated:
        _applier.apply_immediate(profile)
        _current_gate_index = idx
        return
    var duration: float = clampf(profile.transition_duration, 1.5, 3.0)
    var tween: Tween = create_tween().set_parallel(true)
    tween.tween_property(_canvas_modulate, "color", profile.modulate_color, duration)
    tween.tween_property(_world_env.environment, "ambient_light_color", profile.ambient_tint, duration)
    tween.tween_method(_applier.crossfade_textures.bind(profile), 0.0, 1.0, duration)
    _current_gate_index = idx
```

`crossfade_textures`는 두 `Sprite2D`의 알파를 교차 페이드하면서 새 텍스처를 swap.

### 2.6 세션 수명 주기

```
EventBus.launch_session_started:
   _applier.cache_default()              # 현재 배경/모듈레이트 캐시

EventBus.launch_started(total_stages, stage_duration):
   route_id = destination.sky_route_override or get_route_for_tier(tier)
   route = get_route(route_id) or get_route("ROUTE_EARTH")   # fallback
   _route_profiles = route.profiles
   _launch_start_time = Time.get_ticks_msec() / 1000.0
   _total_launch_duration = total_stages * stage_duration
   _apply_gate_profile(0, false)         # SPACEPORT 즉시 적용
   _active = true

(매 _process):
   _update_sky_progress()                # progress 계산 → 다음 게이트 도달 시 보간

EventBus.destination_completed:
   _active = false                       # 현재 프로파일 유지 (승리 연출용)

EventBus.launch_anim_changed("idle"):
   _active = false
   _applier.restore_default()            # Tween 1.0s로 기본 배경 복원

EventBus.launch_session_ended:
   _active = false
   _applier.restore_default()
```

### 2.7 `SkyProfileApplier` 책임

| 메서드 | 역할 |
|---|---|
| `cache_default()` | 현재 `ParallaxLayer.texture` / `CanvasModulate.color` / `WorldEnvironment` 속성 캐시 |
| `apply_immediate(profile)` | 즉시 텍스처 교체 + 색조 적용 (Tween 없음, 시작 시점) |
| `crossfade_textures(profile, t)` | 두 `Sprite2D` 알파 교차 페이드 (`t: 0→1`) |
| `restore_default()` | 캐시된 속성을 Tween 1.0s로 복원 |

> 기존 `ParallaxBackground` 노드 트리는 파괴하지 않음. 텍스처/색만 교체. 다른 시스템이 추가한 파티클 노드는 `apply_immediate`가 보존.

## 3. 정적 데이터 — `data/*.tres`

### `data/sky_profiles/*.tres` (8~55개)
- 위 §2.3 SkyProfile 리소스. tier × zone 조합으로 점진 확장.

### `data/sky_routes.tres`
- `Routes` (6종 순서 배열)
- `tier_to_route` (Dictionary: `int → String`)
- `gate_alphas` (`PackedFloat32Array = [0.0, 0.15, 0.35, 0.62, 0.88]`)

### `data/launch_visual_config.tres`
- `gate_alphas` (위와 동일, 단일 진실원 유지를 위해 `sky_routes.tres`에서만 보관 권장)
- `default_transition_duration` (1.5)

## 4. 플레이어 영속 데이터

**없음**.

## 5. 런타임 상태

`sky_controller.gd` 내부:

| 필드 | 용도 |
|---|---|
| `_applier: SkyProfileApplier` | 적용/복원 헬퍼 |
| `_active: bool` | 발사 중 여부 |
| `_route_id: StringName` | 현재 route (`ROUTE_MARS` 등) |
| `_route_profiles: Array[SkyProfile]` | route의 프로파일 순서 배열 |
| `_current_gate_index: int` | 현재 적용된 게이트 인덱스 (0 = SPACEPORT) |
| `_launch_start_time: float` | `Time.get_ticks_msec() / 1000.0` |
| `_total_launch_duration: float` | `total_stages * stage_duration` |

`sky_profile_applier.gd` 내부:
- `_cached_state: Dictionary` (원본 텍스처/색)
- `_far/_mid/_near: Sprite2D` 참조
- `_canvas_modulate: CanvasModulate` 참조
- `_world_env: WorldEnvironment` 참조 (옵션)

## 6. 시그널 (EventBus)

**수신**:
- `EventBus.launch_session_started`
- `EventBus.launch_started(total_stages: int, stage_duration: float)`
- `EventBus.destination_completed(data: Dictionary)`
- `EventBus.launch_anim_changed(state: String)` — `idle` 시 복원
- `EventBus.launch_session_ended`

**발행**:
- 없음. (Sky는 순수 시각 효과, 다른 시스템이 Sky 상태를 알 필요 없음.)

## 7. 의존성

**의존**:
- `EventBus`, `GameState` (목적지 정보)
- `SkyProfile` 리소스 컬렉션
- `ParallaxBackground` 노드 트리 (`scenes/main/main_screen.tscn`)
- `CanvasModulate`, (옵션) `WorldEnvironment`

**의존받음**:
- `MainSceneController` (→ 4-1) — Sky 인스턴스 보유 / EventBus 중계자

## 8. 관련 파일 맵

| 파일 | 수정 이유 |
|---|---|
| `scripts/services/sky_controller.gd` | 진행률 → 프로파일 매핑, Tween 트리거 |
| `scripts/services/sky_profile_applier.gd` | 텍스처/모듈레이트 적용/복원 헬퍼 |
| `data/sky_profiles/sky_*.tres` | 프로파일 리소스들 |
| `data/sky_routes.tres` | route 테이블 + tier 매핑 + gate_alphas |
| `scenes/main/main_screen.tscn` | `ParallaxBackground` + `CanvasModulate` 노드 |
