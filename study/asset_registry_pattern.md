# 리소스 ID 레지스트리(Asset Registry) — Godot 4에서의 설계

**질문**: 이진 자산의 ID를 관리하는 매니저를 만들어 어디서든 꺼내 쓰는 구조가 가능한가?

**짧은 답**: 가능합니다. 단, Godot에는 이미 **UID + `@export` + Custom Resource**로 "레지스트리에 상당하는 것"이 내장되어 있으니, **"모든 걸 중앙 매니저로 중앙화"하지 말고 "중앙화가 이득인 영역만 선별 적용"하는 것**이 관용적입니다. 이 문서는 세 층위로 구분해 설명합니다:

1. Godot가 이미 제공하는 내장 레지스트리(`ResourceUID`, `@export`, Custom Resource)
2. 커스텀 레지스트리가 실제로 필요해지는 지점
3. StarReach에 맞춘 구체 설계 + 코드 예제

---

## 1. 먼저 내장된 것부터 — Godot의 "이미 있는 레지스트리"

### 1.1 ResourceUID — 엔진이 관리하는 글로벌 ID 테이블

Godot 4.4+는 프로젝트의 **모든 리소스에 고유 UID**(`uid://bxxxxx`)를 자동 부여하고, 내부적으로 `ResourceUID` 싱글턴에 등록합니다. 이건 이미 "중앙 레지스트리"입니다.

```gdscript
# UID ↔ 경로 변환 API (Godot 내장)
ResourceUID.text_to_id("uid://b5k2x7...") -> int
ResourceUID.id_to_text(id: int) -> String
ResourceUID.has_id(id: int) -> bool
ResourceUID.get_id_path(id: int) -> String
ResourceUID.add_id(id, path), ResourceUID.set_id(id, path)

# 로드
load("uid://b5k2x7...")   # 경로 대신 UID로 로드 가능
```

**주의**: 익스포트 빌드에서 UID 테이블이 일부 누락되는 이슈(#75617)가 있었음 — 4.4 이후 개선. `.uid` 사이드카를 **커밋 필수**.

→ 결론: **"경로가 바뀌어도 참조가 살아있는가"**라는 목적이라면 추가 레지스트리 불필요. Godot가 이미 해결.

### 1.2 `@export` + Custom Resource — 데이터가 자산을 소유하는 방식

Godot의 관용 패턴은 "**레지스트리에서 찾아 쓴다**"가 아니라 "**데이터 엔티티가 자산을 직접 참조한다**"입니다.

```gdscript
# res://features/generators/generator_data.gd
class_name GeneratorData
extends Resource

@export var id: StringName
@export var display_name: String
@export var base_cost: float
@export var icon: Texture2D          # ← 자산 슬롯
@export var tick_sfx: AudioStream     # ← 자산 슬롯
@export var buy_fx: ParticleProcessMaterial  # ← 자산 슬롯
```

각 생성기의 `.tres`(`gen_01_miner.tres` 등)를 만들고, 에디터에서 아이콘·사운드·파티클을 **드래그로 연결**. 런타임에 `gen_data.icon`으로 바로 접근.

**장점**: 타입 안전, 에디터 미리보기, "이 생성기에 어떤 자산이 쓰이는가"가 한 눈에. Refactoring 시 UID가 따라옴.

**단점**: 자산을 동적으로 교체하려면 코드가 필요. "전체 아이콘 목록" 같은 횡단 쿼리 불가.

### 1.3 Theme — UI 자산의 빌트인 레지스트리

UI 영역은 이미 `Theme` 리소스가 레지스트리 역할. 폰트·StyleBox·아이콘·색상을 이름으로 등록하고 Control에서 키로 조회:

```gdscript
var close_icon: Texture2D = theme.get_icon("close", "Dialog")
var header_font: Font = theme.get_font("heading", "Label")
```

→ **UI 아이콘만을 위한 별도 레지스트리는 대부분 불필요**. Theme에 넣자.

---

## 2. 그래서 언제 커스텀 레지스트리가 필요한가?

`@export` / Theme / UID만으로 **풀 수 없는 요구**가 생기면 레지스트리를 만듭니다. 실제 트리거는 다음 5가지:

| 상황 | 이유 | 예 |
|---|---|---|
| **문자열 키로 동적 조회** | 세이브파일/서버 데이터에서 "`"coin"` 아이콘을 달라"를 그대로 처리 | 업적 `achievement_id: "first_prestige"` → 아이콘 룩업 |
| **이벤트 기반 재생** | EventBus가 `upgrade_applied` 신호를 내면 관련 SFX/FX를 재생 | `SfxLibrary.play("upgrade_applied")` |
| **횡단 자산 쿼리** | "이 빌드에 포함된 모든 파티클을 나열" — 디버그/감사 | 개발 콘솔, QA 대시보드 |
| **사전 로드(preload warmup)** | 스플래시/로딩 스크린에서 자산을 한 번에 백그라운드 로드 | `AssetHub.warmup(["icons", "sfx"])` |
| **핫스왑·리스킨** | 테마/시즌별로 자산 세트를 통째 교체 | 크리스마스 스킨 팩 |

StarReach(증분 시뮬)는 **2, 4번**이 현실적으로 자주 필요합니다. 1, 3, 5번은 기능 확장 시 고려.

---

## 3. 설계 — 3계층 권장 구조

**핵심 방침: "데이터가 자산을 소유"는 그대로 두고, 그 위에 "명명된 공용 자산의 얇은 레지스트리"만 추가**.

### 3.1 계층 개요

```
┌─────────────────────────────────────────────────────┐
│  AssetHub (Autoload, GDScript singleton)            │  ← 얇은 파사드
│    · warmup() / get_texture(key) / play_sfx(key)    │
└─────────────────┬───────────────────────────────────┘
                  │ holds
                  ▼
┌─────────────────────────────────────────────────────┐
│  AssetLibrary.tres  (custom Resource)               │  ← 데이터
│    · icons:    Dictionary[StringName, Texture2D]    │
│    · sfx:      Dictionary[StringName, AudioStream]  │
│    · fx:       Dictionary[StringName, ...]          │
└─────────────────────────────────────────────────────┘
          ▲
          │ 참조 (@export) — 에디터에서 드래그 등록
          │
  res://assets/icons/coin.png, res://audio/sfx/click.wav, ...
```

동시에, **개별 엔티티의 자산**은 그 엔티티의 `.tres`가 계속 직접 소유합니다 (§1.2).

### 3.2 AssetLibrary — 데이터 Resource

```gdscript
# res://shared/assets/asset_library.gd
class_name AssetLibrary
extends Resource

@export var icons: Dictionary[StringName, Texture2D] = {}
@export var sfx: Dictionary[StringName, AudioStream] = {}
@export var particles: Dictionary[StringName, ParticleProcessMaterial] = {}
@export var fonts: Dictionary[StringName, Font] = {}
```

> **Godot 4.4+의 타입드 Dictionary**(`Dictionary[K, V]`)는 `class_name`이 지정된 타입을 키/값에 사용할 수 있지만, 일부 버전에서 저장 이슈(#101288)가 보고됨. 문제가 나면 `Dictionary`(비타입드)로 폴백하고 런타임 검증을 추가.

`res://shared/assets/asset_library.tres`를 만들어 에디터에서 자산을 드래그 등록:

```tres
[gd_resource type="Resource" script_class="AssetLibrary" load_steps=4 format=3 uid="uid://..."]
[ext_resource type="Script" path="res://shared/assets/asset_library.gd" id="1"]
[ext_resource type="Texture2D" uid="uid://c_coin" path="res://assets/icons/coin.png" id="2"]
[ext_resource type="AudioStream" uid="uid://a_click" path="res://audio/sfx/click.wav" id="3"]
[resource]
script = ExtResource("1")
icons = { &"coin": ExtResource("2") }
sfx   = { &"ui.click": ExtResource("3") }
```

### 3.3 AssetHub — 오토로드 파사드

```gdscript
# res://autoloads/asset_hub.gd
extends Node

const LIBRARY_PATH: String = "res://shared/assets/asset_library.tres"

var _lib: AssetLibrary
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0

func _ready() -> void:
    _lib = load(LIBRARY_PATH) as AssetLibrary
    assert(_lib != null, "AssetLibrary not found: %s" % LIBRARY_PATH)
    _init_sfx_pool(8)

func icon(key: StringName) -> Texture2D:
    var t: Texture2D = _lib.icons.get(key)
    if t == null:
        push_warning("Missing icon key: %s" % key)
    return t

func sfx(key: StringName) -> AudioStream:
    return _lib.sfx.get(key)

func play_sfx(key: StringName, volume_db: float = 0.0) -> void:
    var stream: AudioStream = sfx(key)
    if stream == null:
        return
    var p: AudioStreamPlayer = _sfx_players[_sfx_cursor]
    _sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
    p.stream = stream
    p.volume_db = volume_db
    p.play()

func particle(key: StringName) -> ParticleProcessMaterial:
    return _lib.particles.get(key)

# 스플래시/로딩 시 특정 카테고리만 미리 로드
func warmup(_categories: Array[StringName]) -> void:
    # AssetLibrary가 load()된 시점에 참조된 자산은 이미 로드됨.
    # 대형 자산을 지연 로드하는 경우 여기서 ResourceLoader.load_threaded_request 호출.
    pass

func _init_sfx_pool(size: int) -> void:
    for i in size:
        var p: AudioStreamPlayer = AudioStreamPlayer.new()
        p.bus = &"SFX"
        add_child(p)
        _sfx_players.append(p)
```

**사용부**:
```gdscript
# 아이콘 바인딩
$CoinLabel/Icon.texture = AssetHub.icon(&"coin")

# SFX 재생 (EventBus 연결)
EventBus.upgrade_applied.connect(func(): AssetHub.play_sfx(&"upgrade.applied"))

# 파티클 구성
$Burst.process_material = AssetHub.particle(&"coin_burst")
```

### 3.4 왜 이 구조가 `@export`를 대체하지 않는가

이 레지스트리는 **"여러 곳에서 이름으로 불러야 하는 공용 자산"**만 다룹니다. 예:

| 상황 | 권장 방식 |
|---|---|
| 각 생성기 `.tres`의 고유 아이콘/SFX | **`@export`** (데이터가 자산 소유) |
| UI Theme의 버튼/폰트 | **`Theme.tres`** (내장 레지스트리) |
| "클릭", "획득", "실패" 같은 범용 SFX | **AssetHub** (문자열 키) |
| 업적 ID → 아이콘 매핑 | **AssetHub** (문자열 키) |
| 생성기 1~30 각각의 아이콘 | **각 `.tres`의 `@export`** — AssetHub에 넣지 말 것 |

AssetHub를 **dumping ground**로 쓰면 금방 수백 키짜리 `Dictionary`가 되고, 누가 어디서 쓰는지 추적 불가능해집니다.

---

## 4. 스플래시 로딩과의 통합

이전 study 문서(`splash_and_async_loading.md`)의 `ResourceLoader.load_threaded_request` 패턴과 자연스럽게 연결:

```gdscript
# splash.gd
func _ready() -> void:
    # AssetLibrary는 load()로 동기 로드되지만 참조 자산이 많으면 스플래시에서 백그라운드로.
    ResourceLoader.load_threaded_request(AssetHub.LIBRARY_PATH, "AssetLibrary", true)

func _process(_d: float) -> void:
    var status: int = ResourceLoader.load_threaded_get_status(AssetHub.LIBRARY_PATH, _progress)
    ...
```

단, `use_sub_threads = true`로 두면 AssetLibrary가 참조하는 텍스처·사운드까지 **하위 리소스로 함께 병렬 로드**됩니다 — 스플래시가 끝나는 시점에 핫 캐시 완성.

---

## 5. 카테고리 분할 전략 (라이브러리를 여럿으로)

자산이 많아지면 한 `.tres`가 무거워집니다. 카테고리별로 쪼개세요:

```
res://shared/assets/
├── ui_icons.tres        (AssetLibrary, icons만)
├── ui_sfx.tres          (AssetLibrary, sfx만)
├── fx_particles.tres    (AssetLibrary, particles만)
└── seasonal_winter.tres (위 3개의 교체판 — 스킨)
```

AssetHub는 카테고리별 `@export` 슬롯을 가지거나, 런타임에 `_lib`을 교체하는 `swap_library(path)` 메서드를 제공.

---

## 6. 에디터 지원 (@tool로 자동 채움)

큰 프로젝트에서는 AssetLibrary에 일일이 드래그하는 것도 부담. `@tool` 스크립트로 폴더를 스캔해 자동 등록:

```gdscript
# res://shared/assets/asset_library.gd
@tool
class_name AssetLibrary
extends Resource

@export var icons: Dictionary[StringName, Texture2D] = {}
@export var scan_icons_folder: String = ""

@export_tool_button("Scan icons folder") var _scan_btn = _scan_icons

func _scan_icons() -> void:
    if scan_icons_folder.is_empty():
        return
    icons.clear()
    var dir: DirAccess = DirAccess.open(scan_icons_folder)
    for fname in dir.get_files():
        if fname.ends_with(".png") or fname.ends_with(".svg"):
            var key: StringName = fname.get_basename()
            icons[key] = load(scan_icons_folder.path_join(fname))
    emit_changed()
    ResourceSaver.save(self)
```

- 에디터에서 "Scan icons folder" 버튼 클릭 → 폴더의 모든 PNG/SVG를 파일명 키로 등록.
- AI가 새 아이콘을 폴더에 추가한 뒤 이 버튼만 눌러달라고 요청하면 됨.

---

## 7. 런타임 검증

배포 직전에 "**등록된 모든 키가 유효한가**" 체크:

```gdscript
# AssetHub.gd 말미에
func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    for k in _lib.icons:
        if _lib.icons[k] == null:
            errors.append("icon.%s = null" % k)
    for k in _lib.sfx:
        if _lib.sfx[k] == null:
            errors.append("sfx.%s = null" % k)
    return errors
```

릴리스 빌드의 `_ready()`에서 호출해 로그 출력하거나, 디버그 빌드에서는 `assert()`로 즉시 실패.

---

## 8. AI(에이전트) 관점의 추가 이점

이 패턴이 **에이전트 개발에 특히 어울리는 이유**:

1. **문자열 키가 AI에게 안정적**: 파일 경로는 리팩터링으로 바뀌지만, `&"coin"` 키는 안 바뀜. AI가 작성한 스크립트가 수명이 길어짐.
2. **단일 매니페스트 감사 가능**: AI가 새 기능을 추가할 때 `asset_library.tres`만 열어 "어떤 키가 이미 있는가"를 볼 수 있음.
3. **사람-AI 역할 분리**: 사람은 `.tres`에 자산을 드래그 등록(UI 작업), AI는 스크립트에서 키로 참조(코드 작업). 충돌 영역이 최소.
4. **Placeholder 전환 용이**: AI가 먼저 `PlaceholderTexture2D`로 키를 채워 동작하는 프로토타입을 만들고, 사람이 나중에 실제 자산으로 교체. 소비 코드는 변경 불필요.

---

## 9. 주의사항 / 안티패턴

- **모든 엔티티 자산을 AssetHub에 넣지 말 것** — 생성기 30개의 아이콘을 키 30개로 넣느니 `GeneratorData.tres` 30개의 `@export var icon`으로 두는 편이 낫다.
- **타입드 Dictionary 버전 이슈**: 4.4+에서도 일부 엣지 케이스 보고(#101288, #109574). 저장 불안정 시 `Dictionary` 비타입드로 폴백 + 런타임 타입 검사.
- **순환 참조 금지**: AssetLibrary가 씬(`PackedScene`)을 담으면, 그 씬이 다시 AssetHub를 참조하는 순환이 쉽게 생김. 씬은 별도 `SceneRegistry.tres`로 분리.
- **WeakRef / 언로드 전략 없음**: AssetHub는 참조를 계속 들고 있으므로 로드된 자산은 앱 종료까지 메모리에 상주. 대용량 자산(고해상도 배경, BGM)은 AssetHub에 넣지 말고 on-demand 로드.
- **Autoload 과다**: GameState, EventBus, SceneLoader에 이어 AssetHub까지면 이미 4개. 더 늘어나면 응집도 재검토.

---

## 10. 결정 가이드 — "내 자산, 어디에 둬야 하나"

| 질문 | YES → | NO → |
|---|---|---|
| 한 엔티티에 전속인가? | 엔티티 `.tres` `@export` | 아래로 |
| UI 위젯의 기본 스타일링인가? | `Theme.tres` | 아래로 |
| 여러 스크립트에서 문자열 키로 부를까? | `AssetHub`/`AssetLibrary` | 아래로 |
| 런타임 동적 로드 필요? | `ResourceLoader.load_threaded_*` | `preload()` |

---

## 11. 요약

- **Godot에 이미 UID 레지스트리가 있다** — 경로 불변성 문제는 그걸로 해결.
- **엔티티 데이터는 `@export`로 자산을 직접 소유**한다 (Godot 관용).
- **횡단·범용·이벤트 기반 자산만** 커스텀 레지스트리(`AssetLibrary.tres` + `AssetHub` 오토로드)로 중앙화.
- **AI 친화적**: 문자열 키로 안정적 참조, Placeholder 전환 용이, 자산 감사 가능.
- **안티패턴 경계**: 모든 걸 레지스트리로 밀어넣지 말 것.

---

## 12. 참고 자료

- [Singletons (Autoload) — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)
- [Autoloads versus regular nodes — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_internal_nodes.html)
- [ResourceUID class reference](https://docs.godotengine.org/en/stable/classes/class_resourceuid.html)
- [UID changes coming to Godot 4.4 — Godot blog](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/)
- [Custom Resources are OP in Godot 4 — Ezcha](https://ezcha.net/news/3-1-23-custom-resources-are-op-in-godot-4)
- [Custom Resources in Godot 4 — Simon Dalvai](https://simondalvai.org/blog/godot-custom-resources/)
- 이슈: [Typed Dictionary values not saving on custom Resources (#101288)](https://github.com/godotengine/godot/issues/101288)
