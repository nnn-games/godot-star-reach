# 에디터 사용 최소화 — Headless-First Agent 워크플로우

**목표**: 에이전트 개발에서 Godot 에디터를 **F5 플레이 테스트 외에는 거의 쓰지 않는** 워크플로우를 만든다. 인스펙터 드래그, Layout 메뉴 클릭, "Scan folder" 버튼 누르기 — 모두 제거 가능한지, 제거한다면 어떻게 하는지 정리.

이 문서는 앞선 네 study 문서(`splash_and_async_loading`, `mobile_ui_resize`, `asset_pipeline_for_agent_dev`, `asset_registry_pattern`)의 **설계를 headless-first로 재조정**한다.

---

## 0. 에디터가 하는 일 — 무엇을 대체해야 하나

| 에디터 작업 | Headless 대체 |
|---|---|
| 리소스 임포트 (`.png` → `.ctex`) | `godot --headless --import` |
| UID 생성 (`.uid`, 헤더) | `godot --headless --import` (자동 생성) |
| `.tscn` 노드 편집 | 텍스트 편집 + `godot-scene-surgeon` 또는 프로그래매틱 `PackedScene.pack()` |
| 인스펙터에서 자산 드래그 | 텍스트 `.tres` 편집 또는 컨벤션 기반 오토 등록 |
| Layout 메뉴 클릭(Full Rect 등) | `.tscn`에 `anchor_*` 값 직접 기입 |
| Project Settings UI | `project.godot` INI 직접 편집 |
| AutoLoad 등록 UI | `project.godot`의 `[autoload]` 섹션 직접 편집 |
| 신호 연결 "Connect" 다이얼로그 | 코드에서 `signal.connect()` |
| 씬 실행(F5) | **에디터 필요** (플레이 테스트는 대체 불가) |
| 파티클 실시간 튜닝 | 로직상 불가피 시 에디터 — 하지만 값은 `.tres`로 저장해 텍스트 버전 관리 |

→ **유일하게 에디터가 필수인 것은 "시각 검증(F5)"과 "실시간 파티클/애니메이션 튜닝"** 정도. 나머지는 전부 텍스트·CLI로 가능.

---

## 1. Godot CLI — 반드시 외워야 하는 명령 5개

이전 study 문서에서 소개한 명령들을 **headless 중심**으로 재정리. `godot` 명령이 PATH에 없다면 `C:\Godot\Godot_v4.6-stable_win64.exe --headless ...` 절대 경로 사용.

```bash
# 1) 임포트 + UID 생성 + 검증 (가장 중요)
#    --quit 또는 --quit-after 1 에는 버그 있음 → --quit-after 2 권장 (이슈 #77508)
godot --path star-reach --headless --quit-after 2

# 2) 스크립트 신택스 체크 (CI에서 pre-commit)
godot --path star-reach --check-only res://path/to/script.gd

# 3) 헤드리스에서 스크립트 실행 (리소스 제너레이터, 매니페스트 빌더, 테스트)
godot --path star-reach --headless --script res://tools/build_manifest.gd

# 4) 익스포트 (미리 한 번은 에디터로 열어 .godot 폴더가 있어야 함 — 이슈 #71521)
godot --path star-reach --headless --export-release "Android" build/star-reach.apk

# 5) 에디터 시작 (F5 플레이만을 위해)
godot --path star-reach
```

### 1.1 첫 개장 함정

- **프로젝트가 한 번도 에디터로 열린 적 없으면** `.godot/` 폴더가 없어 임포트·익스포트가 실패(#71521). **최초 1회는 에디터에서 열어야 함**.
- 이후는 완전 CLI로 돌릴 수 있다.

### 1.2 `--import`의 대안 — `--quit-after 2`

공식 `--import` 플래그도 있지만, 실환경에서는 `--headless --quit-after 2`가 더 안정적이라는 사용자 보고가 많음. 의미상: 엔진이 부팅하고 임포트 큐를 비운 뒤 종료.

---

## 2. 텍스트로 모든 `.tscn` 쓰기 — 프로그래매틱 vs 직접 편집

`.tscn`은 사람이 읽을 수 있는 INI 계열 포맷이지만 `load_steps`/`ExtResource`/`SubResource` id 관리가 까다롭다. 두 가지 전략.

### 2.1 전략 A — **텍스트 직접 편집** (소규모 정적 씬)

```tscn
[gd_scene load_steps=3 format=3 uid="uid://b_splash_1"]

[ext_resource type="Script" path="res://features/splash/splash.gd" id="1"]
[ext_resource type="Texture2D" uid="uid://b_logo" path="res://assets/logo.png" id="2"]

[node name="Splash" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Logo" type="TextureRect" parent="."]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -128.0
offset_top = -128.0
offset_right = 128.0
offset_bottom = 128.0
texture = ExtResource("2")
```

- `load_steps`는 `ExtResource + SubResource` 합산. 틀리면 경고는 뜨나 작동은 함.
- `ExtResource` id는 문자열. UID는 리소스 자체에 보관.
- **AI가 수정 시 `godot-scene-surgeon` 서브에이전트를 반드시 경유** (루트 CLAUDE.md에 이미 명시).

### 2.2 전략 B — **프로그래매틱 생성** (복잡·동적 씬)

```gdscript
# res://tools/gen_main_menu.gd
@tool
extends SceneTree

func _init() -> void:
    var root: Control = Control.new()
    root.name = "MainMenu"
    root.anchor_right = 1.0
    root.anchor_bottom = 1.0

    var vbox: VBoxContainer = VBoxContainer.new()
    vbox.name = "Buttons"
    root.add_child(vbox)
    vbox.owner = root   # owner 설정해야 pack()에 포함됨

    for label in ["Play", "Options", "Quit"]:
        var btn: Button = Button.new()
        btn.text = label
        btn.name = label
        vbox.add_child(btn)
        btn.owner = root

    var packed: PackedScene = PackedScene.new()
    var err: int = packed.pack(root)
    assert(err == OK)
    ResourceSaver.save(packed, "res://features/main_menu/main_menu.tscn")
    quit()
```

실행:
```bash
godot --path star-reach --headless --script res://tools/gen_main_menu.gd
```

- **`owner` 설정이 핵심**: `pack()`은 root 자신과 root를 `owner`로 가진 노드만 저장. 안 설정하면 빈 씬이 됨.
- 한번 생성된 `.tscn`은 이후 직접 편집으로 유지보수 가능.
- 복잡한 UI를 빠르게 스캐폴딩할 때, 또는 절차적으로 생성되는 씬(예: 30개 생성기 UI)에 유효.

### 2.3 추가 — 절대 씬 파일로 저장하지 않는 선택지

"**씬 파일을 아예 만들지 않고 런타임 코드로만 구성**"도 가능.

```gdscript
# main.gd — 프로젝트의 main_scene
extends Node

func _ready() -> void:
    var hud: Control = HudBuilder.build()
    add_child(hud)
```

단점: 에디터에서 씬 미리보기 불가, 디자이너 협업 어려움.
장점: `.tscn`의 id 관리 문제 자체가 사라짐. 버전 관리도 단순 `.gd`.

**권장**: 루트 프레임(예: `main.tscn`, `splash.tscn`)만 `.tscn`으로 남기고, 내부 세부 UI는 **코드 빌더**로 구성.

---

## 3. 리소스 드래그 대신 — 컨벤션 기반 오토 등록

이전 `asset_registry_pattern.md`의 "AssetLibrary.tres + 에디터 드래그" 방식은 **에디터 클릭을 요구**한다. Headless-first에서는 대체한다.

### 3.1 방식 1 — 런타임 폴더 스캔 (가장 간단)

AssetHub가 앱 부팅 시 정해진 폴더를 **스캔해서 파일명을 키로 등록**.

```gdscript
# res://autoloads/asset_hub.gd
extends Node

var icons: Dictionary[StringName, Texture2D] = {}
var sfx: Dictionary[StringName, AudioStream] = {}

const ICONS_DIR := "res://assets/icons/"
const SFX_DIR := "res://audio/sfx/"

func _ready() -> void:
    _scan(ICONS_DIR, icons, ["png", "svg", "webp"])
    _scan(SFX_DIR, sfx, ["wav", "ogg", "mp3"])

func _scan(dir_path: String, out: Dictionary, exts: Array[String]) -> void:
    var dir: DirAccess = DirAccess.open(dir_path)
    if dir == null:
        push_error("Dir not found: %s" % dir_path)
        return
    dir.list_dir_begin()
    while true:
        var f: String = dir.get_next()
        if f.is_empty(): break
        if dir.current_is_dir(): continue
        if f.ends_with(".import") or f.ends_with(".uid"): continue
        var ext: String = f.get_extension().to_lower()
        if exts.has(ext):
            var res: Resource = load(dir_path.path_join(f))
            if res != null:
                out[StringName(f.get_basename())] = res

func icon(key: StringName) -> Texture2D:   return icons.get(key)
func play_sfx(key: StringName) -> void:     ...  # (pool 구현은 이전 문서 §3.3 참조)
```

**장점**: 에디터 드래그 0. 새 파일을 폴더에 떨어뜨리면 다음 부팅에 자동 등록.
**함정**: 익스포트 빌드에서 `DirAccess`가 `res://`를 나열할 수 있느냐는 플랫폼/버전 이슈가 있음 — 4.x는 기본 제공되지만, 익스포트 프리셋의 **"Include Filter"에 해당 확장자가 포함되어야** 한다. `export_presets.cfg`에서 `include_filter="*.png,*.ogg,*.wav,..."` 확인 필요.

### 3.2 방식 2 — 빌드타임 매니페스트 (익스포트 안전)

런타임 스캔이 불안하면 **빌드 스크립트가 `.tres`를 생성**한다.

```gdscript
# res://tools/build_asset_manifest.gd
@tool
extends SceneTree

const ICONS_DIR := "res://assets/icons/"
const MANIFEST_PATH := "res://shared/assets/asset_library.tres"

func _init() -> void:
    var lib := preload("res://shared/assets/asset_library.gd").new() as AssetLibrary
    _scan_into(ICONS_DIR, lib.icons, ["png", "svg", "webp"])
    # ... sfx, particles 동일 ...
    var err: int = ResourceSaver.save(lib, MANIFEST_PATH)
    assert(err == OK)
    print("Manifest built: %d icons" % lib.icons.size())
    quit()

func _scan_into(dir_path: String, out: Dictionary, exts: Array[String]) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null: return
    for f in dir.get_files():
        var ext: String = f.get_extension().to_lower()
        if exts.has(ext):
            out[StringName(f.get_basename())] = load(dir_path.path_join(f))
```

실행:
```bash
godot --path star-reach --headless --script res://tools/build_asset_manifest.gd
```

매니페스트 `.tres`는 커밋한다 → 런타임에는 `ResourceLoader.load(MANIFEST_PATH)` 한 번으로 끝. 익스포트 호환성 완벽.

**AI 워크플로우**:
1. 사용자가 새 아이콘 `res://assets/icons/gem.png`를 드롭.
2. AI가 `godot --headless --quit-after 2`로 임포트/UID 생성.
3. AI가 `godot --headless --script res://tools/build_asset_manifest.gd`로 매니페스트 재생성.
4. AI가 사용처 스크립트에 `AssetHub.icon(&"gem")` 추가.
5. 사용자가 에디터로 F5.

에디터 클릭 0회.

---

## 4. Import 설정 — `.import` 파일 텍스트 편집

에디터 인스펙터의 Import 탭 대신, AI는 **`.import` 파일을 직접 수정**한다.

예: 모든 UI 아이콘을 로스레스·밉맵 없음으로 일괄 설정.

```gdscript
# res://tools/normalize_icon_imports.gd
@tool
extends SceneTree

const ICONS_DIR := "res://assets/icons/"

func _init() -> void:
    var dir := DirAccess.open(ICONS_DIR)
    for f in dir.get_files():
        if not f.ends_with(".import"): continue
        var path := ICONS_DIR.path_join(f)
        var cfg := ConfigFile.new()
        if cfg.load(path) != OK: continue
        cfg.set_value("params", "compress/mode", 0)           # Lossless
        cfg.set_value("params", "mipmaps/generate", false)
        cfg.set_value("params", "process/fix_alpha_border", true)
        cfg.save(path)
    quit()
```

→ 한 번 만들어두면 새 아이콘 추가 때마다 자동 적용. 에디터 Import 탭을 열 일 없음.

---

## 5. `project.godot` 직접 편집

프로젝트 설정 UI도 필요 없다. `project.godot`은 INI 포맷:

```ini
[application]
config/name="StarReach"
run/main_scene="res://features/splash/splash.tscn"
boot_splash/image="res://assets/logo_boot.png"
boot_splash/bg_color=Color(0.06, 0.08, 0.18, 1)
boot_splash/minimum_display_time=800

[autoload]
GameState="*res://autoloads/game_state.gd"
EventBus="*res://autoloads/event_bus.gd"
SceneLoader="*res://autoloads/scene_loader.gd"
AssetHub="*res://autoloads/asset_hub.gd"
; 앞의 '*'는 "Enable as Global"(싱글턴으로 활성) 표시

[display]
window/size/viewport_width=720
window/size/viewport_height=1280
window/handheld/orientation="portrait"
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[input]
ui_accept={
"deadzone": 0.5,
"events": [Object(InputEventKey,"keycode":4194309)]
}

[gui]
theme/default_theme_scale=1.5
```

AI가 이 파일을 `Edit`로 수정 → 에디터를 다시 열면(또는 `--headless --quit-after 2`) 반영.

**AutoLoad 규칙**: 이름 앞의 `*`가 **Enable as Singleton** 플래그. 빼먹으면 전역 네임스페이스에 노출되지 않음.

---

## 6. 신호 연결 — 코드에서만

에디터의 "Connect a Signal" 다이얼로그를 쓰면 `.tscn`에 `[connection]` 섹션이 생긴다. **헤드리스 워크플로우에서는 코드 연결이 표준**이다:

```gdscript
func _ready() -> void:
    $BuyButton.pressed.connect(_on_buy_pressed)
    EventBus.currency_changed.connect(_on_currency_changed)
```

장점: 에디터 열지 않아도 연결을 볼 수 있음. grep 한 번에 모든 연결 추적 가능. 리팩터링 안전.

---

## 7. 파티클·애니메이션 — 유일한 "에디터 권장" 영역

이것만은 타협한다. 파티클 수십 개 변수를 코드로 이리저리 튜닝하는 건 고통스럽다.

**권장 하이브리드**:
1. AI가 합리적 기본값으로 `ParticleProcessMaterial.tres`를 텍스트 생성.
2. 사용자가 에디터에서 GPUParticles2D를 재생하며 값을 튜닝.
3. 에디터가 자동으로 `.tres`에 저장.
4. AI는 이후 `.tres`를 읽어 필요시 파라미터만 조정.

AnimationPlayer도 동일: 초기 트랙은 AI가 생성, 타이밍 미세조정은 에디터.

대안: `Tween`(scripted)로 대체 가능한 곳은 AnimationPlayer 대신 `create_tween()`. 에디터 없이 완결됨.

```gdscript
# fade_in without AnimationPlayer
func _ready() -> void:
    modulate.a = 0.0
    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
```

---

## 8. 자동 검증 파이프라인

F5마저 줄이려면 headless 테스트를 도입. **GUT**(Godot Unit Test)이나 순수 스크립트로 자가 검증:

```gdscript
# res://tools/smoke_test.gd — 부팅만 되는지 확인
@tool
extends SceneTree

func _init() -> void:
    var splash := load("res://features/splash/splash.tscn") as PackedScene
    assert(splash != null, "Splash scene failed to load")
    var inst := splash.instantiate()
    assert(inst != null)
    inst.queue_free()

    # AssetHub 검증
    var hub_script := load("res://autoloads/asset_hub.gd") as Script
    assert(hub_script != null)
    print("Smoke test OK")
    quit()
```

```bash
godot --path star-reach --headless --script res://tools/smoke_test.gd
echo "exit code: $?"
```

CI에 걸면 AI가 PR을 올리기 전에 "임포트 OK + 씬 로드 OK + 스크립트 파싱 OK"를 자동 확인.

---

## 9. 개정된 Agent 워크플로우 (최종)

사용자가 "생성기 '광부'를 추가해줘"라고 했을 때 AI가 수행하는 단계:

1. **데이터**: `res://features/generators/data/gen_miner.tres` 텍스트 생성 — `GeneratorData` 스키마 기반.
2. **씬 수정**: `godot-scene-surgeon`에게 `generator_list.tscn`에 새 엔트리 ExtResource 추가 위임.
3. **자산 요청이 필요하면**: `res://assets/icons/miner.png` 스펙을 사용자에게 알려주고 **Placeholder** `PlaceholderTexture2D.tres`로 동작하는 프로토타입 완성.
4. **AssetHub 매니페스트 재빌드** (필요 시): `godot --headless --script res://tools/build_asset_manifest.gd`.
5. **임포트 캐시 업데이트**: `godot --path star-reach --headless --quit-after 2`.
6. **스모크 테스트**: `godot --path star-reach --headless --script res://tools/smoke_test.gd`.
7. **사용자에게**: "F5로 실행해 결과 확인 부탁드립니다."

에디터 클릭은 오직 **6단계 이후 F5** 한 번.

---

## 10. 요약 — "에디터는 F5를 위해서만 존재한다"

| 영역 | 기존 (에디터 의존) | Headless-first |
|---|---|---|
| 스크립트 작성 | 에디터 또는 외부 에디터 | 외부 에디터 / AI Edit |
| 씬 편집 | 인스펙터 + 트리 | 텍스트 편집 + scene-surgeon / 프로그래매틱 빌드 |
| 리소스 임포트 | 에디터 실행 | `--headless --quit-after 2` |
| UID 생성 | 에디터 저장 | 임포트가 자동 생성 |
| 자산 레지스트리 | 인스펙터 드래그 | 폴더 스캔 + 매니페스트 스크립트 |
| Import 설정 | Import 탭 | `.import` ConfigFile 편집 |
| Project Settings | Settings UI | `project.godot` INI 편집 |
| AutoLoad 등록 | AutoLoad 탭 | `[autoload]` 섹션 편집 |
| 신호 연결 | Connect 다이얼로그 | 코드 `.connect()` |
| 파티클 튜닝 | 에디터 (권장) | 에디터 권장 + `.tres` 커밋 |
| 플레이 테스트 | **F5 (필수)** | **F5 (필수)** |
| 익스포트 | Export UI | `--headless --export-release` |

→ **98%는 텍스트·CLI로 가능, 2%(F5, 파티클 실시간 튜닝)만 에디터**.

---

## 11. 추가로 고려할 리스크

- **익스포트 전 최초 1회 에디터 개장 필수** (이슈 #71521). CI에서는 `.godot/` 폴더를 아티팩트로 저장하거나, Docker 이미지에 사전 포함.
- **`@tool` 스크립트의 `load()`**: 에디터/headless SceneTree 컨텍스트에서는 작동하나, 익스포트 후 런타임에서는 일부 API가 제한. 빌드 스크립트와 런타임 스크립트를 혼동하지 말 것.
- **`.godot/` 폴더는 `.gitignore`**: 임포트 캐시라 커밋 금지. 단 `.uid`와 `.import`는 **커밋**.
- **headless에서 GPUParticles2D 렌더 검증 불가**: 시각 테스트는 여전히 F5 의존.
- **Windows + Git Bash**: 이 프로젝트의 환경에서는 경로 구분자 주의. `--path`에는 정방향 슬래시 권장.

---

## 12. 참고 자료

- [Command line tutorial — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Running code in the editor (@tool) — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html)
- [PackedScene class reference](https://docs.godotengine.org/en/stable/classes/class_packedscene.html)
- [ResourceSaver class reference](https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html)
- [ConfigFile class reference](https://docs.godotengine.org/en/stable/classes/class_configfile.html) (for `.import` / `project.godot` 편집)
- [Exporting for dedicated servers — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html)
- 이슈: [Headless import with --quit hangs (#77508)](https://github.com/godotengine/godot/issues/77508)
- 이슈: [Headless export needs prior editor open (#71521)](https://github.com/godotengine/godot/issues/71521)
