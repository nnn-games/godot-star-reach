# Launch Sky Transition System — Godot 4.6 2D 구현 기획

> **목적**: 2D 우주 발사 증분 시뮬레이터 StarReach에서 발사 진행 / 목적지 도달 / Tier 전환 시 배경(하늘·우주)을 자연스럽게 전환하는 시스템을 정의한다.
> **장르**: 2D Incremental Simulator (Godot 4.6, GL Compatibility / Mobile Renderer)
> **플랫폼**: Android / iOS / PC Steam (싱글플레이, 오프라인)
> **작성일**: 2026-04-24
> **관련 코드**: `scripts/services/sky_profile_applier.gd`, `scripts/autoload/event_bus.gd`, `scenes/stage/sky_layer.tscn`

---

## 1. 요약

- 배경 전환은 모두 **2D 레이어 합성**으로 처리한다. 3D Skybox/카메라 시네마틱은 사용하지 않는다.
- 핵심 노드 조합은 `ParallaxBackground` + `CanvasModulate` + `GPUParticles2D` + `WorldEnvironment`(2D Background only)이다.
- 모든 정적 데이터(`SkyProfile`)는 `Resource`(`.tres`)로 분리된다.
- 목적지 변경 / 마일스톤 도달 시 `Tween`으로 `1.5~3초` 보간한다.
- 마일스톤(10/25/50/75/100 도달)과 핵심 First-Reach는 사전 렌더 영상(`VideoStreamPlayer`)으로 보강한다.

---

## 2. 전체 구조

### 2.1 노드 트리

```
Stage (Node2D)
├── WorldEnvironment              # Background only, mobile-safe
├── CanvasModulate                # 화면 전체 색조
├── ParallaxBackground
│   ├── ParallaxLayer (stars_far)         # motion_scale: 0.05
│   ├── ParallaxLayer (stars_near)        # motion_scale: 0.15
│   ├── ParallaxLayer (background)        # motion_scale: 0.30
│   ├── ParallaxLayer (midground)         # motion_scale: 0.55
│   └── ParallaxLayer (foreground)        # motion_scale: 0.85
├── GPUParticles2D (atmosphere)   # 먼지 / 입자 / 성운 입자
├── GPUParticles2D (sparks)       # 발사 직후 화염 잔재
├── Camera2D
├── AudioStreamPlayer (bgm_a)
├── AudioStreamPlayer (bgm_b)     # 크로스페이드용
└── VideoStreamPlayer (cinematic) # 사전 렌더 마일스톤 영상
```

### 2.2 데이터 / 서비스 분리

| 역할 | 파일 | 종류 |
|---|---|---|
| Sky 프로파일 정의 | `data/sky_profiles/zone_*.tres` | Resource |
| Sky 프로파일 타입 | `scripts/data/sky_profile.gd` | `class_name SkyProfile` |
| 프로파일 적용 서비스 | `scripts/services/sky_profile_applier.gd` | Node (autoload 권장) |
| 마일스톤 영상 재생 | `scripts/services/cinematic_player.gd` | Node |
| BGM 크로스페이드 | `scripts/services/bgm_mixer.gd` | Node |
| 이벤트 통신 | `scripts/autoload/event_bus.gd` | autoload |

UI는 `EventBus.sky_profile_changed(profile_id)` 시그널만 구독하고, `SkyProfileApplier`의 내부를 직접 참조하지 않는다.

---

## 3. SkyProfile 리소스 스키마

`scripts/data/sky_profile.gd` — `Resource`를 상속한 데이터 컨테이너.

```gdscript
class_name SkyProfile
extends Resource

@export var profile_id: StringName
@export var display_name: String

# 색조 (CanvasModulate)
@export var canvas_color: Color = Color(1, 1, 1, 1)

# 레이어별 텍스처 (5장 슬롯, 비워두면 해당 레이어 스킵)
@export var tex_stars_far: Texture2D
@export var tex_stars_near: Texture2D
@export var tex_background: Texture2D
@export var tex_midground: Texture2D
@export var tex_foreground: Texture2D

# 패럴랙스 스크롤 속도 (px/sec, X축 자동 스크롤)
@export var parallax_speed_x: float = 6.0

# 파티클 프리셋
@export var particle_preset: StringName = &"none"
@export var particle_emission_rate: float = 0.0
@export var particle_color: Color = Color(1, 1, 1, 0.4)

# BGM 트랙
@export var bgm_stream: AudioStream
@export var bgm_volume_db: float = -6.0

# 전환 시간 (이 프로파일로 들어올 때 사용)
@export_range(0.5, 5.0, 0.1) var transition_seconds: float = 2.0

# 카메라 효과
@export var camera_zoom: Vector2 = Vector2(1.0, 1.0)
@export var camera_shake_amplitude: float = 0.0
```

### 3.1 텍스처 / 자산 가이드

- 모든 레이어 텍스처: **1024x1024 이하**, 가로 타일링 가능하도록 좌/우 끝이 이어져야 함
- 압축: Android `ASTC 4x4`, iOS `ASTC 4x4`, PC `BPTC` (Godot Import Preset에서 지정)
- `ParallaxLayer.motion_mirroring` 사용 → 가로 무한 스크롤
- 별 레이어는 알파 PNG, 색조는 `CanvasModulate`가 입혀준다

---

## 4. Tier · Zone별 Sky Profile 사양

100 목적지 × 11 Zone × 5 Tier 구성을 지원한다.
**11 Zone × 5 Tier = 55 프로파일은 과잉**이므로, 실제 .tres 자산은 **Zone 단위 11종 × Tier 변형 색조 5단계**로 다음과 같이 구성한다.

- 베이스 텍스처: Zone당 1세트 (5 레이어 × 11 = 55장)
- Tier 변형: 같은 텍스처에 `canvas_color`, `parallax_speed_x`, `particle_emission_rate`만 다르게 .tres 추가
- 결과: **Zone × Tier = 55 .tres** (재사용 텍스처 55장)

### 4.1 Zone 정의 (11 Zone)

| Zone ID | 명칭 | 핵심 색조 | 배경 모티프 |
|---|---|---|---|
| `Z01_LAUNCHPAD` | 발사장 / 지표 | `Color(0.70, 0.85, 1.00)` | 새벽 발사장, 구름, 관제탑 |
| `Z02_TROPOSPHERE` | 대기권 하층 | `Color(0.55, 0.75, 0.95)` | 두꺼운 구름, 햇빛 |
| `Z03_STRATOSPHERE` | 성층권 | `Color(0.30, 0.50, 0.85)` | 옅은 구름, 푸른 띠 |
| `Z04_THERMOSPHERE` | 열권 / 오로라 | `Color(0.18, 0.28, 0.55)` | 오로라 그라데이션, 곡률 지구 |
| `Z05_LOW_ORBIT` | 저궤도 | `Color(0.10, 0.12, 0.25)` | 검은 우주 + 지구 가장자리 |
| `Z06_CISLUNAR` | 달 전이 | `Color(0.12, 0.14, 0.20)` | 달 표면, 회색 광휘 |
| `Z07_INNER_PLANETS` | 내행성계 | `Color(0.20, 0.10, 0.08)` | 화성, 붉은 헤이즈, 황색 태양 |
| `Z08_ASTEROID_BELT` | 소행성대 | `Color(0.18, 0.16, 0.14)` | 바위 실루엣, 먼지 입자 |
| `Z09_OUTER_PLANETS` | 외행성계 | `Color(0.10, 0.15, 0.22)` | 가스 행성 띠, 차가운 청 |
| `Z10_KUIPER` | 카이퍼 벨트 | `Color(0.06, 0.08, 0.14)` | 얼음 입자, 희미한 태양 |
| `Z11_INTERSTELLAR` | 성간 우주 | `Color(0.05, 0.05, 0.10)` | 별 밀도 극대, 성운 띠 |

### 4.2 Tier 변형 규칙

같은 Zone 안에서 Tier가 올라갈수록:

| 속성 | T1 | T2 | T3 | T4 | T5 |
|---|---|---|---|---|---|
| `canvas_color` 채도 | 100% | 95% | 88% | 78% | 65% (어두워짐) |
| `parallax_speed_x` | 4.0 | 6.0 | 9.0 | 13.0 | 18.0 |
| `particle_emission_rate` | 0 | 8 | 16 | 28 | 45 |
| `camera_zoom` | 1.00 | 1.00 | 0.95 | 0.90 | 0.85 (확대 → 광활함) |

각 .tres 파일명 규칙: `data/sky_profiles/{zone_id}_t{tier}.tres`
예: `data/sky_profiles/Z05_LOW_ORBIT_t3.tres`

### 4.3 BGM 매핑

BGM은 Zone마다 1트랙, Tier 변화 시에는 같은 트랙의 변주(loop)로 처리한다. 리소스 절약 목적이다.

| Zone | BGM 파일 | 분위기 |
|---|---|---|
| Z01~Z02 | `audio/bgm/launch_takeoff.ogg` | 긴장, 추진 |
| Z03~Z05 | `audio/bgm/orbit_calm.ogg` | 정적, 부유감 |
| Z06~Z07 | `audio/bgm/inner_journey.ogg` | 신비, 탐사 |
| Z08~Z09 | `audio/bgm/deep_space.ogg` | 광활, 공허 |
| Z10~Z11 | `audio/bgm/interstellar.ogg` | 장엄, 미지 |

크로스페이드 정책: Zone이 바뀔 때만 교체. 같은 Zone 내 Tier 전환에는 BGM 유지.

---

## 5. SkyProfileApplier 서비스

### 5.1 책임

- 현재 적용 중인 `SkyProfile`을 보관
- 다음 프로파일이 들어오면 `Tween`으로 `1.5~3초` 보간
- 보간 대상: `CanvasModulate.color`, 각 `ParallaxLayer.motion_offset` 가속도, `GPUParticles2D.amount_ratio`, `Camera2D.zoom`
- 텍스처 교체는 **알파 페이드**로 마스킹 (이전 레이어를 알파 1→0, 새 레이어를 0→1로 동시 보간)

### 5.2 시그널

`event_bus.gd`에 다음 시그널이 있다고 가정한다.

```gdscript
signal sky_profile_requested(profile_id: StringName)
signal sky_profile_changed(profile_id: StringName)
signal sky_transition_started(from_id: StringName, to_id: StringName, seconds: float)
signal sky_transition_finished(profile_id: StringName)
```

### 5.3 핵심 구현 스케치

```gdscript
class_name SkyProfileApplier
extends Node

@export var canvas_modulate: CanvasModulate
@export var parallax_root: ParallaxBackground
@export var atmosphere_particles: GPUParticles2D
@export var camera: Camera2D
@export var bgm_mixer: Node # bgm_mixer.gd 인스턴스

var _current: SkyProfile
var _active_tween: Tween

func _ready() -> void:
	EventBus.sky_profile_requested.connect(_on_profile_requested)

func _on_profile_requested(profile_id: StringName) -> void:
	var next := _load_profile(profile_id)
	if next == null:
		push_warning("SkyProfile not found: %s" % profile_id)
		return
	apply(next)

func apply(next: SkyProfile) -> void:
	var from_id: StringName = _current.profile_id if _current else &""
	var dur := next.transition_seconds
	EventBus.sky_transition_started.emit(from_id, next.profile_id, dur)

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween().set_parallel(true)

	# 색조
	_active_tween.tween_property(canvas_modulate, "color", next.canvas_color, dur)

	# 패럴랙스 속도 (각 레이어의 motion_offset를 _process에서 누적시킨다고 가정)
	_active_tween.tween_method(_set_parallax_speed, _current_parallax_speed(), next.parallax_speed_x, dur)

	# 파티클
	_active_tween.tween_property(atmosphere_particles, "amount_ratio",
		clamp(next.particle_emission_rate / 50.0, 0.0, 1.0), dur)

	# 카메라
	_active_tween.tween_property(camera, "zoom", next.camera_zoom, dur)

	# 텍스처는 별도 _crossfade_layers()에서 알파 보간으로 처리
	_crossfade_layers(next, dur)

	# BGM (Zone이 바뀔 때만)
	if _current == null or _zone_of(_current.profile_id) != _zone_of(next.profile_id):
		bgm_mixer.crossfade(next.bgm_stream, next.bgm_volume_db, dur)

	_active_tween.finished.connect(func() -> void:
		_current = next
		EventBus.sky_profile_changed.emit(next.profile_id)
		EventBus.sky_transition_finished.emit(next.profile_id)
	)
```

### 5.4 레이어 크로스페이드

각 `ParallaxLayer` 내부에 `Sprite2D` 두 개(`active`, `incoming`)를 두고:

1. `incoming.texture = next.tex_*`, `incoming.modulate.a = 0.0`
2. `tween_property(incoming, "modulate:a", 1.0, dur)`
3. `tween_property(active, "modulate:a", 0.0, dur)`
4. 완료 시 `active`/`incoming` 역할 스왑

이 방식은 모바일에서 한 프레임에 두 텍스처만 그리면 되므로 부담이 적다.

---

## 6. ParallaxBackground 레이어 구조

| 레이어 | motion_scale | 역할 | 텍스처 권장 크기 |
|---|---|---|---|
| `stars_far` | 0.05 | 가장 깊은 별, 미세 광점 | 1024x1024 (알파) |
| `stars_near` | 0.15 | 큰 별, 깜빡임 | 1024x1024 (알파) |
| `background` | 0.30 | 행성 / 성운 / 지구 곡률 | 1024x1024 |
| `midground` | 0.55 | 가까운 가스 띠 / 구름층 | 1024x1024 |
| `foreground` | 0.85 | 가까운 입자 / 장애물 실루엣 | 1024x1024 (알파) |

- 모든 레이어는 `motion_mirroring = Vector2(texture_width, 0)`로 가로 무한 스크롤
- 발사 중에는 `_process(delta)`에서 `parallax_root.scroll_offset.x += parallax_speed_x * delta`로 자동 스크롤
- 정지 상태(허브 / 메뉴)에서는 `parallax_speed_x = 0`

---

## 7. CanvasModulate 색조 보간

`CanvasModulate`는 자식 캔버스 전체의 곱셈 색조를 제어한다.

| 단계 | 색조 RGB | 의미 |
|---|---|---|
| 발사장 | `(0.70, 0.85, 1.00)` | 푸른 새벽 |
| 대기권 | `(0.55, 0.75, 0.95)` | 햇빛 강함 |
| 성층권 | `(0.30, 0.50, 0.85)` | 푸른 띠 |
| 저궤도 | `(0.10, 0.12, 0.25)` | 검은 우주 + 지구광 |
| 심우주 | `(0.06, 0.08, 0.14)` | 거의 무채색 |
| 성간 | `(0.05, 0.05, 0.10)` | 칠흑 |

전환은 항상 `Tween.tween_property(canvas_modulate, "color", target, transition_seconds)`. 보간 곡선은 `set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)`을 권장한다.

---

## 8. BGM 크로스페이드

`bgm_mixer.gd`는 `AudioStreamPlayer` 2개(`A`, `B`)를 번갈아 사용한다.

```gdscript
class_name BgmMixer
extends Node

@export var player_a: AudioStreamPlayer
@export var player_b: AudioStreamPlayer

var _active: AudioStreamPlayer

func _ready() -> void:
	_active = player_a

func crossfade(next_stream: AudioStream, target_db: float, seconds: float) -> void:
	if next_stream == null:
		return
	if _active.stream == next_stream:
		return
	var incoming := player_b if _active == player_a else player_a
	incoming.stream = next_stream
	incoming.volume_db = -60.0
	incoming.play()

	var t := create_tween().set_parallel(true)
	t.tween_property(incoming, "volume_db", target_db, seconds)
	t.tween_property(_active, "volume_db", -60.0, seconds)
	t.finished.connect(func() -> void:
		_active.stop()
		_active = incoming
	)
```

- 같은 Zone 내 Tier 전환 시에는 호출하지 않는다 (`SkyProfileApplier`에서 Zone 비교).
- 마일스톤 영상 재생 중에는 BGM `volume_db`를 `-30dB`로 일시 감소.

---

## 9. 사전 렌더 영상 정책

특정 마일스톤과 핵심 First-Reach에서는 5~12초짜리 사전 렌더 영상(MP4 → Godot `.ogv` 또는 `WebM VP9`)을 재생한다.

### 9.1 트리거 조건

| 트리거 | 영상 길이 | 영상 ID |
|---|---|---|
| 10번째 목적지 도달 | 6초 | `cine_milestone_10` |
| 25번째 목적지 도달 | 8초 | `cine_milestone_25` |
| 50번째 목적지 도달 | 10초 | `cine_milestone_50` |
| 75번째 목적지 도달 | 10초 | `cine_milestone_75` |
| 100번째 목적지 도달 (엔딩) | 12초 | `cine_milestone_100` |
| 첫 Zone 진입 (Z02 ~ Z11) | 5~7초 | `cine_first_{zone_id}` |
| First-Tier-5 첫 도달 | 7초 | `cine_first_tier5` |

### 9.2 재생 규칙

- 노드: `VideoStreamPlayer` (autoplay = false, expand = true)
- 스킵 가능: 입력 1회로 `stop()` + 다음 전환 즉시 시작
- 2회차 이후 자동 스킵 (저장 데이터의 `seen_cinematics: Array[StringName]` 확인)
- 영상 종료 후 `EventBus.cinematic_finished.emit(cine_id)`
- 재생 직전 `bgm_mixer`에 `duck(-30dB, 0.3s)` 호출

### 9.3 데이터 저장

`SaveSystem`의 세이브 스키마 (`version: 1`)에 다음 필드 추가:

```gdscript
{
	"version": 1,
	"seen_cinematics": ["cine_milestone_10", "cine_first_Z03_STRATOSPHERE"],
	...
}
```

---

## 10. 모바일 최적화

| 항목 | 정책 |
|---|---|
| 텍스처 해상도 | 모든 레이어 ≤ 1024x1024 |
| 텍스처 압축 | Android/iOS: ASTC 4x4, PC: BPTC |
| 동시 활성 레이어 | 최대 5장 + 크로스페이드 시 일시적 10장 |
| 파티클 입자 수 | 모바일 ≤ 100, PC ≤ 300 (`amount` 동적 설정) |
| `WorldEnvironment` | Background only, Glow / SSR / SSAO 모두 OFF |
| 렌더러 | GL Compatibility (모바일/구형 PC), D3D12 (Windows 옵션) |
| BGM | OGG Vorbis 96kbps mono, 루프 포인트 임포트 시 지정 |
| VideoStream | WebM VP9 720p 30fps, 스킵 즉시 메모리 해제 |
| 프리로드 | 진입 가능성이 있는 인접 Zone 1개의 프로파일만 백그라운드 로드 |

### 10.1 프리로드 전략

```gdscript
# SkyProfileApplier 내부
func preload_neighbors(current_zone: StringName) -> void:
	var next_zone := _next_zone_of(current_zone)
	if next_zone == &"":
		return
	for tier in range(1, 6):
		var path := "res://data/sky_profiles/%s_t%d.tres" % [next_zone, tier]
		ResourceLoader.load_threaded_request(path)
```

---

## 11. 발사 시퀀스에서의 적용 흐름

발사 진행률(`launch_progress: 0.0 ~ 1.0`)에 따라 다음 게이트에서 프로파일을 요청한다.

| 게이트 | progress | 동작 |
|---|---|---|
| `G0` | 0.00 | 현재 Zone Tier-1 프로파일 적용 (이미 적용된 상태일 수도 있음) |
| `G1` | 0.20 | Zone Tier-2 적용 |
| `G2` | 0.45 | Zone Tier-3 적용 |
| `G3` | 0.70 | Zone Tier-4 적용 |
| `G4` | 0.92 | Zone Tier-5 (목적지 도달 직전) |
| `Arrived` | 1.00 | 다음 Zone Tier-1로 전환 + 마일스톤이면 영상 재생 |

게이트 통과 시 `EventBus.sky_profile_requested.emit(profile_id)` 한 줄만 호출하면 된다.

### 11.1 실패 처리

- 실패 시 현재 프로파일 유지
- 0.5초 홀드 후 `Camera2D.zoom`을 1.0으로 복귀
- 추락 연출 동안에는 `parallax_speed_x`를 음수로 보간 (역방향 스크롤)
- 착지 후 `Z01_LAUNCHPAD_t1`로 전환

### 11.2 오프라인 진행 복귀

`SaveSystem` 로드 시:

1. `last_destination_id`로부터 현재 Zone/Tier 계산
2. `SkyProfileApplier.apply(profile)`을 `transition_seconds = 0.0`으로 즉시 적용 (Tween 스킵)
3. 오프라인 동안 통과한 마일스톤 영상은 **재생하지 않고** `seen_cinematics`에 추가만 한다 (사용자가 자리에 없었으므로)

---

## 12. 파일 산출물 목록

### 12.1 코드

- `scripts/data/sky_profile.gd`
- `scripts/services/sky_profile_applier.gd`
- `scripts/services/bgm_mixer.gd`
- `scripts/services/cinematic_player.gd`
- `scripts/autoload/event_bus.gd` (시그널 추가)

### 12.2 씬

- `scenes/stage/sky_layer.tscn` — ParallaxBackground + CanvasModulate + 파티클
- `scenes/stage/cinematic_overlay.tscn` — VideoStreamPlayer + 스킵 버튼

### 12.3 데이터

- `data/sky_profiles/Z01_LAUNCHPAD_t1.tres` ~ `Z11_INTERSTELLAR_t5.tres` (총 55개)

### 12.4 자산

- `assets/sky/{zone_id}/stars_far.png`
- `assets/sky/{zone_id}/stars_near.png`
- `assets/sky/{zone_id}/background.png`
- `assets/sky/{zone_id}/midground.png`
- `assets/sky/{zone_id}/foreground.png`
- (Zone 11개 × 5장 = 55장)
- `audio/bgm/*.ogg` (5트랙)
- `assets/cinematic/*.webm` (마일스톤 5 + Zone 첫 진입 10 + 기타 = ~16편)

---

## 13. 구현 우선순위

1. `SkyProfile` 리소스 클래스 (`scripts/data/sky_profile.gd`)
2. `EventBus`에 sky 시그널 4종 추가
3. `sky_layer.tscn` (ParallaxBackground 5 레이어 + CanvasModulate)
4. `SkyProfileApplier` — 단일 프로파일 적용 + Tween
5. Z01, Z02, Z05, Z11 4개 Zone × Tier-1만 먼저 제작 (4 .tres + 20장 텍스처)
6. 발사 게이트 4개에서 시그널 발화 연동
7. `BgmMixer` + 5 BGM 트랙
8. Tier 1~5 변형 .tres 생성 (스크립트 자동 생성 권장)
9. 나머지 Zone 7개 텍스처 제작
10. `CinematicPlayer` + 마일스톤 영상 재생
11. `seen_cinematics` 저장 연동
12. 인접 Zone 프리로드
13. 모바일 텍스처 압축 / 파티클 수 동적 조정
14. QA 패스 (Section 14)

---

## 14. QA 체크리스트

- 발사 시작 시 G0 ~ G4 게이트가 정확한 progress 지점에서 발화하는가
- Tween이 1.5~3초 안에 부드럽게 색조와 텍스처를 전환하는가
- 같은 Zone 내 Tier 전환 시 BGM이 끊기지 않는가
- Zone 변경 시 BGM 크로스페이드가 5초 안에 완료되는가
- 마일스톤 영상이 첫 도달에는 재생되고 두 번째부터는 자동 스킵되는가
- 영상 재생 중 입력으로 즉시 스킵되는가
- 오프라인 복귀 시 영상이 재생되지 않고 seen_cinematics에 기록만 되는가
- 모바일 (Android 중급기) 에서 60fps가 유지되는가
- 파티클 수가 모바일에서 100을 넘지 않는가
- 텍스처 메모리 사용이 활성 Zone 기준 80MB 이하인가
- ParallaxBackground가 가로 끝에서 끊김 없이 무한 반복되는가
- `CanvasModulate.color` 보간이 UI(HUD)까지 어둡게 만들지 않는가 (UI는 별도 CanvasLayer)
- 실패 시 현재 프로파일이 유지되고 착지 후 발사장으로 복귀하는가
- 게임 종료 후 재시작 시 마지막 적용 프로파일이 즉시 복원되는가 (transition_seconds = 0)
- 빠른 연속 발사(AutoLaunch) 시 Tween이 충돌하지 않고 마지막 요청만 적용되는가
