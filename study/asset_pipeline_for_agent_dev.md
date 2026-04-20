# Agent 개발에서의 리소스 관리 — 이미지·사운드·파티클

**문제의 본질**: Agent-driven 개발에서 AI는 **텍스트 파일(`.gd`, `.tscn`, `.tres`)만** 만들 수 있다. PNG·OGG·FBX 같은 **이진(binary) 에셋은 생성 불가**. 따라서 전략은 다음 세 축으로 갈린다.

1. **이진 자산 없이** Godot 내장 리소스로 풀 수 있는 범위를 최대로 확장한다 → 프로시저럴·벡터·텍스트 `.tres`.
2. 정말 필요한 이진 자산은 **외부(CC0, 사용자 제작)에서 수급**하되, AI가 **자동으로 참조·설정**할 수 있도록 파이프라인을 정비한다.
3. 모든 리소스는 **`.tres` 참조 기반**으로 관리해 AI가 안전하게 편집할 수 있게 한다.

---

## 0. 먼저 이해할 것 — Godot의 리소스 모델

Godot에서 "리소스"는 크게 두 종류:

| 유형 | 예시 | AI가 직접 생성 가능? |
|---|---|---|
| **이진 파일** | `.png`, `.jpg`, `.ogg`, `.mp3`, `.ttf`, `.gltf` | ❌ 불가 (사람이 공급) |
| **텍스트 리소스** | `.tres`, `.tscn`, `.material`, `.gdshader` | ✅ 가능 |

이진 파일을 `res://` 아래에 넣으면 Godot가 자동으로 `.import` 사이드카와 `.godot/imported/` 캐시를 생성한다. **런타임에 로드되는 실제 리소스는 `.import`가 지정한 재포맷된 캐시**다.

- 이미지 `foo.png` → `foo.png.import` (메타) + `.godot/imported/foo-*.ctex` (실제 로드 대상)
- 오디오 `bgm.ogg` → `bgm.ogg.import` + `.oggvorbisstr` 캐시

→ AI가 **import 설정을 바꿔야 한다면** `.import` 파일을 편집하면 된다 (INI 포맷, 텍스트).

### 0.1 UID의 중요성

Godot 4.4+는 모든 리소스에 **UID**(`uid://xxxx`)를 부여한다. `.uid` 사이드카 파일은 **반드시 커밋**해야 한다 — `.gitignore`하면 다른 머신에서 UID가 재생성되어 씬 참조가 모두 깨진다.

- `.tscn`에서 리소스 참조는 경로와 UID를 함께 저장: `ExtResource("uid://b2a...")` + `path=res://...`
- 파일 이동/이름변경이 있어도 UID로 추적되어 참조가 깨지지 않는다.
- **AI가 `.tscn`/`.tres`를 편집할 때 반드시 `godot-scene-surgeon` 서브에이전트를 쓰라**고 CLAUDE.md에 명시된 이유가 이것이다.

---

## 1. 이미지·텍스처 리소스

### 1.1 AI가 이진 없이 만들 수 있는 텍스처 타입

Godot가 런타임/임포트 타임에 **절차적으로 생성**해주는 Texture2D 파생 리소스들. `.tres`로 저장 가능하며 AI가 텍스트로 편집 가능.

| 리소스 | 용도 | 설정 포인트 |
|---|---|---|
| **`GradientTexture1D` / `GradientTexture2D`** | 그라데이션 바, 스카이박스, 파티클 컬러램프 | `Gradient` 서브 리소스 + 크기/필(linear/radial) |
| **`NoiseTexture2D`** | 노이즈 배경, 마스크, 파티클 노이즈맵 | `FastNoiseLite`(서브 리소스) 주파수·옥타브 |
| **`AtlasTexture`** | 스프라이트시트에서 영역 잘라쓰기 | 원본 `Texture2D` + `region` |
| **`AnimatedTexture`** | 간단 프레임 애니메이션(프레임 수 ≤ 256) | `Frames` 배열 + fps |
| **`ViewportTexture`** | SubViewport 결과를 텍스처로 | 씬 내 SubViewport 경로 |
| **`PlaceholderTexture2D`** | 이진 대체용 더미(크기만 지정) | `size` 벡터 |
| **`CanvasTexture`** | 2D 전용 리트 + 노멀 + 스페큘러 조합 | 3개 슬롯 |
| **`CompressedTexture2D`** | `.png.import`이 만들어내는 런타임 타입 | import 설정으로만 간접 제어 |

### 1.2 증분 시뮬에 특히 유용한 패턴

**배경 그라데이션** (PNG 없이):
```gdscript
# res://ui/themes/sky_gradient.tres
[gd_resource type="GradientTexture2D" load_steps=3 format=3 uid="uid://..."]
[sub_resource type="Gradient" id="Gradient_1"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(0.06, 0.08, 0.18, 1, 0.2, 0.3, 0.6, 1)
[resource]
gradient = SubResource("Gradient_1")
width = 2
height = 512
fill = 1            # 0=linear, 1=radial
fill_from = Vector2(0.5, 0.2)
fill_to = Vector2(0.5, 1.0)
```
이후 씬에서 `TextureRect.texture = preload("res://ui/themes/sky_gradient.tres")`.

**버튼 배경/패널** → `StyleBoxFlat` (이미지 없이 순수 코드):
- 둥근 모서리, 그림자, 테두리, 그라데이션을 모두 `.tres`에서 정의.
- Theme에 연결해 전 UI에 일괄 적용.

**아이콘**:
- CC0 아이콘팩(Kenney, Phosphor, Lucide)을 `res://assets/icons/`에 **벌크 임포트**해두고, AI는 파일명 규칙으로 참조.
- 더 가벼운 대안: **SVG → Godot의 SVG 임포터**가 고해상도 대응을 자동 처리.

### 1.3 이미지 Import 설정 제어

`<file>.png.import`의 주요 키(텍스트 편집 가능):

```ini
[params]
compress/mode=0          ; 0=Lossless, 1=Lossy, 2=VRAM Compressed, 3=VRAM Uncompressed, 4=Basis Universal
compress/lossy_quality=0.7
compress/high_quality=false
compress/hdr_compression=1
mipmaps/generate=false
mipmaps/limit=-1
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map=0     ; 0=Detect, 1=Enable, 2=Disabled
detect_3d/compress_to=1
```

**UI·2D 게임 일반 권장**:
- `compress/mode = 0` (Lossless) — 2D 픽셀 선명.
- `mipmaps/generate = false` — UI는 거의 불필요, 메모리 절약.
- `process/fix_alpha_border = true` — 투명 경계 퍼짐 방지.

**3D/거대 텍스처**:
- `compress/mode = 2` (VRAM Compressed) — GPU 메모리 최적.
- `mipmaps/generate = true`.

→ AI는 PR 리뷰 시 `.import` 값을 읽어 규칙 위반을 즉시 잡아낼 수 있다.

---

## 2. 사운드 리소스

### 2.1 포맷 선택 기준

| 포맷 | 압축 | 용도 | 로딩 |
|---|---|---|---|
| **WAV** | PCM 또는 QOA/IMA ADPCM | **짧은 SFX** (클릭, 획득, 업그레이드) | 전체 메모리 로드 |
| **OGG Vorbis** | 가변 비트레이트, 무손실에 가까움 | **BGM**, 긴 앰비언트 | 스트리밍 가능 |
| **MP3** | 손실 | 라이선스/플랫폼 제약 주의, 권장도 낮음 | 스트리밍 가능 |

**증분/idle 게임 기본 방침**:
- 짧은 피드백 사운드 다수 → WAV + QOA 압축(Godot 4.3+의 `Quite OK Audio` 기본값).
- BGM 루프 → OGG + loop begin 지정.

### 2.2 루프 설정

**WAV import 설정 (`*.wav.import`)**:
```ini
[params]
force/max_rate=false
edit/trim=false
edit/normalize=false
edit/loop_mode=0         ; 0=Detect, 1=Disabled, 2=Forward, 3=Ping-Pong, 4=Backward
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0          ; 0=PCM, 1=IMA ADPCM, 2=Quite OK Audio
```

**OGG/MP3**: loop end는 지원되지 않고 loop begin만 가능. 포워드 루프만.

### 2.3 이진 없이 사운드 만들 수 있나?

**제한적으로 가능**:
- **`AudioStreamGenerator`** — 스크립트로 샘플 버퍼를 직접 채워 합성. 간단한 톤/비프 정도는 생성 가능.
- **`AudioStreamSynchronized`** / **`AudioStreamRandomizer`** — **기존 스트림들을 조합/랜덤화**하는 `.tres`. AI가 가장 자주 쓸 수 있는 영역.
  - `AudioStreamRandomizer`: 클릭 사운드 5종을 넣고 피치/볼륨 랜덤 → 반복감 제거.
  - `AudioStreamSynchronized`: 레이어드 BGM(베이스·멜로디·타악).

**현실적 결론**: BGM/SFX 원본은 사람이 CC0에서 수급. AI는 `.tres`로 **조합·랜덤화·믹싱**을 담당.

### 2.4 AudioBus 구성

`res://default_bus_layout.tres`는 텍스트 편집 가능. AI가 버스 구성(Master / Music / SFX / UI)과 각 버스 이펙트를 `.tres`에 기술하고, 볼륨 옵션 UI는 `AudioServer.set_bus_volume_db()`로 훅업.

```
Master
├── Music   (-6 dB default, effect: AudioEffectLowPassFilter for pause menu)
├── SFX     (0 dB)
└── UI      (-3 dB)
```

---

## 3. 파티클 리소스

파티클은 **AI 개발에 가장 친화적인** 영역 중 하나다. 셰이더/텍스처 없이 순수 `.tres` 설정만으로 풍부한 효과를 만들 수 있다.

### 3.1 선택: GPUParticles2D vs CPUParticles2D

| 항목 | `GPUParticles2D` | `CPUParticles2D` |
|---|---|---|
| 처리 | GPU | CPU |
| 최대 개수 | 수만 개 | 수백 ~ 수천 |
| 설정 | **`ParticleProcessMaterial`**(`.tres`) | 노드 프로퍼티 직접 |
| Web 익스포트 호환성 | 제한적 (셰이더 컴파일) | 안정적 |
| 모바일 저사양 | 느려질 수 있음 | 안정적 |
| 권장 | 데스크탑/고사양 모바일 | **모바일·Web 기본** |

**StarReach (모바일·Web 타깃) 권장**: `CPUParticles2D` 우선. 동일 효과의 설정값이 `GPUParticles2D` ↔ `CPUParticles2D` 간 **거의 1:1 매핑**되므로 나중에 교체 가능.

### 3.2 `ParticleProcessMaterial` 핵심 프로퍼티 (GPU)

AI가 편집하는 `.tres`에서 다루는 주요 축:

- **Spawn**: `emission_shape` (point/sphere/box/ring/directed), `direction`, `spread`, `initial_velocity_min/max`.
- **Gravity/Forces**: `gravity`, `linear_accel_*`, `radial_accel_*`, `tangential_accel_*`, `damping_*`.
- **Scale over life**: `scale_min/max` + `scale_curve` (`CurveTexture` 서브리소스).
- **Color over life**: `color_ramp` (`GradientTexture1D` 서브리소스).
- **Rotation / Angular**: `angle_min/max`, `angular_velocity_*`.
- **Hue/Alpha randomization**: `hue_variation_*`.
- **Turbulence**: 4.3+ 내장 난류, 이미지 없이 복잡한 움직임.

파티클의 **텍스처**는 `GPUParticles2D.texture` 슬롯에 할당. 텍스처 없으면 1x1 흰 점 → 작은 파티클로 그려짐. → **증분 게임의 재화 획득 반짝임, 클릭 폭죽 등은 텍스처 없이 `GradientTexture1D` 컬러램프만으로 충분**.

### 3.3 재사용 파티클 `.tres` 예시 (이진 자산 0개)

```
res://fx/particles/coin_burst.tres       (ParticleProcessMaterial)
res://fx/particles/coin_burst_scale.tres (CurveTexture)
res://fx/particles/coin_burst_ramp.tres  (GradientTexture1D)
```

씬에서:
```
GPUParticles2D
├── process_material = preload("res://fx/particles/coin_burst.tres")
├── texture = null       # 또는 작은 dot.png
├── amount = 32
├── lifetime = 0.8
├── one_shot = true
└── explosiveness = 0.9  # 한순간 터지게
```

이 조합은 **사람 손 없이 완전히 AI가 만든다**. 사운드와 달리 파티클은 자산 수급 부담이 0에 가깝다.

### 3.4 SFX 공장 패턴

업그레이드·프레스티지·재화 증가 등 이벤트별로 파티클 템플릿을 만들어두면 EventBus에서 트리거만 하면 된다.

```
res://fx/particles/
├── currency_tick.tres      # 0.1초 작은 반짝
├── upgrade_applied.tres    # 중간 규모 버스트
├── prestige_fx.tres         # 대형, 느린 페이드
└── error_shake.tres         # 빨간 파편
```

---

## 4. 폰트·텍스트

- 폰트만은 이진(TTF/OTF) 필요. 오픈 폰트(Noto Sans, Inter, Pretendard, Pixelify Sans 등)를 `res://assets/fonts/`에 놓고 **Theme**에서 참조.
- `LabelSettings`(`.tres`)로 제목/본문/숫자 스타일을 분리. AI가 편집 가능.
- `SystemFont`(`.tres`) — 플랫폼 시스템 폰트를 참조 (한글 폴백용).
- 숫자 포맷터(1.23K, 4.5M 등)는 **유틸 스크립트**로 공통화. UI 노드에 하드코딩 금지 (루트 CLAUDE.md 규칙).

---

## 5. 폴더 구조 권장

공식 가이드는 "**에셋 타입 기반**"과 "**피처 기반**" 둘을 허용하지만, **에이전트 개발에서는 피처 기반이 유리**하다 — AI가 `upgrade_panel` 기능을 수정할 때 관련 리소스를 한 폴더에서 찾을 수 있기 때문.

```
star-reach/
├── project.godot
├── main.tscn
├── autoloads/
│   ├── game_state.gd
│   ├── event_bus.gd
│   └── scene_loader.gd
├── features/                      # 피처 단위
│   ├── splash/
│   │   ├── splash.tscn
│   │   ├── splash.gd
│   │   └── assets/
│   │       └── logo.png (+ .import + .uid)
│   ├── main_menu/
│   ├── generators/
│   │   ├── generator_panel.tscn
│   │   ├── generator_data.gd        # Resource 클래스 정의
│   │   └── data/
│   │       ├── gen_01_miner.tres
│   │       └── gen_02_refinery.tres
│   └── prestige/
├── ui/
│   ├── theme/
│   │   ├── main_theme.tres
│   │   ├── label_settings_title.tres
│   │   └── styleboxes/
│   └── components/                  # 공용 UI 씬
│       ├── currency_counter.tscn
│       └── upgrade_button.tscn
├── fx/
│   └── particles/
│       ├── coin_burst.tres
│       └── upgrade_applied.tres
├── audio/
│   ├── bgm/
│   │   └── menu_loop.ogg
│   ├── sfx/
│   │   ├── click_01.wav
│   │   └── click_randomizer.tres   # AudioStreamRandomizer
│   └── buses/
│       └── default_bus_layout.tres
└── shared/
    ├── utils/
    │   └── number_format.gd
    └── textures/
        ├── gradients/
        └── noise/
```

**규칙**:
- **피처 전용 에셋은 피처 폴더 안**으로. 공유될 때만 `shared/`/`ui/`로.
- `snake_case` 파일명(공식 가이드).
- 데이터 주도 리소스(`*.tres`)는 `data/` 서브폴더로 분리.

---

## 6. Agent 워크플로우 — 에셋을 다루는 규칙

1. **AI가 이진 파일을 요구할 때**: 사용자에게 **어떤 특성(크기, 알파, 스타일, CC0 출처)**을 가진 파일이 필요한지 **정확한 명세**를 전달. 파일 스펙만 통보하고, 경로에 임시 `PlaceholderTexture2D.tres`를 남겨둠 → 사용자가 실제 파일을 같은 경로에 드롭하면 자동 교체.
2. **AI는 언제나 리소스 추가 시 `.uid` 파일을 커밋 대상에 포함**. `.gitignore`에서 제외.
3. **씬 편집은 항상 `godot-scene-surgeon` 서브에이전트**. UID/ExtResource id 충돌 방지.
4. **하드코딩된 경로 금지**. 씬에서는 `ExtResource`로, 스크립트에서는 `preload("res://...")` 또는 `@export var icon: Texture2D`로. 문자열 경로 분산을 막는다.
5. **Import 설정 표준화**: 최초 임포트 시 AI가 `.import`를 편집해 규칙(압축/필터/밉맵) 적용 → PR 리뷰 시 검사.
6. **프로시저럴 우선 원칙**: 이진 자산을 요청하기 전에 `GradientTexture2D`·`NoiseTexture2D`·`StyleBoxFlat`·파티클 `.tres`로 **대체 가능한지 먼저 검토**.

---

## 7. CC0 에셋 수급 소스 (사용자가 공급할 때)

이진 자산이 필요하면 **라이선스가 깨끗한 곳에서만** 받아야 상업 배포 안전.

- **[Kenney.nl](https://kenney.nl/assets)** — 60,000+ 무료 CC0 자산 (2D/3D/오디오/UI/폰트). 증분 게임 아이콘·파티클 텍스처·UI 조각이 여기서 거의 다 해결됨.
- **[OpenGameArt.org](https://opengameart.org/content/cc0-resources)** — CC0 카테고리 필터 필수. 라이선스 혼재 주의.
- **[itch.io — CC0 assets](https://itch.io/game-assets/assets-cc0)** — 신선한 개별 아티스트 팩.
- **[Freesound.org](https://freesound.org/)** — 사운드. CC0/BY 필터.
- **[Pixabay Music](https://pixabay.com/music/)** — 상업 사용 가능 BGM.
- **아이콘**: [Phosphor](https://phosphoricons.com/), [Lucide](https://lucide.dev/), [Tabler Icons](https://tabler-icons.io/) — 모두 MIT/ISC.
- **폰트**: [Google Fonts](https://fonts.google.com/), [Pretendard](https://github.com/orioncactus/pretendard).

---

## 8. 체크리스트

- [ ] `*.uid` 파일이 `.gitignore`에 들어있지 않은가?
- [ ] 이진 자산 import 설정이 표준(2D 로스레스/3D VRAM)을 따르는가?
- [ ] 모든 `.tscn` 편집은 `godot-scene-surgeon`을 거쳤는가?
- [ ] 씬·스크립트가 **직접 하드코딩 경로**를 쓰지 않고 `@export` 또는 `preload`로 참조하는가?
- [ ] 공용 파티클/그라데이션 `.tres`를 먼저 시도했는가 (이진 자산 요청 전)?
- [ ] 사운드 BGM에 `loop_mode`가 올바르게 설정됐는가?
- [ ] 폰트·테마가 한 곳(`ui/theme/`)에 정의되고 Project Settings에서 기본 테마로 지정됐는가?

---

## 9. 참고 자료

- [Project organization — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)
- [Importing images — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)
- [Importing audio samples — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html)
- [ParticleProcessMaterial class reference](https://docs.godotengine.org/en/stable/classes/class_particleprocessmaterial.html)
- [GPUParticles2D class reference](https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html)
- [CPUParticles2D class reference](https://docs.godotengine.org/en/stable/classes/class_cpuparticles2d.html)
- [NoiseTexture2D / GradientTexture2D](https://docs.godotengine.org/en/stable/classes/class_noisetexture2d.html)
- [UID changes coming to Godot 4.4 — Godot blog](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/)
- [Kenney Assets (CC0)](https://www.kenney.nl/assets)
- [OpenGameArt CC0 resources](https://opengameart.org/content/cc0-resources)
