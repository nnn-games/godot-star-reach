# Godot 4 스플래시·로딩 스크린 & 비동기 리소스 로딩 조사

Godot 4.6 기준. StarReach에 적용할 수 있도록 **(1) 부트 스플래시**, **(2) 커스텀 스플래시 씬**, **(3) 비동기 리소스 로딩 API**, **(4) 프로그레스 바 로딩 스크린 패턴** 순서로 정리한다.

---

## 1. 두 가지 "스플래시" 레이어 — 개념 정리

Godot에서 스플래시는 단일 기능이 아니라 **엔진 부트 단계**와 **게임 내부 스플래시**의 두 레이어로 나뉜다. 실제 제품은 거의 항상 둘을 조합한다.

| 레이어 | 표시 시점 | 표현력 | 설정 위치 |
|---|---|---|---|
| **Boot Splash (부트 스플래시)** | 엔진이 띄워지고 main scene이 로드되기 직전까지의 "검은 화면"을 덮는 정적 이미지 | 이미지 1장 + 배경색. 애니메이션/사운드 불가 | `project.godot` → `application/boot_splash/*` |
| **Splash Scene (커스텀 스플래시)** | Main scene을 부트 스플래시 이미지 대신 스플래시 씬으로 지정 → 애니메이션/로고/프로그레스 바 표시 후 실제 타이틀 씬으로 전환 | 씬이므로 제한 없음 (2D/3D/사운드/비디오) | 일반 씬 + `application/run/main_scene` |

공식 권장 흐름: **Boot Splash → Splash Scene(로고·로딩) → Main Menu**.

---

## 2. Boot Splash 설정

### 2.1 프로젝트 설정 키 (project.godot)

`[application]` 섹션 아래 `boot_splash/*` 하위 키들:

| 키 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `boot_splash/show_image` | bool | `true` | 이미지 사용 여부 (false면 `bg_color`만 표시) |
| `boot_splash/image` | String(path) | `""` (Godot 로고) | 표시할 이미지 리소스 경로. 비우면 엔진 로고 |
| `boot_splash/fullsize` | bool | `true` | 전체 화면 크기로 스케일 |
| `boot_splash/use_filter` | bool | `true` | 스케일 시 필터링(픽셀 아트면 `false`) |
| `boot_splash/bg_color` | Color | `Color(0.14, 0.14, 0.14, 1)` | 배경색 |
| `boot_splash/minimum_display_time` | int(ms) | `0` | 최소 표시 시간. 로딩이 빨라도 이 시간만큼은 유지 |

> `minimum_display_time`은 **에디터가 아닌 익스포트 실행에서만 엄격히 적용**되는 편이다. 플랫폼별 동작 편차 보고도 있으니, "최소 노출 시간"은 스플래시 씬 쪽에서 추가로 확보하는 편이 안전하다.

### 2.2 에디터에서 설정

`Project → Project Settings → Application → Boot Splash` 에서 이미지 드롭, 배경색 지정 등 모두 UI로 가능.

### 2.3 주의

- `*.import`이 있는 정식 리소스 경로를 써야 한다(예: `res://assets/ui/boot_logo.png`).
- 투명 PNG + 투명 `bg_color` 조합은 플랫폼별 버그 이력이 있어 권장하지 않음 — 불투명 배경을 권장.
- Web 익스포트에서는 별도 HTML 템플릿이 먼저 뜨므로, 브라우저 배경색도 맞춰야 이질감이 없다.

---

## 3. Splash Scene (커스텀 스플래시) 전략

애니메이션·로고·로딩 바를 보여주려면 **씬으로 만든다**.

기본 구조(권장):

```
SplashScene (Control)
├── BgColorRect            # 배경
├── LogoTextureRect        # 로고 (AnimationPlayer로 페이드)
├── ProgressBar            # 비동기 로딩 진행도 (선택)
└── AnimationPlayer        # fade_in → hold → fade_out 타임라인
```

흐름 설계 옵션은 두 가지:

1. **선형 타이머 전환**: fade_in → N초 hold → fade_out → `change_scene_to_file("res://menu.tscn")`. 리소스 로드는 필요 없지만 "로딩 중"을 연출만 함.
2. **실제 비동기 로딩 + 프로그레스 바**: `_ready()`에서 `ResourceLoader.load_threaded_request()`를 시작하고, `_process()`에서 진행도를 갱신 → 로딩 완료 + 최소 연출 시간 경과 시 `change_scene_to_packed()`로 전환.

StarReach(증분 시뮬)는 초기 리소스가 크지 않으므로 **2번 패턴을 쓰되, 최소 표시 시간(예: 1.5s)을 강제**하는 편이 UX상 자연스럽다. 너무 빨리 지나가는 스플래시는 "깜빡임"으로 인식된다.

---

## 4. 비동기 리소스 로딩 핵심 API

### 4.1 왜 필요한가

- `load(path)` / `preload(path)`는 **메인 스레드를 블로킹**한다. 큰 씬/오디오/이미지를 로드할 때 프레임이 얼어붙는다.
- `ResourceLoader.load_threaded_*`는 **별도 스레드에서 로드 + 메인에서 폴링**하는 3단계 API를 제공한다.

### 4.2 핵심 메서드 시그니처

```gdscript
# 1) 백그라운드 로드 시작
ResourceLoader.load_threaded_request(
    path: String,
    type_hint: String = "",
    use_sub_threads: bool = false,
    cache_mode: ResourceLoader.CacheMode = ResourceLoader.CACHE_MODE_REUSE
) -> Error

# 2) 진행 상황 폴링
ResourceLoader.load_threaded_get_status(
    path: String,
    progress: Array = []   # out-param: progress[0]에 0.0~1.0 퍼센트가 채워짐
) -> ResourceLoader.ThreadLoadStatus

# 3) 완료된 리소스 획득 (아직이면 블로킹됨 — 반드시 status 확인 후 호출)
ResourceLoader.load_threaded_get(path: String) -> Resource
```

### 4.3 `ThreadLoadStatus` 열거형

| 값 | 의미 | 대응 |
|---|---|---|
| `THREAD_LOAD_INVALID_RESOURCE` | 경로/리소스가 잘못됨 | 에러 로깅 후 폴백 |
| `THREAD_LOAD_IN_PROGRESS` | 로딩 중 | 프로그레스 바 업데이트 |
| `THREAD_LOAD_FAILED` | 로딩 실패 | 에러 표시, 재시도/폴백 |
| `THREAD_LOAD_LOADED` | 완료 | `load_threaded_get()` 호출 후 사용 |

### 4.4 파라미터 디테일

- **`type_hint`**: `"PackedScene"`, `"Texture2D"` 같은 타입 문자열. 타입 체크가 들어가 잘못된 리소스 지정 시 조기 실패. 넘기는 쪽이 안전.
- **`use_sub_threads`**: `true`로 하면 하위 리소스도 병렬로 로드 — 크고 의존 리소스가 많은 씬에 효과적. 기본은 `false`.
- **`cache_mode`**:
  - `CACHE_MODE_IGNORE` — 캐시 무시, 항상 새로 로드
  - `CACHE_MODE_REUSE`(기본) — 기존 캐시 재사용
  - `CACHE_MODE_REPLACE` — 새로 로드하되 기존 캐시 항목을 덮어씀(핫리로드용)
- **`progress` 배열**: 호출 전에 `var p: Array = []` 로 만들어 넘긴다. 콜 이후 `p[0]`에 `0.0 ~ 1.0`의 진행 비율이 들어온다. 값은 근사치이며 리소스 성격에 따라 단조 증가가 보장되지 않을 수 있다.

### 4.5 중요 경고 (공식 문서)

> **"`load_threaded_get()`을 호출하면, 백그라운드 로딩이 완료됐으면 즉시 반환, 아직이면 `load()`처럼 블로킹된다."**

→ 반드시 `load_threaded_get_status() == THREAD_LOAD_LOADED`를 확인한 뒤 호출하거나, 의도적으로 블로킹 대기를 할 때만 바로 호출할 것.

### 4.6 알려진 제약

- **Web 익스포트(HTML5)**: 브라우저 환경에서는 멀티스레딩이 제한되어 `load_threaded_*`가 사실상 동기처럼 동작하거나 미지원인 경우가 있다. 웹 빌드 대상이면 별도 프로파일/폴백 경로를 고려.
- 동시에 복잡한 씬 여러 개를 `load_threaded_request`로 올리면 불안정성이 보고된 이슈가 있다 — 한 번에 하나씩, 또는 청크 단위로 큐잉.

---

## 5. 로딩 스크린 구현 패턴 (최소 예제)

### 5.1 씬 구조

```
loading_screen.tscn (Control, full rect)
├── Background (ColorRect)
├── Logo (TextureRect)
├── ProgressBar (min=0, max=100)
└── StatusLabel (Label) — 선택
```

### 5.2 스크립트 (`loading_screen.gd`)

```gdscript
extends Control

@export var target_scene_path: String = "res://scenes/main_menu.tscn"
@export var min_display_time_sec: float = 1.5  # 깜빡임 방지용 최소 노출 시간

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var status_label: Label = $StatusLabel

var _progress: Array = []
var _elapsed: float = 0.0
var _loaded_packed: PackedScene = null

func _ready() -> void:
    var err: int = ResourceLoader.load_threaded_request(
        target_scene_path,
        "PackedScene",
        true  # use_sub_threads: 하위 리소스 병렬 로드
    )
    if err != OK:
        push_error("load_threaded_request failed: %s" % err)

func _process(delta: float) -> void:
    _elapsed += delta
    var status: int = ResourceLoader.load_threaded_get_status(target_scene_path, _progress)

    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            # _progress[0] ∈ [0.0, 1.0]
            progress_bar.value = _progress[0] * 100.0
        ResourceLoader.THREAD_LOAD_LOADED:
            progress_bar.value = 100.0
            if _loaded_packed == null:
                _loaded_packed = ResourceLoader.load_threaded_get(target_scene_path)
            if _elapsed >= min_display_time_sec:
                get_tree().change_scene_to_packed(_loaded_packed)
                set_process(false)
        ResourceLoader.THREAD_LOAD_FAILED:
            status_label.text = "Load failed."
            set_process(false)
        ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            status_label.text = "Invalid resource: %s" % target_scene_path
            set_process(false)
```

### 5.3 포인트

- **최소 노출 시간(`min_display_time_sec`)**: 로딩이 0.1초 만에 끝나도 1.5s는 유지 → 깜빡임 방지.
- **`change_scene_to_packed`** 사용: 이미 메모리에 로드된 PackedScene을 사용하므로 `change_scene_to_file`처럼 다시 로드하지 않음.
- **`set_process(false)`**: 전환 직전에 루프 중단.
- **에러 상태 2종**(`FAILED`, `INVALID_RESOURCE`)을 분리 처리하면 디버깅이 쉬워진다.

### 5.4 여러 리소스를 함께 로드하는 경우

```gdscript
var _paths: PackedStringArray = [
    "res://scenes/main_menu.tscn",
    "res://audio/bgm_menu.ogg",
    "res://data/initial_balance.tres",
]
var _progress_each: Array = []  # 각 경로별 progress array

func _ready() -> void:
    for p in _paths:
        ResourceLoader.load_threaded_request(p)
        _progress_each.append([])

func _process(_d: float) -> void:
    var total: float = 0.0
    var done: int = 0
    for i in _paths.size():
        var prog: Array = _progress_each[i]
        var status: int = ResourceLoader.load_threaded_get_status(_paths[i], prog)
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            done += 1
            total += 1.0
        elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and prog.size() > 0:
            total += prog[0]
    progress_bar.value = (total / _paths.size()) * 100.0
    if done == _paths.size():
        _on_all_loaded()
```

---

## 6. 오토로드 기반 로더(선택)

씬 전환 시 로딩 스크린이 `change_scene_to_*`로 파괴되면 프로그레스 바가 리셋된다. 화면이 "전환 → 검정 → 새 로딩 화면 표시"로 튀는 걸 피하려면:

- `SceneLoader` **오토로드 싱글턴**에 로딩 로직을 두고,
- 전환 요청이 오면 기존 씬 위에 **CanvasLayer로 로딩 오버레이**를 띄우고,
- 완료 후 `get_tree().change_scene_to_packed()` 호출 + 오버레이 제거.

이렇게 하면 트랜지션이 매끄럽고, API도 단순해진다:

```gdscript
# 호출부
SceneLoader.load_and_switch("res://scenes/game.tscn")
```

커뮤니티 레퍼런스: *Maaack's Godot Scene Loader*, *EiTaNBaRiBoA/AsyncScene* 가 정확히 이 패턴.

---

## 7. StarReach 적용 권장

증분 시뮬레이터 특성상 초기 로딩이 무겁지 않다. 다음 구성을 권장:

1. **Boot Splash**: 정적 로고 PNG + 단색 배경. `minimum_display_time = 800`.
2. **Splash Scene (`res://scenes/splash.tscn`)**:
   - 로고 페이드 인/홀드/아웃 AnimationPlayer
   - 백그라운드에서 `res://scenes/main_menu.tscn` + `GameState`가 쓰는 주요 `.tres`들 `load_threaded_request`
   - 로드 완료 + fade_out 종료 시 `change_scene_to_packed`
3. **Main Scene 설정**: `application/run/main_scene = res://scenes/splash.tscn`.
4. **향후 게임플레이 씬 전환**(예: 프레스티지 리셋 후 재진입)은 6장의 오토로드 `SceneLoader`로 일원화.

---

## 8. 참고 자료

- [Background loading — Godot Docs (stable)](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html)
- [ResourceLoader class reference — Godot Docs](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html)
- [godot-docs GitHub source (background_loading.rst)](https://github.com/godotengine/godot-docs/blob/stable/tutorials/io/background_loading.rst)
- [Loading Screen in Godot 4 — gotut.net](https://www.gotut.net/loading-screen-in-godot-4/)
- [Maaack's Godot-Scene-Loader (autoload 패턴 레퍼런스)](https://github.com/Maaack/Godot-Scene-Loader)
- [EiTaNBaRiBoA/AsyncScene (progress_changed 시그널 기반 래퍼)](https://github.com/EiTaNBaRiBoA/AsyncScene)
- [SplashScreenWizard (스플래시 씬 생성 플러그인)](https://github.com/ThePat02/SplashScreenWizard)
- [godot-awesome-splash (스플래시 예제 모음)](https://github.com/duongvituan/godot-awesome-splash)
