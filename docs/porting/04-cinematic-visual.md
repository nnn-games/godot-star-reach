# 04. Cinematic / Visual — 발사 연출 기획서

> **문서 유형**: 게임 플레이 기획서 (Gameplay Design Document)
> **작성일**: 2026-04-24
> **정본 근거**: `docs/systems/4-1-seat-cinematic.md` ~ `4-3-launch-vfx.md`
> **대상 독자**: 아트 / VFX / UI / 게임플레이 프로그래머

---

## 0. 개요

**Cinematic / Visual**은 플레이어의 "발사 경험"을 감각적으로 전달하는 레이어다. `LaunchService`가 결정한 판정 결과(Launch Core)를 받아 **2D 시네마틱 + 사전 렌더 영상**으로 풀어낸다.

**3개 하위 시스템**:

| ID | 시스템 | 담당 |
|---|---|---|
| 4-1 | Main Scene Cinematic | 카메라 / 로켓 상승 / 낙하 시퀀스 (`Camera2D` + `Tween`) |
| 4-2 | Sky / Lighting Transition | Tier별 `SkyProfile` 보간 (`ParallaxBackground` + `CanvasModulate`) |
| 4-3 | Launch VFX / Result Overlay | 풀스크린 플래시 + 마일스톤 사전 렌더 영상 (`VideoStreamPlayer`) |

### 0.1 공통 원칙

**"발사 연출은 단일 클라이언트 시뮬레이션이다."**

- 로켓 이동은 `Camera2D` + `Sprite2D.position` Tween.
- 환경 변화는 `ParallaxBackground` + `CanvasModulate.color` 보간.
- `EventBus` 시그널로 단계/완료/실패 결과를 받아 자체 시퀀스 진행.
- 마일스톤(10/25/50/75/100) 도달 시에만 `VideoStreamPlayer` 사전 렌더 영상 5~12초.

---

## 1. Main Scene Cinematic — 로켓 상승/낙하 시퀀스 (4-1)

### 1.1 디자인 의도

**"발사 버튼 한 번 = 한 편의 짧은 영화."**

N단계 확률 판정(→ 01 §3)은 본질적으로 "2초 × N번의 `randf()`"이지만, 플레이어가 느끼는 것은 다음이어야 한다:

1. **상승 중 긴장** — 카메라가 점차 zoom-in, 미세 쉐이크 강화
2. **결과 직후 홀드** — 성공/실패 순간을 인식할 짧은 정적
3. **풀백** — 카메라가 멀어지며 상황 조감
4. **성공: 추가 상승 → 다음 발사 준비 / 실패: 자유낙하 → 착지 → 원위치**

진입 의식 없이 메인 화면에서 LAUNCH 탭 즉시 시퀀스 시작.

### 1.2 상태머신

```
[idle] 메인 화면 진입 시
  ↓ (LAUNCH 탭: EventBus.launch_started)
[ascending]  로켓 상승 중
  ├─ Sprite2D position Tween (-180 px 위로, 단계당)
  ├─ Camera2D.zoom 1.0 → 1.05 (50ms)
  └─ 미세 shake (amplitude 2px, duration 0.4s)
  ↓ (단계 결과 수신: stage_succeeded / stage_failed)
[holding]  0.5s 결과 홀드
  ↓
[pullback]  0.95s easeOutCubic 풀백
  ├─ 성공 (모든 단계 통과) → 추가 상승 → landed
  ├─ 단계 통과 (마지막 아님) → 다음 단계로 (ascending 유지)
  └─ 단계 실패 → 자유낙하로 전환 → falling
  ↓
[falling]  (실패 전용)
  ├─ Sprite2D position Tween (가속, easeIn)
  ├─ Camera2D shake 강도 1.35x
  └─ position.y >= start_y → landed
  ↓
[landed]  0.35s 대기 → 원위치 복귀 → idle
```

### 1.3 카메라 / Sprite 파라미터

| 상태 | Camera2D.zoom | Sprite2D 변화 |
|---|---|---|
| idle (대기) | 1.0 | 메인 화면 중하단 정지 |
| ascending close (단계 통과) | 1.05 | 위로 -180 px Tween |
| success pullback | 0.92 | 추가 상승 +120 px |
| fail pullback | 0.92 | 멈춤 |
| falling | 1.0 | 빠른 Tween (가속) |
| landed | 1.0 | 원위치 복귀 |

### 1.4 타이밍 정리

| 구간 | 시간 | 곡선 |
|---|---|---|
| LAUNCH 진입 | 50ms | Quad.Out (zoom) |
| 단계 | 2.0s × N | 선형 + 미세 shake |
| 결과 홀드 | 0.5s | 정지 |
| 풀백 | 0.95s | easeOutCubic |
| 낙하 (실패) | 가변 | easeIn (가속) |
| 착지 후 대기 | 0.35s | — |
| 원위치 복귀 | 즉시 | — |

**실패 시 최소 다음 발사까지**: holding(0.5) + pullback(0.95) + falling(~1.0) + landed(0.35) ≈ **2.8초**. 이 동안 LAUNCH 버튼 라벨이 상태별로 바뀌며 "지금은 누를 수 없음"을 전달 (서비스가 `input_lock_*` 시그널로 실제 차단).

### 1.5 LAUNCH 버튼 라벨 상태 표

| Cinematic 상태 | 버튼 텍스트 |
|---|---|
| idle | `LAUNCH` |
| ascending | `STAGE x/y` |
| holding | `RESULT` |
| pullback | `PULL BACK` |
| falling | `FALLING...` |
| landed | `RESETTING...` |
| Auto Launch ON | `AUTO` |

### 1.6 플레이어 체감

**상승 중**: 화면이 미세하게 zoom-in. 단계마다 결과 시그널이 도착 → 성공 시 계속, 실패 시 즉시 풀백 전환.

**성공 목적지 완료**: 풀백 후 추가 상승(성공 연출), 그 후 착지. WinScreen 모달은 시네마틱이 `idle`로 돌아온 이후에만 표시 → **연출 중복 방지**. 마일스톤 카운트(10/25/50/75/100) 충족 시 사전 렌더 영상 모달이 시네마틱과 WinScreen 사이에 삽입.

**실패**: 풀백 + 실패 shake 배수(1.35x) + 자유낙하 → 모든 감각이 "떨어진다"에 집중.

### 1.7 시그널 동기화

```gdscript
# scripts/autoload/event_bus.gd
signal launch_started
signal stage_succeeded(stage_index: int, chance: float)
signal stage_failed(stage_index: int, chance: float)
signal launch_completed(d_id: String)
signal cinematic_state_changed(state: String)  # "idle" | "ascending" | "holding" | "pullback" | "falling" | "landed"
signal input_lock_acquired(reason: String)
signal input_lock_released(reason: String)
```

UI / Sky / 메뉴는 `cinematic_state_changed` 구독으로 자체 반응 (예: SkyProfileApplier는 `idle` 복귀 시 RestoreSky).

### 1.8 디자인 주의점

- **`scenes/main/main_screen.tscn`** 트리에 `RocketView` (Sprite2D + AnimationPlayer) + `Camera2D` + `VFXLayer` (GPUParticles2D 컨테이너) + `UILayer` (CanvasLayer) 배치.
- **단계 통과 시그널과 카메라 Tween 분리** — Tween 진행 중 다음 단계 시그널이 도착해도 Tween을 끊지 말고 큐잉.
- **모바일 성능**: 60fps 목표, 저사양 디바이스(`OS.get_screen_dpi()` 등으로 감지) 시 shake amplitude 절반.

---

## 2. Sky / Lighting Transition — Tier별 환경 보간 (4-2)

### 2.1 디자인 의도

**"플레이어가 진행하는 만큼 세상이 바뀐다."**

Tier 1 대기권 (푸른 하늘) → Tier 5 성간 (칠흑 우주)으로 점진 변화. 각 Tier × Zone 조합마다 별도 `SkyProfile.tres` 등록.

전환 트리거:
- **목적지 변경** — `Tween` 1.5~3초로 새 Profile 보간 (주 사용 케이스)
- **단계 통과** (옵션) — 미세 색조 변화로 진행감 강화

### 2.2 Tier × Zone 매핑

`docs/contents.md`의 11 Zone × 5 Tier 조합으로 최대 55개 `SkyProfile` 가능. V1은 Zone별 핵심 1~2 프로필만 작업 후 Tier 변형 적용.

| Zone | 대표 Profile | Tier 변형 규칙 |
|---|---|---|
| Earth Region | sky_earth_atmos | 채도 ↑, 패럴랙스 속도 ↑ |
| Lunar & NEO | sky_lunar | 채도 ↓, 별 밀도 ↑ |
| Inner Solar | sky_inner_solar | 색조 빨강/주황 |
| Asteroid Belt | sky_belt | 회전 파티클 |
| Jovian | sky_jupiter | 거대 가스 폭풍 텍스처 |
| Saturnian | sky_saturn | 고리 레이어 추가 |
| Ice Giants | sky_ice | 청록색 |
| Pluto / Kuiper | sky_kuiper | 어두운 회색 + 얼음 입자 |
| Interstellar | sky_interstellar | 거의 검정 + 가스 nebula |
| Milky Way | sky_milkyway | 풍부한 별 + 색감 풍부 |
| Deep Space | sky_deep | 시공간 왜곡 (셰이더) |

### 2.3 SkyProfile 리소스 스키마

```gdscript
# data/sky_profiles/*.tres
class_name SkyProfile extends Resource

@export var profile_id: String = "sky_earth_atmos_t1"
@export var background_layers: Array[Texture2D] = []     # 4~5장 (전경/중경/원경/별)
@export var parallax_speeds: Array[Vector2] = []         # 레이어별 스크롤 속도
@export var canvas_modulate_color: Color = Color.WHITE
@export var particle_preset: PackedScene                 # GPUParticles2D 프리셋
@export var bgm_track: AudioStream
@export var camera_zoom: float = 1.0
@export var ambient_light: Color = Color(1, 1, 1, 1)
```

### 2.4 SkyProfileApplier 보간 흐름

```gdscript
# scripts/services/sky_profile_applier.gd
func apply_profile(target: SkyProfile, duration: float = 2.0) -> void:
    var tween := create_tween().set_parallel(true)
    tween.tween_property(canvas_modulate, "color", target.canvas_modulate_color, duration)
    tween.tween_property(camera, "zoom", Vector2.ONE * target.camera_zoom, duration)
    # 배경 텍스처 알파 크로스페이드
    for i in range(target.background_layers.size()):
        tween.tween_property(background_layers[i], "modulate:a", 1.0, duration)
    # BGM 크로스페이드
    if target.bgm_track != current_bgm:
        AudioBus.fade_to(target.bgm_track, duration)
```

### 2.5 단계별 미세 변화 (옵션)

각 단계 통과 시 미세한 색조 보정 가능:
- Tier 1 (3~4 단계): 하늘이 점점 어두워짐 (3% Lerp 단계당)
- Tier 5 (10 단계): 별 밀도 점진 증가

성능을 위해 V1은 **목적지 단위 변경만** 활성. 단계별 미세 변화는 V2에서 검토.

### 2.6 모바일 최적화

- 텍스처: ≤ 1024 × 1024
- 압축: ASTC 4×4 (모바일) / DXT5 (PC Steam)
- 파티클 동시 ≤ 100 (저사양 디바이스 ≤ 50)
- BGM: OGG Vorbis q=4, ≤ 90초 루프
- 인접 Zone 프리로드 전략 (현재 Tier ± 1)

### 2.7 V1 활성 / 미완 항목

| 항목 | 상태 |
|---|---|
| 11 Zone 핵심 Profile | V1 활성 |
| Tier 변형 규칙 (5 Tier × 11 Zone = 55) | V1 활성 |
| BGM Tier별 5곡 (Earth / Cislunar / Mars / Outer / Interstellar) | V1 활성 |
| 단계별 미세 색조 변화 | V2 검토 |
| Deep Space 시공간 왜곡 셰이더 | V1 후반 |

---

## 3. Launch VFX / Result Overlay — 풀스크린 피드백 (4-3)

### 3.1 디자인 의도

발사의 즉각 피드백 + 마일스톤의 서사적 마침표 두 축.

| 피드백 | 시간 | 사용처 |
|---|---|---|
| GPUParticles2D 트레일 | 단계 진행 중 지속 | 엔진 트레일 (등 구간 변형) |
| 단계 분리 파티클 | 단계 통과 순간 | 1단/2단 분리 시각화 |
| 폭발 파티클 | 단계 실패 | 검은 연기 + 파편 |
| 풀스크린 플래시 (`ColorRect` modulate) | 0.15~0.3s | 성공/실패/Abort |
| 사전 렌더 영상 (`VideoStreamPlayer`) | 5~12s | 마일스톤 (10/25/50/75/100) + Zone 첫 진입 |

### 3.2 4종 GPUParticles2D 프리셋

```gdscript
# scenes/launch/launch_vfx.tscn 트리:
# Node2D
# ├─ EngineTrail (GPUParticles2D)
# ├─ StageSeparation (GPUParticles2D)
# ├─ Atmosphere Breach (GPUParticles2D)
# └─ Explosion (GPUParticles2D)
```

각 프리셋:
- **EngineTrail**: 단계 시작~통과 동안 emit, 발사 색상은 IAP 코스메틱(트레일 컬러)에 따라 변경
- **StageSeparation**: 단계 통과 순간 1회 burst (작은 입자 50개)
- **Atmosphere Breach**: 카르만 선 통과 등 특정 도달 순간 1회 풀스크린 광선
- **Explosion**: 실패 순간 검은 연기 + 파편 (큰 입자 30개)

### 3.3 풀스크린 플래시

```gdscript
# scenes/ui/flash_overlay.tscn 트리:
# CanvasLayer (layer = 100)
# └─ ColorRect (anchor full)
```

```gdscript
# scripts/ui/flash_overlay.gd
func flash(color: Color, duration: float = 0.25) -> void:
    color_rect.color = color
    color_rect.modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(color_rect, "modulate:a", 0.7, duration * 0.3)
    tween.tween_property(color_rect, "modulate:a", 0.0, duration * 0.7)
```

| 이벤트 | 색상 | duration |
|---|---|---|
| 목적지 완료 (성공) | `Color(1, 1, 0.8)` (밝은 백황색) | 0.25s |
| 단계 실패 (T1~T2) | `Color(0.4, 0.0, 0.0)` (어두운 적색) | 0.20s |
| Abort 발생 | `Color(1, 0.2, 0)` (강한 적색) | 0.40s + shake 강화 |

### 3.4 사전 렌더 영상 (`VideoStreamPlayer`)

마일스톤 + Zone 첫진입 시 풀스크린 영상 재생.

```gdscript
# scenes/transitions/milestone_video_overlay.tscn 트리:
# CanvasLayer (layer = 200)
# └─ VideoStreamPlayer (anchor full)
#    ├─ stream = preload("res://data/cinematic_videos/D_010.ogv")
#    └─ Skip Button (Control)
```

| 이벤트 | 영상 ID | 길이 |
|---|---|---|
| D_010 첫 도달 | mile_010_karman | 6s |
| D_025 첫 도달 | mile_025_moon | 8s |
| D_050 첫 도달 | mile_050_mars | 10s |
| D_075 첫 도달 | mile_075_jupiter | 10s |
| D_100 첫 도달 | mile_100_endgame | 12s |
| Zone 첫 진입 (각 11) | zone_*_intro | 5~8s |

**스킵 정책**: 첫 재생은 스킵 가능 (탭으로 즉시 종료), 2회차 재생은 자동 스킵 (옵션, 설정 메뉴에서 변경 가능).

**SaveSystem 필드**:
```json
{
    "seen_cinematics": ["mile_010_karman", "zone_earth_intro"]
}
```

### 3.5 영상 인코딩

| 항목 | 값 |
|---|---|
| 포맷 | Theora (.ogv) — Godot 네이티브 지원 |
| 해상도 | 720p (1280 × 720) |
| 프레임레이트 | 24 fps |
| 평균 비트레이트 | ≤ 1.5 Mbps |
| 음성 | OGG Vorbis 96 kbps |
| 단일 영상 파일 크기 | 약 1.5~3 MB |
| 총 16종 영상 (5 mile + 11 zone) | 약 30~50 MB |

### 3.6 입력 잠금

영상 재생 중 LAUNCH 버튼 비활성:

```gdscript
EventBus.input_lock_acquired.emit("milestone_video")
# ... 영상 재생 ...
EventBus.input_lock_released.emit("milestone_video")
```

`MainScreen`은 잠금 reason 누적 카운터 → 0이면 활성, > 0이면 비활성.

---

## 4. 연출 플로우 통합 — 한 번의 발사에서 보이는 것

```
[메인 화면 진입]
  ├─ Cinematic: state = idle, Sprite2D 정지
  ├─ Sky: 현재 Tier의 SkyProfile 적용
  └─ Audio: 해당 Tier BGM 재생

[LAUNCH 탭]
  ├─ EventBus.launch_started.emit()
  ├─ Cinematic: state → ascending, Camera zoom 1.0 → 1.05 (50ms)
  ├─ VFX: EngineTrail 활성
  └─ UI: 버튼 라벨 "STAGE 1/N"

[스테이지 1 통과 (2초 후)]
  ├─ EventBus.stage_succeeded.emit(1, 0.85)
  ├─ Cinematic: Sprite2D position Tween 위로 -180 px
  ├─ VFX: StageSeparation 1회 burst
  └─ UI: 단계 표시기 점등

[스테이지 N 실패]
  ├─ EventBus.stage_failed.emit(N, 0.36)
  ├─ Cinematic: state → holding (0.5s) → pullback (0.95s) → falling
  ├─ VFX: Explosion burst + Camera shake 강화
  ├─ Flash: Color(0.4, 0, 0), 0.20s
  └─ UI: 토스트 "Stage N — Failed"

[모든 스테이지 통과]
  ├─ EventBus.launch_completed.emit(d_id)
  ├─ Cinematic: state → pullback (성공 분기, 추가 상승)
  ├─ Flash: Color(1, 1, 0.8), 0.25s
  ├─ Sky: (옵션) 다음 Tier 프로필 보간 시작
  └─ DestinationService.complete_destination(d_id) → EventBus.destination_completed

[시네마틱 idle 복귀 + WinScreen]
  ├─ Cinematic: state → idle, Sprite2D 원위치
  ├─ Sky: 현재 Tier 유지 또는 다음 Tier로 보간 완료
  └─ UI: WinScreen 모달 노출 (보상 요약, 새 Badge, 마스터리)

[(조건부) 마일스톤 영상 재생]
  ├─ EventBus.input_lock_acquired.emit("milestone_video")
  ├─ VideoStreamPlayer 풀스크린 5~12s
  └─ EventBus.input_lock_released.emit("milestone_video")
```

---

## 5. 단일 클라이언트 연출의 함의

모든 연출이 단일 클라이언트에서 자체 시뮬되므로:

- **장점**: 네트워크 부담 0. 발사 타이밍 완전 독립. CPU/GPU 예산을 한 명의 연출에 집중 가능.
- **단점**: 공용 경험 부재 — 멀티 동시 발사 같은 SF 영상 부재 (싱글 정책상 의도적 결정).
- **마일스톤 영상이 보완**: 공용 임팩트는 사전 렌더 영상이 대체 (5~12초 풀스크린 컷이 강한 인상).

---

## 6. 알려진 이슈 / 포팅 시 주의

1. **사전 렌더 영상 16종 작업 필요** — 마일스톤 5종 (10/25/50/75/100) + Zone 첫진입 11종.
2. **GPUParticles2D 프리셋 4종** — 엔진 트레일 / 단계 분리 / 대기 돌파 / 폭발.
3. **모바일 저사양 가드** — `Performance.get_monitor()` 또는 디바이스 SoC 기반으로 파티클 동시 수 자동 조절.
4. **Tier × Zone 55 SkyProfile 파일 작업** — 핵심 11개 + 변형 자동 생성 도구 검토.
5. **Steam Deck 720p 가독성** — 작은 글씨/아이콘 검증.
6. **단계별 미세 색조 보정** — V2 검토 (V1은 목적지 단위 변경만).
7. **Deep Space 시공간 왜곡 셰이더** — 셰이더 작업 1주 예상.

---

## 7. 관련 원본 문서

- `docs/systems/4-1-seat-cinematic.md` (Main Scene Cinematic으로 재정의)
- `docs/systems/4-2-sky-transition.md`
- `docs/systems/4-3-launch-vfx.md`
- `docs/rocket_launch_implementation_spec.md` §6 (카메라 / Tween / shake 헬퍼)
- `docs/launch_sky_transition_plan.md` (Sky 전환 상세)
- `docs/rocket_launch_content_preparation.md` §2.2~2.4 (VFX / 사운드 목록)
- `docs/ui_design_guide.md` (UI / 컬러 / 애니메이션)
