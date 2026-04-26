# 로켓 여정 2D 연출 기획서

> **목적**: StarReach의 핵심 내러티브 — "지상 발사 → 대기권 돌파 → 태양계 관통 → 성간 우주" — 를 2D 스프라이트 애니메이션으로 구현하기 위한 연출 설계. 증분형 시뮬레이터의 진행도(progress)가 곧 연출 진행이 되도록 매핑한다.
> **대상**: 기획 확정 전 프로토타입 연출. 이 문서가 확정되면 에셋 사양서/씬 구조 설계로 분기한다.

---

## 1. 컨셉 한 줄 요약

> **"플레이어의 숫자가 오르는 만큼 로켓도 위로 올라간다."**

- 연출은 일회성 시네마틱이 아니라 **진행도에 종속된 상시 배경**이다.
- 세로 스크롤 뷰. 로켓은 화면 중앙~중하단 고정, 세상(배경)이 아래로 흘러내리는 것처럼 보인다.
- 모든 스테이지 전환은 페이드/크로스페이드가 아닌 **그라디언트 색 변이 + 레이어 스왑**으로 연속감 유지.

---

## 2. 여정 스테이지 분할

진행도(내부 수치: `altitude` 또는 대표 재화 누적치의 로그 스케일)에 따른 9단계.

| # | 스테이지명 | 고도/거리 개념 | 대표 시각 요소 | 지속 시간(체감) |
|---|---|---|---|---|
| 0 | **발사대(Pre-Launch)** | 지면 | 발사대, 카운트다운, 연기 | 수 초 (프롤로그) |
| 1 | **대류권(Troposphere)** | ~12 km | 구름, 새, 파란 하늘 | 초반 |
| 2 | **성층권(Stratosphere)** | ~50 km | 옅은 구름, 기상 관측 풍선 | |
| 3 | **중간권/열권(Mesosphere/Thermosphere)** | ~100 km | 오로라, 유성, 짙은 남색 | 전환점 (Kármán Line) |
| 4 | **저궤도(LEO)** | 200~2000 km | 지구 곡면, ISS, 위성 | 초중반 절정 |
| 5 | **지구-달 공간(Cislunar)** | ~38만 km | 멀어지는 지구, 커지는 달 | |
| 6 | **내행성계(Inner Solar System)** | ~AU 단위 | 태양·수성·금성·화성 | 중반 |
| 7 | **외행성계(Outer Solar System)** | 수십 AU | 목성·토성(고리)·천왕성·해왕성·소행성대 | 중후반 |
| 8 | **성간 공간(Interstellar)** | >100 AU | 카이퍼 벨트, 오르트 구름, 먼 항성장 | 후반 |
| 9 | **성간 목적지(Proxima+)** | 광년 단위 | 붉은 왜성, 외계 행성 | 프레스티지 게이트 |

---

## 3. 카메라/뷰포트 전략

- **뷰포트 해상도**: 1080×1920 기준 세로. 가로 화면에서는 배경이 좌우로 확장된 형태로 대응.
- **카메라**: `Camera2D` 고정. 로켓은 앵커 위치에서 수직으로 ±20px 부유(`sin` 기반 bob).
- **움직임의 착시**: 로켓은 움직이지 않고, 배경/전경 레이어가 아래로 스크롤하는 것으로 상승감 연출.
- **스테이지 전환 시 줌 변화**:
  - 지상 → 대기권: 줌 1.0, 스크롤 속도 fast.
  - LEO → Cislunar: 줌 점진적 out (0.8), 지구가 화면 하단에 작게 보임.
  - 태양계 → 성간: 줌 0.6, 로켓이 점(dot)에 가까워지고 별 배경이 주인공으로.

---

## 4. 레이어 구조 (Parallax)

`ParallaxBackground` + `ParallaxLayer` 다층 구조. 각 레이어의 스크롤 속도 배수로 원근감 연출.

| 레이어(뒤→앞) | 스크롤 배수 | 역할 | 스테이지별 교체 |
|---|---|---|---|
| BG_Sky_Gradient | 0.0 | 하늘색 변화 (Shader) | 연속 보간 |
| BG_Stars_Far | 0.1 | 먼 별 | 스테이지 3부터 등장 |
| BG_Stars_Near | 0.25 | 가까운 별 | 스테이지 4부터 |
| BG_Celestial | 0.4 | 행성·태양·달 | 스테이지마다 스폰/디스폰 |
| MG_Clouds_Far | 0.6 | 옅은 구름 | 스테이지 1~2 |
| MG_Clouds_Near | 1.0 | 짙은 구름 | 스테이지 1 |
| FG_Debris | 1.2 | 먼지, 우주쓰레기, 소행성 | 스테이지 7 |
| FG_Particles | — | 로켓 화염/항적 (GPUParticles2D) | 상시 |
| UI_Layer | — | HUD (`CanvasLayer`) | 상시 |

---

## 5. 로켓 스프라이트 상태

`AnimatedSprite2D` 기반. 진행도에 따라 외형이 업그레이드된다 — 증분 게임의 "강화" 피드백.

| 상태 | 트리거 | 표현 |
|---|---|---|
| `idle_ground` | 게임 시작 | 발사대 위, 엔진 off |
| `ignition` | 첫 발사 시점 | 화염 분출, 카메라 셰이크 0.3s |
| `boost_mk1` | 스테이지 1~2 | 단순 화염 |
| `boost_mk2` | 스테이지 3~4 | 단 분리 + 2차 부스터 점화 |
| `boost_mk3` | 스테이지 5~6 | 이온 엔진(푸른 빛) 전환 |
| `cruise` | 스테이지 7~8 | 엔진 약화, 관성 항행, 작은 플리커 |
| `warp` | 스테이지 9 (프레스티지) | 빛 줄기, 아공간 왜곡 Shader |

**업그레이드 연출 훅**: 플레이어가 로켓 강화 업그레이드를 살 때 짧은 플래시 + 형태 morph.

---

## 6. 스테이지별 상세 연출

### Stage 0 — 발사대
- 화면 하단에 발사대 실루엣, 로켓 중앙. 카운트다운 UI (3·2·1).
- 배경은 단색 새벽 하늘(딥 블루 → 오렌지 하단 그라디언트).
- 증분 시작 시 **엔진 점화**: 화염 파티클 폭발, 화면 약한 셰이크, 발사대가 화면 밖으로 스크롤.

### Stage 1 — 대류권
- Sky_Gradient: 하늘색(#87CEEB) 톤.
- 구름 레이어 2단 패럴럭스, 드문드문 새 스프라이트(장식용 스폰 루프).
- 화염이 크고 연기 트레일이 길다(공기 밀도 표현).

### Stage 2 — 성층권
- Sky: 짙은 하늘색 → 남색으로 Lerp.
- 구름 얇아지고, 고도 관측 풍선이 1~2회 흘러지나감.
- 연기 트레일 길이 감소 시작.

### Stage 3 — 중간권/열권 (Kármán Line)
- **전환 강조 포인트**: Kármán Line 100km 통과 시 화면 가로선 한 줄 플래시 + 텍스트 "ENTERING SPACE".
- Sky: 남색 → 검정 그라디언트, 별이 서서히 페이드 인.
- 오로라(초록·보라) Shader 레이어가 상단에서 하단으로 흘러감.
- 화염 길이 최소화, 진공에서의 짧은 플룸으로 전환.

### Stage 4 — 저궤도
- 화면 하단에 **지구 곡면** 등장(큰 호 스프라이트 + 구름 오버레이).
- ISS·위성이 지나가는 이벤트(30~60초 주기 랜덤).
- 로켓 단 분리 연출(`boost_mk2`) — 버린 단이 화면 아래로 추락.

### Stage 5 — Cislunar
- 지구가 점점 작아짐(스케일 Tween), 달이 위에서 커지며 다가옴.
- 달 근접 플라이바이 이벤트(달 크레이터 디테일이 잠깐 보임).

### Stage 6 — 내행성계
- 배경을 "태양계 맵" 스타일로 전환: 먼 태양(화면 중앙 상단에 크게).
- 수성·금성·화성이 스테이지 내 서브-스테이지로 등장·퇴장.
- 태양 플레어 Shader(상단에서 빛줄기). 금성 통과 시 대기 노란빛 반사.

### Stage 7 — 외행성계
- **목성**: 거대한 줄무늬 행성, 대적점 디테일. 지나감에 수초 소요.
- **소행성대**: FG_Debris 레이어 활성, 소행성 스프라이트가 좌우로 드리프트.
- **토성**: 고리 기울기 연출(ellipse), 여러 위성 점.
- **천왕성·해왕성**: 푸른 톤, 빠르게 통과.

### Stage 8 — 성간 공간
- 배경이 거의 검정 + 무수한 별. 별의 이동 속도가 눈에 띄게 빨라짐(광속 근접감).
- 카이퍼 벨트 / 오르트 구름 — 얼음 입자 파티클.
- 로켓이 `cruise` 상태. 엔진 플리커 + 통신 텍스트 UI("SIGNAL DELAY: 4h 12m").

### Stage 9 — 성간 목적지 (프레스티지 게이트)
- `warp` 상태 진입: 화면 전체 빛줄기 뻗음, Chromatic Aberration.
- 목적 항성계 도착: 붉은 왜성 + 외계 행성 실루엣.
- 프레스티지 확정 버튼 UI 등장. 수락 시 전체 페이드 → 신규 루프 시작.

---

## 7. 전환 규칙

- **연속 전환**: 스테이지 경계에서 컷(cut)은 피한다. Sky_Gradient는 `Gradient`에 저장된 키 색을 진행도 비율로 Lerp.
- **이벤트성 연출**: Kármán Line, 단 분리, 행성 플라이바이, 워프는 **1회성 트리거**로 분리하여 `EventBus`에서 `signal`로 발화.
- **되감기 금지**: 프레스티지 전까지 연출은 단방향. 로드 시에도 "현재 스테이지"부터 재개.

---

## 8. 증분 시스템 ↔ 연출 매핑

```
progress_value (대표 재화의 log10 혹은 전용 altitude 값)
  └→ StageManager가 구간 판정 → 현재 스테이지 인덱스(0~9)
       ├→ BackgroundController: 레이어 교체/Gradient 보간
       ├→ RocketController: 애니메이션 상태 전이
       └→ EventDispatcher: 스테이지 진입/이탈 1회성 연출 트리거
```

- **데이터 주도**: 각 스테이지의 `altitude_threshold`, `gradient_top`, `gradient_bottom`, `rocket_state`, `spawnables` 은 `StageData.tres`(Resource)로 분리.
- UI는 `GameState`의 진행도 시그널만 구독. 연출 모듈은 `GameState` ↔ 레이어 상태를 일방향 바인딩.

---

## 9. 에셋 요구 목록 (프로토타입용 최소셋)

### 스프라이트
- `rocket_mk1~mk3.png` — 단 분리 시각화 포함
- `launchpad.png`
- `cloud_A/B/C.png` (3종, 알파 있음)
- `balloon.png`, `bird_A.png`
- `earth_curve.png` (큰 호), `earth_distant.png` (작은 원)
- `moon.png`, `sun.png`
- `planet_mercury/venus/mars/jupiter/saturn/uranus/neptune.png`
- `asteroid_A~D.png`
- `iss.png`, `satellite_A.png`
- `star_big.png`, `star_small.png`, `nebula_A.png`

### 파티클(텍스처)
- `flame_particle.png`, `smoke_particle.png`, `ion_particle.png`
- `dust_particle.png`, `warp_streak.png`

### Shader
- `sky_gradient.gdshader` — 두 색 + 노이즈
- `aurora.gdshader` — 흐르는 리본
- `warp.gdshader` — 방사형 스트레치 + Chromatic Aberration

### 폰트/UI
- 카운트다운 숫자, 고도 텍스트, 신호지연 텍스트용 모노스페이스 픽셀 폰트 1종.

**프로토타입에서는 에셋을 단색 박스/원으로 대체**하고 레이아웃·타이밍·전환만 먼저 검증한다.

---

## 10. Godot 씬 구조 제안

```
Main (Node2D)
├── WorldLayer (Node2D)
│   ├── ParallaxBackground
│   │   ├── Layer_SkyGradient      (ColorRect + Shader)
│   │   ├── Layer_StarsFar         (spawner)
│   │   ├── Layer_StarsNear        (spawner)
│   │   ├── Layer_Celestial        (spawner)
│   │   ├── Layer_CloudsFar
│   │   ├── Layer_CloudsNear
│   │   └── Layer_Debris
│   ├── Rocket (AnimatedSprite2D)
│   │   └── FlameParticles (GPUParticles2D)
│   └── Camera2D
├── EffectsLayer (CanvasLayer)
│   └── TransitionOverlay (flash, warp shader)
└── UILayer (CanvasLayer)
    ├── HUD
    └── StageTransitionLabel
```

- `StageManager` (오토로드 후보): 진행도 → 스테이지 인덱스 판정 및 시그널 발화.
- `BackgroundController` (Main 하위 스크립트): 스테이지 변경 시 레이어 상태 갱신.
- `RocketController`: 로켓 상태·업그레이드 연출.

---

## 11. 기술 리스크 & 완화

| 리스크 | 완화 |
|---|---|
| 패럴럭스 스크롤이 끊김 | 레이어별 `motion_mirroring`을 뷰포트 2배 이상으로. |
| 천체 스폰 누적으로 드로콜 증가 | 스테이지 이탈 시 `queue_free()` 필수. 풀링 고려. |
| Shader 전환 시 프레임 드롭 | `Gradient` 리소스 기반 `ColorRect` 로 대체(필요 시에만 Shader). |
| 오프라인 진행 후 진행도 급점프 | 로드 시 **단계 건너뛰기 요약 UI**로 보여주고, 실시간 연출은 현재 스테이지부터. |
| 가로/세로 화면 전환 | 레이어 크기를 뷰포트 비율로 바인딩하여 동적 조정. |

---

## 12. 단계별 구현 로드맵 (프로토타입 우선)

1. **뼈대(1일)**: Main 씬, Camera2D, ParallaxBackground + SkyGradient만. 고정색 배경이 진행도에 따라 Lerp되는지 검증.
2. **로켓 기본(1일)**: 단색 사각형 로켓 + 화염 파티클. Idle bob 애니메이션.
3. **스테이지 판정(0.5일)**: `StageManager` + `StageData.tres` 3개(지상/대기권/우주)로 축소 테스트.
4. **천체 스폰(1일)**: 스테이지별 스폰/디스폰 로직. 더미 원형 스프라이트 사용.
5. **이벤트 연출(1일)**: 단 분리, Kármán Line 플래시.
6. **에셋 교체(점진)**: 단색 더미 → 실제 스프라이트로 순차 교체.
7. **워프/프레스티지 연출(후순위)**: 기획 확정 후.

---

## 13. 확정 필요 항목 (기획 입력 대기)

- 대표 재화 이름 및 진행도 축(고도 m? AU? log 스케일?) — **연출 구간 임계값 산출의 기준**
- 프레스티지 트리거 조건 — Stage 9 도달이 곧 프레스티지인지, 별도 조건인지
- 로켓 업그레이드 트리 — `boost_mk1~mk3` 변경 타이밍이 스테이지와 일치하는지
- 오프라인 진행 요약 UI 톤앤매너
- 아트 스타일 (픽셀 vs 벡터 vs 일러스트) — 본 문서는 스타일 중립으로 작성됨

---

## 14. 구현 리소스 리스트 (파일명 명세)

Godot 프로젝트 루트(`star-reach/`) 기준 경로. 모든 파일명은 **snake_case**, PNG는 알파 포함 권장.

### 14.1 스프라이트 — 로켓 & 발사대

```
star-reach/assets/sprites/rocket/rocket_mk1.png
star-reach/assets/sprites/rocket/rocket_mk2.png
star-reach/assets/sprites/rocket/rocket_mk3.png
star-reach/assets/sprites/rocket/rocket_stage_discarded.png
star-reach/assets/sprites/rocket/rocket_warp.png
star-reach/assets/sprites/launchpad/launchpad_base.png
star-reach/assets/sprites/launchpad/launchpad_tower.png
star-reach/assets/sprites/launchpad/launchpad_smoke.png
```

### 14.2 스프라이트 — 대기권 오브젝트

```
star-reach/assets/sprites/atmosphere/cloud_a.png
star-reach/assets/sprites/atmosphere/cloud_b.png
star-reach/assets/sprites/atmosphere/cloud_c.png
star-reach/assets/sprites/atmosphere/cloud_thin.png
star-reach/assets/sprites/atmosphere/bird_a.png
star-reach/assets/sprites/atmosphere/bird_b.png
star-reach/assets/sprites/atmosphere/balloon_weather.png
```

### 14.3 스프라이트 — 천체 (Celestial)

```
star-reach/assets/sprites/celestial/earth_curve.png
star-reach/assets/sprites/celestial/earth_distant.png
star-reach/assets/sprites/celestial/moon.png
star-reach/assets/sprites/celestial/sun.png
star-reach/assets/sprites/celestial/planet_mercury.png
star-reach/assets/sprites/celestial/planet_venus.png
star-reach/assets/sprites/celestial/planet_mars.png
star-reach/assets/sprites/celestial/planet_jupiter.png
star-reach/assets/sprites/celestial/planet_saturn.png
star-reach/assets/sprites/celestial/planet_saturn_rings.png
star-reach/assets/sprites/celestial/planet_uranus.png
star-reach/assets/sprites/celestial/planet_neptune.png
star-reach/assets/sprites/celestial/star_red_dwarf.png
star-reach/assets/sprites/celestial/exoplanet_a.png
```

### 14.4 스프라이트 — 우주 오브젝트

```
star-reach/assets/sprites/space/iss.png
star-reach/assets/sprites/space/satellite_a.png
star-reach/assets/sprites/space/satellite_b.png
star-reach/assets/sprites/space/asteroid_a.png
star-reach/assets/sprites/space/asteroid_b.png
star-reach/assets/sprites/space/asteroid_c.png
star-reach/assets/sprites/space/asteroid_d.png
star-reach/assets/sprites/space/kuiper_ice_a.png
star-reach/assets/sprites/space/kuiper_ice_b.png
```

### 14.5 스프라이트 — 배경 별/성운

```
star-reach/assets/sprites/stars/star_big.png
star-reach/assets/sprites/stars/star_medium.png
star-reach/assets/sprites/stars/star_small.png
star-reach/assets/sprites/stars/star_dot.png
star-reach/assets/sprites/stars/nebula_a.png
star-reach/assets/sprites/stars/nebula_b.png
star-reach/assets/sprites/stars/galaxy_far.png
```

### 14.6 파티클 텍스처

```
star-reach/assets/particles/flame_core.png
star-reach/assets/particles/flame_outer.png
star-reach/assets/particles/smoke_soft.png
star-reach/assets/particles/ion_particle.png
star-reach/assets/particles/dust_particle.png
star-reach/assets/particles/warp_streak.png
star-reach/assets/particles/spark.png
```

### 14.7 셰이더

```
star-reach/assets/shaders/sky_gradient.gdshader
star-reach/assets/shaders/aurora.gdshader
star-reach/assets/shaders/warp.gdshader
star-reach/assets/shaders/solar_flare.gdshader
star-reach/assets/shaders/chromatic_aberration.gdshader
```

### 14.8 폰트

```
star-reach/assets/fonts/pixel_mono_regular.ttf
star-reach/assets/fonts/pixel_mono_bold.ttf
```

### 14.9 오디오 (프로토타입 단계에서는 생략 가능)

```
star-reach/assets/audio/sfx/launch_ignition.ogg
star-reach/assets/audio/sfx/stage_separation.ogg
star-reach/assets/audio/sfx/karman_crossing.ogg
star-reach/assets/audio/sfx/warp_activate.ogg
star-reach/assets/audio/bgm/ground.ogg
star-reach/assets/audio/bgm/atmosphere.ogg
star-reach/assets/audio/bgm/space.ogg
star-reach/assets/audio/bgm/interstellar.ogg
```

### 14.10 데이터 리소스 (`.tres`)

```
star-reach/data/stages/stage_0_launchpad.tres
star-reach/data/stages/stage_1_troposphere.tres
star-reach/data/stages/stage_2_stratosphere.tres
star-reach/data/stages/stage_3_mesosphere.tres
star-reach/data/stages/stage_4_leo.tres
star-reach/data/stages/stage_5_cislunar.tres
star-reach/data/stages/stage_6_inner_system.tres
star-reach/data/stages/stage_7_outer_system.tres
star-reach/data/stages/stage_8_interstellar.tres
star-reach/data/stages/stage_9_destination.tres
star-reach/data/stages/sky_gradient_keys.tres
star-reach/data/rocket/rocket_state_mk1.tres
star-reach/data/rocket/rocket_state_mk2.tres
star-reach/data/rocket/rocket_state_mk3.tres
```

### 14.11 씬 파일 (`.tscn`)

```
star-reach/scenes/stage/main_stage.tscn
star-reach/scenes/stage/rocket.tscn
star-reach/scenes/stage/parallax_world.tscn
star-reach/scenes/stage/transition_overlay.tscn
star-reach/scenes/stage/spawners/celestial_spawner.tscn
star-reach/scenes/stage/spawners/cloud_spawner.tscn
star-reach/scenes/stage/spawners/asteroid_spawner.tscn
star-reach/scenes/ui/hud.tscn
star-reach/scenes/ui/stage_transition_label.tscn
star-reach/scenes/ui/offline_summary_popup.tscn
```

### 14.12 스크립트 (`.gd`)

```
star-reach/scripts/stage/stage_manager.gd          # 오토로드
star-reach/scripts/stage/stage_data.gd             # Resource 클래스
star-reach/scripts/stage/background_controller.gd
star-reach/scripts/stage/rocket_controller.gd
star-reach/scripts/stage/rocket_state.gd           # Resource 클래스
star-reach/scripts/stage/celestial_spawner.gd
star-reach/scripts/stage/cloud_spawner.gd
star-reach/scripts/stage/asteroid_spawner.gd
star-reach/scripts/stage/transition_dispatcher.gd
star-reach/scripts/stage/events/karman_flash.gd
star-reach/scripts/stage/events/stage_separation.gd
star-reach/scripts/stage/events/warp_sequence.gd
star-reach/scripts/ui/hud.gd
star-reach/scripts/ui/offline_summary_popup.gd
```

### 14.13 리소스 합계 요약

| 분류 | 개수 |
|---|---:|
| 로켓/발사대 스프라이트 | 8 |
| 대기권 스프라이트 | 7 |
| 천체 스프라이트 | 14 |
| 우주 오브젝트 스프라이트 | 9 |
| 배경 별/성운 스프라이트 | 7 |
| 파티클 텍스처 | 7 |
| 셰이더 | 5 |
| 폰트 | 2 |
| 오디오 (선택) | 8 |
| 데이터 리소스(.tres) | 14 |
| 씬 파일(.tscn) | 10 |
| 스크립트(.gd) | 14 |
| **총합** | **105** |

> **프로토타입 최소 셋(MVP)**: 14.1의 `rocket_mk1.png`, 14.2의 `cloud_a.png`, 14.3의 `earth_curve.png`·`moon.png`·`sun.png`, 14.5의 `star_small.png`, 14.6의 `flame_core.png`·`smoke_soft.png`, 14.7의 `sky_gradient.gdshader`, 14.10의 스테이지 `.tres` 3개(0/4/8), 14.11~14.12 일체. — **총 20개 미만**으로 뼈대 검증 가능.

---

*이 문서는 `plan/rocket_journey_animation.md`에 저장된다. 기획 확정 시 본 문서를 근거로 씬 구조 설계/에셋 명세서로 분기하며, 연출 로직은 `star-reach/scripts/stage/` 하위에 구현한다(추후).*
