# 리소스 관리 아키텍처 설계 — StarReach

앞선 여섯 개 study 문서(`splash_and_async_loading`, `mobile_ui_resize`, `asset_pipeline_for_agent_dev`, `asset_registry_pattern`, `headless_first_agent_workflow`, `agent_driven_workflow`)의 결론을 **하나의 일관된 설계**로 통합한다.

---

## 0. 설계 목표와 제약

**목표**
- 이미지·사운드·파티클을 **이름/키 하나로 꺼내 쓸 수 있는** 체계
- AI 에이전트가 **텍스트만으로 추가·수정·검증** 가능한 구조
- 기능(feature) 확장 시 **파일 한 곳만** 수정하면 되도록 응집

**제약 (앞선 메모리에서)**
- 에디터는 F5 플레이테스트 전용
- 씬 편집은 `godot-scene-surgeon` 경유
- `.uid`·`.import`는 커밋, `.godot/`는 gitignore
- 모바일 포트레이트(720×1280 베이스) 우선

---

## 1. Godot의 관용 설계 패턴 — 이 설계가 쓰는 것들

설계에 앞서, Godot가 "이미 제공하거나 권장하는" 패턴을 정리. 이 위에 필요한 것만 얇게 얹는다.

| 패턴 | Godot에서의 구현체 | 이 설계의 용도 |
|---|---|---|
| **Scriptable Object** | `class_name Foo extends Resource` + `.tres` | 생성기·업그레이드·재화의 **데이터 스키마** |
| **Singleton** | Autoload 노드 | GameState / EventBus / SceneLoader / AssetHub / SfxDirector / FxDirector |
| **Observer** | `signal` + `connect()` | 엔티티 ↔ UI 결합 |
| **Event Bus** | Autoload 싱글턴 (signal만) | 엔티티 ↔ Director 결합 해제 |
| **Flyweight** | Resource 참조 공유 | 같은 `AudioStream`을 여러 Player가 참조 |
| **Factory** | `PackedScene.instantiate()` | FX 파티클 스폰 |
| **Composition** | 씬 트리 + Component 노드 | 재사용 UI 조각 |
| **Prototype** | `.tscn`을 복제해 인스턴스화 | 공용 팝업·버튼 |
| **Data-Driven** | `@export` on Resource + `.tres` | 게임 밸런싱 전체 |

**원칙**:
- "**데이터는 Resource, 로직은 Node**" — 데이터/로직 분리의 Godot식 공식.
- "**파일이 하나면 그게 진실**" — 같은 정보가 두 군데 있으면 하나는 지운다.

---

## 2. 폴더 구조 — Feature-First + Shared

공식 가이드는 "**장면과 가까이**"를 권장한다. 여기에 AI 친화성(피처 단위 작업 응집)을 더해 **피처 우선**으로 배치한다.

```
star-reach/
├── project.godot
├── export_presets.cfg
├── default_bus_layout.tres
│
├── autoloads/                         # Layer 3: 런타임 서비스
│   ├── game_state.gd                   # 세이브/로드·재화·틱
│   ├── event_bus.gd                    # 전역 시그널 허브
│   ├── scene_loader.gd                 # 씬 전환 + 로딩 스크린
│   ├── asset_hub.gd                    # 자산 룩업(파사드)
│   ├── sfx_director.gd                 # 사운드 재생·풀·버스
│   └── fx_director.gd                  # 파티클 스폰·풀·포지셔닝
│
├── schemas/                           # Layer 2: 데이터 스키마 (class_name Resource)
│   ├── generator_data.gd               # 생성기 정의
│   ├── upgrade_data.gd                 # 업그레이드 정의
│   ├── currency_data.gd                # 재화 정의
│   ├── sfx_clip.gd                     # 사운드 클립 + 믹싱 메타
│   ├── fx_effect.gd                    # 파티클 효과 정의
│   └── asset_library.gd                # 횡단 자산 매니페스트
│
├── features/                          # 각 기능은 자기 폴더 하나
│   ├── splash/
│   │   ├── splash.tscn
│   │   ├── splash.gd
│   │   └── assets/                     # 이 씬 전용
│   │       └── logo.png (+ .import + .uid)
│   │
│   ├── main_menu/
│   │   ├── main_menu.tscn
│   │   └── main_menu.gd
│   │
│   ├── generators/
│   │   ├── generator_panel.tscn
│   │   ├── generator_panel.gd
│   │   ├── generator_row.tscn          # 재사용 컴포넌트
│   │   ├── generator_row.gd
│   │   └── data/                       # Custom Resource 인스턴스(.tres)
│   │       ├── gen_01_miner.tres
│   │       ├── gen_02_refinery.tres
│   │       └── gen_03_reactor.tres
│   │
│   ├── upgrades/
│   │   ├── upgrade_panel.tscn
│   │   └── data/
│   │       └── upg_*.tres
│   │
│   └── prestige/
│       └── ...
│
├── ui/
│   ├── theme/
│   │   ├── main_theme.tres             # 전역 Theme (버튼·폰트·아이콘)
│   │   ├── label_settings_title.tres
│   │   └── styleboxes/
│   │       ├── panel_flat.tres
│   │       └── button_primary.tres
│   │
│   └── components/                     # 모든 피처가 재사용
│       ├── currency_counter.tscn
│       ├── big_number_label.tscn
│       └── safe_area_margin.tscn       # 이전 문서 §3.2
│
├── fx/
│   └── particles/
│       ├── coin_burst.tres             # ParticleProcessMaterial
│       ├── upgrade_applied.tres
│       ├── prestige_fx.tres
│       └── curves/                     # 파티클이 참조하는 CurveTexture
│           └── scale_ease_out.tres
│
├── audio/
│   ├── bgm/
│   │   └── menu_loop.ogg (+ .import)
│   ├── sfx/
│   │   ├── ui_click_01.wav
│   │   ├── ui_click_02.wav
│   │   ├── currency_tick.wav
│   │   └── randomizers/                # AudioStreamRandomizer .tres
│   │       └── ui_click.tres
│   └── clips/                          # SfxClip Custom Resource 인스턴스
│       ├── ui_click.tres
│       └── upgrade_applied.tres
│
├── shared/
│   ├── assets/
│   │   ├── asset_library.tres          # AssetLibrary 매니페스트 (빌드 스크립트 생성)
│   │   ├── icons/                      # 전역 UI 아이콘
│   │   │   ├── coin.svg
│   │   │   ├── gem.svg
│   │   │   └── settings.svg
│   │   └── textures/
│   │       ├── gradients/              # GradientTexture2D .tres
│   │       └── noise/                  # NoiseTexture2D .tres
│   │
│   ├── fonts/
│   │   └── Pretendard-Bold.otf (+ .import)
│   │
│   └── utils/
│       ├── number_format.gd            # 1.23K/4.5M 포맷터
│       └── math_ext.gd
│
└── tools/                             # 헤드리스 빌드/검증 스크립트
    ├── build_asset_manifest.gd         # 스캔 → asset_library.tres
    ├── build_fx_manifest.gd
    ├── normalize_imports.gd            # .import 일괄 표준화
    └── smoke_test.gd
```

**핵심 규칙**:
- **피처 전용 자산은 피처 폴더 안**. 공유될 때만 `shared/`·`ui/`·`fx/`·`audio/`로 승격.
- **데이터는 `data/` 하위 폴더**, 스크립트는 같은 층 파일.
- **`tools/`는 `@tool` 헤드리스 스크립트**. 런타임 코드와 섞지 않음.
- **`.uid`·`.import` 파일은 모두 커밋**.
- **`addons/`는 이 구조 밖**(루트 `star-reach/addons/`). 서드파티 플러그인만.

---

## 3. 3계층 아키텍처

```
┌────────────────────────────────────────────────────────────────┐
│  Layer 3 — Runtime Services (Autoloads)                        │
│  ──────────────────────────────────────────                    │
│  AssetHub       SfxDirector    FxDirector    SceneLoader       │
│  (수동 조회)     (이벤트 재생)   (파티클 스폰) (씬 전환)         │
│                        ▲                                       │
│                        │ EventBus 시그널 구독                   │
│  ┌─────────────────────┴───────────────────────┐               │
│  │  EventBus  — 로직 없음, 시그널만            │               │
│  │  currency_changed, upgrade_applied, ...      │               │
│  └─────────────────────▲───────────────────────┘               │
│                        │                                       │
│                     GameState (tick/save/load) ─► EventBus 발신 │
└────────────────────────┼───────────────────────────────────────┘
                         │ reads (read-only)
┌────────────────────────┼───────────────────────────────────────┐
│  Layer 2 — Data Schemas (Custom Resources)                     │
│  ──────────────────────────────────────                        │
│  GeneratorData   UpgradeData   CurrencyData   SfxClip   FxEffect│
│  (class_name, @export)                                          │
│                                                                │
│  인스턴스(.tres): gen_01_miner.tres, ui_click.tres, coin_burst... │
└────────────────────────┬───────────────────────────────────────┘
                         │ imported by
┌────────────────────────┼───────────────────────────────────────┐
│  Layer 1 — Binary / Built-in (Godot 내장)                      │
│  ──────────────────────────────────────                        │
│  PNG/SVG   WAV/OGG   Font   Theme.tres   ResourceUID           │
└────────────────────────────────────────────────────────────────┘
```

**단방향 의존성**: 상위는 하위를 알고, 하위는 상위를 모른다. Layer 3이 Layer 2를 **읽고 실행**, Layer 2는 Layer 1을 **참조**.

---

## 4. Layer 2 — 데이터 스키마(Custom Resources)

### 4.1 `SfxClip` — 사운드 정의의 기본 단위

```gdscript
# res://schemas/sfx_clip.gd
class_name SfxClip
extends Resource

@export var id: StringName
@export var stream: AudioStream                      # .wav/.ogg or AudioStreamRandomizer
@export_range(-60.0, 12.0) var volume_db: float = 0.0
@export_range(0.1, 3.0)    var pitch_scale: float = 1.0
@export var bus: StringName = &"SFX"                 # SFX / UI / Music
@export_range(0.0, 1.0)    var pitch_jitter: float = 0.0  # 재생 시 ±랜덤
@export var polyphony_limit: int = 4                 # 동시 재생 상한
```

**왜 Stream을 바로 안 쓰고 한 번 감싸나**:
- 볼륨/피치/버스/랜덤화는 **운영 메타데이터**. 원본 오디오 파일과 분리해야 수정이 용이.
- `SfxClip`만 있으면 AI가 텍스트로 전체 사운드 디자인을 수정 가능(원본 `.ogg`는 그대로).

인스턴스: `res://audio/clips/upgrade_applied.tres`

### 4.2 `FxEffect` — 파티클 효과 정의

```gdscript
# res://schemas/fx_effect.gd
class_name FxEffect
extends Resource

@export var id: StringName
@export var material: ParticleProcessMaterial
@export var texture: Texture2D = null                # null이면 1px 흰 점
@export var amount: int = 32
@export var lifetime: float = 0.8
@export_range(0.0, 1.0) var explosiveness: float = 0.9
@export var one_shot: bool = true
@export var scale: Vector2 = Vector2.ONE
@export var use_gpu: bool = false                    # 모바일 기본 CPU
```

인스턴스: `res://fx/particles/coin_burst.tres`

### 4.3 `GeneratorData` — 엔티티 데이터

```gdscript
# res://schemas/generator_data.gd
class_name GeneratorData
extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D                          # 자산을 데이터가 소유(§1.2)
@export var base_cost: float = 10.0
@export var cost_growth: float = 1.15
@export var base_output: float = 1.0
@export var tick_interval: float = 1.0
@export var on_buy_sfx: SfxClip                      # Resource 참조 체인
@export var on_buy_fx: FxEffect
```

인스턴스: `res://features/generators/data/gen_01_miner.tres`

**Flyweight 효과**: 여러 생성기가 같은 `SfxClip`을 참조해도 실제 `AudioStream`은 하나만 메모리에 존재.

### 4.4 `AssetLibrary` — 횡단 자산 매니페스트

```gdscript
# res://schemas/asset_library.gd
class_name AssetLibrary
extends Resource

@export var icons: Dictionary[StringName, Texture2D] = {}
@export var fonts: Dictionary[StringName, Font] = {}
@export var gradients: Dictionary[StringName, Texture2D] = {}
```

**주의**: `SfxClip`과 `FxEffect`는 AssetLibrary에 넣지 않는다 — 각각의 Director가 컬렉션을 소유(§5.2, §5.3). 타입드 Dictionary 저장 이슈(#101288)도 있어 단순 Texture/Font만 담는다.

---

## 5. Layer 3 — 런타임 서비스(Autoloads)

### 5.1 `EventBus` — 로직 없는 시그널 허브

**원칙**: 이 파일은 `signal` 선언과 한 줄 주석만 있다. 메서드/상태 금지.

```gdscript
# res://autoloads/event_bus.gd
extends Node

# 경제
signal currency_changed(currency_id: StringName, amount: float)
signal generator_purchased(gen_id: StringName, new_level: int)
signal generator_ticked(gen_id: StringName, produced: float)

# 업그레이드/프레스티지
signal upgrade_applied(upgrade_id: StringName)
signal prestige_reset

# UI/시스템
signal scene_change_requested(path: String)
signal save_completed
signal error_raised(code: StringName, message: String)
```

**왜 이렇게 마른가**: 누가 무엇을 알리는지, 누가 무엇에 반응하는지 이 파일 하나만 읽으면 파악된다. 디버깅·AI 탐색 모두 유리.

### 5.2 `SfxDirector` — 사운드 재생 + 풀 + 이벤트 바인딩

```gdscript
# res://autoloads/sfx_director.gd
extends Node

const CLIPS_DIR := "res://audio/clips/"

var _clips: Dictionary[StringName, SfxClip] = {}
var _players: Dictionary[StringName, Array] = {}   # bus → AudioStreamPlayer 풀

func _ready() -> void:
    _scan_clips()
    _init_pools([&"SFX", &"UI"], 8)
    _bind_events()

func _scan_clips() -> void:
    var dir := DirAccess.open(CLIPS_DIR)
    if dir == null: return
    for f in dir.get_files():
        if not f.ends_with(".tres"): continue
        var clip := load(CLIPS_DIR.path_join(f)) as SfxClip
        if clip and clip.id != &"":
            _clips[clip.id] = clip

func _init_pools(buses: Array[StringName], size: int) -> void:
    for bus in buses:
        var arr: Array = []
        for i in size:
            var p := AudioStreamPlayer.new()
            p.bus = bus
            add_child(p)
            arr.append(p)
        _players[bus] = arr

func play(clip_id: StringName) -> void:
    var clip: SfxClip = _clips.get(clip_id)
    if clip == null:
        push_warning("SFX not found: %s" % clip_id)
        return
    var pool: Array = _players.get(clip.bus, [])
    var free_player: AudioStreamPlayer = _find_free(pool)
    if free_player == null: return
    free_player.stream = clip.stream
    free_player.volume_db = clip.volume_db
    free_player.pitch_scale = clip.pitch_scale
    if clip.pitch_jitter > 0.0:
        free_player.pitch_scale += randf_range(-clip.pitch_jitter, clip.pitch_jitter)
    free_player.play()

func _find_free(pool: Array) -> AudioStreamPlayer:
    for p in pool:
        if not p.playing: return p
    return pool[0] if not pool.is_empty() else null  # 없으면 가장 오래된 덮어씀

func _bind_events() -> void:
    # EventBus 이벤트 → SFX 매핑. 이 함수가 "사운드 디자인 문서"가 된다.
    EventBus.generator_purchased.connect(func(_id, _lv): play(&"ui.buy"))
    EventBus.upgrade_applied.connect(func(_id): play(&"upgrade.applied"))
    EventBus.prestige_reset.connect(func(): play(&"prestige.big"))
    EventBus.error_raised.connect(func(_c, _m): play(&"ui.error"))
```

**포인트**:
- 클립은 **폴더 스캔으로 자동 등록** (이전 headless-first 원칙).
- 이벤트 ↔ 사운드 바인딩이 **한 함수(`_bind_events`)에 집약** → AI가 "프레스티지에 새 사운드 추가"를 편집할 곳이 명확.
- 풀링으로 동시재생 제어.

### 5.3 `FxDirector` — 파티클 스폰

```gdscript
# res://autoloads/fx_director.gd
extends Node

const FX_DIR := "res://fx/particles/"

var _effects: Dictionary[StringName, FxEffect] = {}

func _ready() -> void:
    _scan_effects()
    _bind_events()

func _scan_effects() -> void:
    var dir := DirAccess.open(FX_DIR)
    if dir == null: return
    for f in dir.get_files():
        if not f.ends_with(".tres"): continue
        var fx := load(FX_DIR.path_join(f)) as FxEffect
        if fx and fx.id != &"":
            _effects[fx.id] = fx

# 어디에 스폰할지는 호출자가 global_position과 parent를 넘긴다.
func spawn(fx_id: StringName, parent: Node, at: Vector2) -> void:
    var fx: FxEffect = _effects.get(fx_id)
    if fx == null:
        push_warning("FX not found: %s" % fx_id)
        return
    var node: Node2D = _build_particles(fx)
    node.global_position = at
    parent.add_child(node)
    # one_shot이면 자동 해제
    if fx.one_shot:
        var timer := get_tree().create_timer(fx.lifetime + 0.2)
        timer.timeout.connect(node.queue_free)

func _build_particles(fx: FxEffect) -> Node2D:
    if fx.use_gpu:
        var p := GPUParticles2D.new()
        p.process_material = fx.material
        p.texture = fx.texture
        p.amount = fx.amount
        p.lifetime = fx.lifetime
        p.explosiveness = fx.explosiveness
        p.one_shot = fx.one_shot
        p.scale = fx.scale
        p.emitting = true
        return p
    else:
        var p := CPUParticles2D.new()
        # GPU → CPU 설정 복사. ParticleProcessMaterial의 속성을
        # CPUParticles2D 프로퍼티로 매핑하는 헬퍼가 별도 필요.
        # 4.x의 GPUParticles2D.convert_from_particles()에 해당 기능 없음 — 수동 매핑.
        p.amount = fx.amount
        p.lifetime = fx.lifetime
        p.explosiveness = fx.explosiveness
        p.one_shot = fx.one_shot
        p.scale = fx.scale
        p.texture = fx.texture
        p.emitting = true
        return p

func _bind_events() -> void:
    EventBus.upgrade_applied.connect(func(_id): pass)  # UI가 spawn 호출 — 위치 정보 있음
    EventBus.prestige_reset.connect(func(): pass)      # 동일
```

**주의**: FX는 **위치 정보가 필수**. EventBus가 위치를 모르므로, UI 노드가 이벤트를 수신한 뒤 자기 position을 붙여 `FxDirector.spawn(...)`을 직접 호출하는 패턴이 자연스럽다.

### 5.4 `AssetHub` — 나머지 자산의 얇은 파사드

```gdscript
# res://autoloads/asset_hub.gd
extends Node

const LIBRARY_PATH := "res://shared/assets/asset_library.tres"

var _lib: AssetLibrary

func _ready() -> void:
    _lib = load(LIBRARY_PATH) as AssetLibrary
    if _lib == null:
        push_error("AssetLibrary missing at %s" % LIBRARY_PATH)

func icon(key: StringName) -> Texture2D:
    if _lib == null: return null
    return _lib.icons.get(key)

func font(key: StringName) -> Font:
    if _lib == null: return null
    return _lib.fonts.get(key)

func gradient(key: StringName) -> Texture2D:
    if _lib == null: return null
    return _lib.gradients.get(key)

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if _lib == null:
        errors.append("AssetLibrary not loaded")
        return errors
    for k in _lib.icons:
        if _lib.icons[k] == null: errors.append("icon.%s missing" % k)
    return errors
```

**역할 분할**:
- AssetHub = **정적 조회**(아이콘·폰트·그라데이션).
- SfxDirector/FxDirector = **이벤트 구동 재생**.

### 5.5 `AutoLoad` 등록 (`project.godot`)

```ini
[autoload]
GameState="*res://autoloads/game_state.gd"
EventBus="*res://autoloads/event_bus.gd"
AssetHub="*res://autoloads/asset_hub.gd"
SfxDirector="*res://autoloads/sfx_director.gd"
FxDirector="*res://autoloads/fx_director.gd"
SceneLoader="*res://autoloads/scene_loader.gd"
```

**순서 중요**: EventBus가 다른 서비스보다 먼저 오도록. SceneLoader는 마지막(다른 서비스가 준비된 뒤 첫 전환).

---

## 6. 데이터 흐름 — 한 프레임 시나리오

사용자가 "광부 구매" 버튼을 눌렀을 때:

```
[GeneratorRow(UI)]
  .on_buy_pressed()
  └─► GameState.try_purchase(&"gen_01_miner")
        ├─► (재화 차감)
        ├─► EventBus.currency_changed.emit(...)   ┐
        └─► EventBus.generator_purchased.emit(...)│
                  │                                │
          ┌───────┴─────────────┐                  │
          ▼                     ▼                  ▼
      [SfxDirector]         [FxDirector]      [UI 전체]
      play(&"ui.buy")       (위치 없음 → skip)  currency_label 업데이트

[GeneratorRow] 자체가 generator_purchased 수신 →
       FxDirector.spawn(&"coin_burst", self, global_position)  (UI가 위치 제공)
```

- **UI ↔ GameState**: 직접 메서드 호출 (down → direct).
- **GameState → 모두**: EventBus (up/broadcast).
- **위치 필요한 FX**: 수신자(UI)가 직접 Director 호출.

이 흐름은 **"data down, events up" 원칙**의 교과서적 적용.

---

## 7. AI 작업 수순 — "새 생성기 '정제소' 추가"를 예로

1. **데이터 생성** (AI가 텍스트로):
   - `res://features/generators/data/gen_02_refinery.tres` — `GeneratorData` 인스턴스
   - 필요한 `SfxClip`이 없으면 `res://audio/clips/refinery_tick.tres` 작성
   - 필요한 `FxEffect`가 없으면 `res://fx/particles/refinery_glow.tres` 작성

2. **자산 요청 (없으면)**:
   - 아이콘 `res://features/generators/assets/refinery.svg` 스펙을 사용자에게 통보
   - 그 자리에 `PlaceholderTexture2D.tres`를 먼저 배치해 프로토타입 작동

3. **스크립트 변경 없음** — 폴더 스캔이 자동으로 로드.

4. **(선택) EventBus 바인딩 추가**: SfxDirector `_bind_events()`에 새 매핑 한 줄.

5. **헤드리스 검증**:
   ```bash
   godot --path star-reach --headless --quit-after 2
   godot --path star-reach --headless --script res://tools/smoke_test.gd
   ```

6. **사용자에게**: "F5 실행해 확인 부탁드립니다."

→ **코드 수정 0 ~ 1줄**, **에디터 클릭 0회**, **피처 하나에 집중**.

---

## 8. 헤드리스 도구 스크립트들

`tools/`에 미리 만들어둘 빌드/검증 유틸.

### 8.1 `build_asset_manifest.gd`

`shared/assets/icons/`·`fonts/`·`gradients/`를 스캔해 `asset_library.tres` 생성.

```gdscript
# res://tools/build_asset_manifest.gd
@tool
extends SceneTree

func _init() -> void:
    var lib := preload("res://schemas/asset_library.gd").new() as AssetLibrary
    _scan("res://shared/assets/icons/", lib.icons, ["png", "svg", "webp"])
    _scan("res://shared/fonts/",        lib.fonts, ["ttf", "otf"])
    _scan("res://shared/assets/textures/gradients/", lib.gradients, ["tres"])
    var err := ResourceSaver.save(lib, "res://shared/assets/asset_library.tres")
    assert(err == OK)
    print("Manifest: %d icons / %d fonts" % [lib.icons.size(), lib.fonts.size()])
    quit()

func _scan(dir_path: String, out: Dictionary, exts: Array[String]) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null: return
    for f in dir.get_files():
        var ext := f.get_extension().to_lower()
        if exts.has(ext):
            out[StringName(f.get_basename())] = load(dir_path.path_join(f))
```

### 8.2 `normalize_imports.gd`
2D UI 아이콘: Lossless, mipmap off, fix_alpha_border on.

### 8.3 `smoke_test.gd`
- AssetLibrary 로드 → validate()
- 주요 씬(splash, main_menu, generator_panel) load/instantiate
- SfxDirector/FxDirector의 `_scan_*` 결과 개수 확인 (예: 5개 이상)

### 8.4 CI 호출
```bash
# .github/workflows/ci.yml (예시 스케치)
godot --path star-reach --headless --quit-after 2
godot --path star-reach --headless --script res://tools/build_asset_manifest.gd
godot --path star-reach --headless --script res://tools/smoke_test.gd
```

---

## 9. 각 Godot 패턴이 이 설계에서 하는 일 (매핑표)

| Godot 패턴 | 이 설계의 사용처 |
|---|---|
| **Custom Resource (class_name)** | `GeneratorData`, `SfxClip`, `FxEffect`, `AssetLibrary` |
| **Autoload Singleton** | `GameState`, `EventBus`, `AssetHub`, `SfxDirector`, `FxDirector`, `SceneLoader` |
| **Event Bus** | `EventBus` (로직 0, 시그널만) |
| **Observer** | UI ↔ GameState 값 구독 |
| **Flyweight** | 여러 `GeneratorData.tres`가 같은 `SfxClip.tres` 공유 |
| **Factory** | `FxDirector.spawn()`이 `GPUParticles2D` 인스턴스 생성 |
| **Composition** | `features/generators/generator_row.tscn` 재사용 |
| **Data-Driven** | 밸런싱 전체를 `.tres`로 분리 (하드코딩 0) |
| **@tool / Headless Build** | `tools/build_*.gd`가 `.tres` 생성 |
| **Theme** | UI 기본 스타일의 빌트인 레지스트리 |
| **ResourceUID** | 파일 이동에도 참조 유지 (엔진 자동) |

---

## 10. 안티패턴 체크리스트

다음을 피한다.

- ❌ AssetHub에 모든 자산 몰아넣기 — 엔티티 자산은 엔티티 `.tres`가 소유
- ❌ EventBus에 메서드/상태 추가 — 시그널만
- ❌ 씬이 GameState 필드를 직접 쓰기 — 시그널 구독 또는 메서드 호출
- ❌ UI 노드가 AudioStreamPlayer를 자기 자식으로 두고 play — SfxDirector 사용
- ❌ 하드코딩된 파일 경로 문자열 스캐터 — `preload()` 또는 키 조회
- ❌ `.tscn`의 `[connection]` 섹션에 의존 — 코드 `connect()` 사용
- ❌ `.uid` gitignore
- ❌ 생성기별로 스크립트 만들기 — `GeneratorData.tres` + 범용 `GeneratorRow` 하나

---

## 11. 점진적 구축 로드맵

이 설계를 한 번에 다 만들지 말 것. 피처가 생겨야 패턴이 필요해진다.

**Phase 0 — 스켈레톤** (파일 몇 개):
- `project.godot` 업데이트 (autoload 등록, stretch 설정)
- `autoloads/event_bus.gd` (빈 시그널 3~4개)
- `autoloads/game_state.gd` (재화 1종 + tick)
- `features/splash/` (로고 + 3초 후 main_menu 전환)
- `features/main_menu/` (빈 컨테이너 + 버튼 하나)

**Phase 1 — 첫 생성기**:
- `schemas/generator_data.gd` + 인스턴스 1개
- `features/generators/generator_row.tscn` + `generator_panel.tscn`
- GameState의 purchase/tick 로직
- **여기까진 SFX/FX 없어도 됨**

**Phase 2 — 사운드/FX**:
- `schemas/sfx_clip.gd` + `fx_effect.gd`
- `autoloads/sfx_director.gd` + `fx_director.gd`
- 클립 2~3개만 넣고 검증

**Phase 3 — 확장**:
- AssetHub + asset_library 매니페스트
- 업그레이드/프레스티지 피처

---

## 12. 의사결정 요약 (빠른 참조)

| 질문 | 답 |
|---|---|
| 새 게임 데이터 어디에 두나 | `schemas/*.gd`에 스키마 정의, `features/<f>/data/*.tres`에 인스턴스 |
| 새 SFX 어떻게 추가 | `audio/sfx/`에 원본 + `audio/clips/<id>.tres`에 `SfxClip`. 스캔이 자동 등록 |
| 새 파티클 어떻게 추가 | `fx/particles/<id>.tres`에 `FxEffect`. UI가 `FxDirector.spawn()` 호출 |
| 전역 아이콘 하나 추가 | `shared/assets/icons/<name>.svg` 드롭 + 빌드 스크립트 재실행 |
| 새 전역 이벤트 | `EventBus.gd`에 `signal` 한 줄 |
| UI 스타일 일괄 변경 | `ui/theme/main_theme.tres` 편집 |
| 파티클 튜닝 | 에디터로 재생하며 값 조정 → `.tres` 자동 저장 |
| 씬 구조 수정 | `godot-scene-surgeon` 경유 |

---

## 13. 다음 단계

이 설계를 실제 `star-reach/` 프로젝트에 **Phase 0 수준으로 스캐폴딩**할 준비가 됐습니다. 진행할 단계는:

1. 폴더 구조 + 빈 autoload 파일 생성
2. `project.godot`에 autoload/stretch/orientation 적용
3. `schemas/*.gd` 스키마 최소 버전
4. `tools/build_asset_manifest.gd` + `tools/smoke_test.gd`
5. `--headless --quit-after 2` + smoke_test 통과 확인

진행하려면 지시만 주세요. 한 번에 다 만들지, Phase 단위로 나눠 진행할지도 선택 가능.
