# Godot 4 모바일 UI 리사이즈 — 해상도·비율·노치·DPI 대응

Godot 4.6 기준, 모바일(Android/iOS)에서 UI를 **어떤 기기에서도 깨지지 않게** 만드는 기본 전략 정리. StarReach는 **세로(portrait) 증분 시뮬**이 될 가능성이 높으므로 그 관점에서 권장안까지 제시한다.

---

## 0. 문제 정의 — 모바일 UI가 어려운 5가지 축

| 축 | 범위 | 핵심 고려사항 |
|---|---|---|
| **해상도** | 720×1280 ~ 1440×3200 (Android 최신 폰까지) | 베이스 해상도를 정하고 **스케일**시킨다 |
| **종횡비** | 세로 16:9 ~ 20:9 이상 | "기준 프레임이 얼마나 늘어나는가"를 통제 |
| **노치·펀치홀·둥근 모서리** | iPhone Dynamic Island, Android cutout | **Safe Area** 내부로 UI를 제한 |
| **DPI** | 2x ~ 4x 픽셀 밀도 | 스케일 팩터 + 테마 스케일로 보정 |
| **방향 전환** | portrait ↔ landscape | 락 or 동적 레이아웃 |

Godot는 이 중 **1~3번은 거의 완벽한 빌트인 해결책**을, **4번은 일부 자동**, **5번은 설정 + 런타임 시그널**로 지원한다.

---

## 1. Content Scale — 가장 중요한 3개의 노브

Godot의 모바일 리사이즈 전략의 **90%는 프로젝트 설정 3개**에 들어있다. (`Project Settings → Display → Window → Stretch`)

### 1.1 Stretch Mode — "어떻게 늘릴 것인가"

| 값 | 동작 | 언제 쓰나 |
|---|---|---|
| **`disabled`** (기본) | 스케일 없음. 1 유닛 = 1 픽셀. 해상도가 달라지면 UI가 고정 픽셀로 남음 | 에디터/데스크탑 툴. **모바일 금지** |
| **`canvas_items`** | 베이스 해상도 → 화면 해상도로 늘림. 2D/UI는 **벡터처럼** 선명하게 스케일. 3D는 영향 없음 | **모바일 UI 기본 선택** |
| **`viewport`** | 베이스 해상도로 먼저 렌더한 뒤 전체를 확대. 저해상도 렌더링 느낌 | 픽셀아트, 도트 그래픽 |

> 증분 시뮬 UI는 대부분 선명한 벡터성 위젯/타이포그래피 → **`canvas_items`**가 정답.

런타임 변경: `get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS`

### 1.2 Stretch Aspect — "비율이 안 맞을 때 어떻게 할 것인가"

| 값 | 동작 | UX 효과 |
|---|---|---|
| `ignore` | 종횡비 무시, 무조건 늘림 | UI가 찌그러짐. ❌ |
| `keep` | 베이스 비율 유지, 남는 부분은 검은 띠 | 레터박스/필러박스 발생 |
| `keep_width` | 가로폭 유지. 위아래가 남으면 위아래로 뷰포트가 늘어남 | **세로 게임 기본** |
| `keep_height` | 세로높이 유지. 좌우가 남으면 좌우로 뷰포트가 늘어남 | **가로 게임 기본** |
| `expand` | 종횡비 유지하되 남는 방향으로 뷰포트 확장 | 세로/가로 모두 대응, 검은 띠 없음 |

**핵심 원리**:
- `keep_*`/`expand`는 **뷰포트 자체가 커진다**. 즉, 화면이 더 길어진 만큼 Control이 차지할 수 있는 공간도 커진다 → Anchor `1.0` 이면 끝까지 따라간다.
- 반대로 `keep`은 뷰포트가 절대 커지지 않고 주변을 검게 만든다.

**모바일 권장**: **`expand`** — 세로 20:9 폰에서도 위아래로 UI가 자연스럽게 늘어나고, 가로 태블릿에서도 좌우로 확장. 안드로이드 공식 Godot 가이드도 모바일에 `expand` 권장.

런타임 변경: `get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND`

### 1.3 Stretch Scale (Factor) — "추가 배율"

- 위 스케일 결과 위에 한 번 더 곱해지는 **float 배율**. 기본 `1.0`.
- 저시력 접근성 옵션("UI 125%")을 노출할 때 쓴다.
- 런타임: `get_tree().root.content_scale_factor = 1.25`

### 1.4 Stretch Scale Mode (Godot 4.2+)

- `fractional`(기본): 2.5배 등 실수 배율 허용.
- `integer`: 정수 배율로 반올림 내림 → 픽셀아트 왜곡 방지.

### 1.5 베이스 해상도 권장

세로 모바일 기준:

| 기기 타깃 | 베이스 해상도 |
|---|---|
| 광범위 호환 (권장) | `720×1280` |
| 고해상도 기준 | `1080×1920` |
| 세로+태블릿 동시 | `720×960` 또는 `960×1280` (4:3 계열) |

Anchoring과 `expand`가 나머지를 흡수하므로 **베이스 해상도는 "참조용 캔버스"일 뿐**이라고 생각하는 편이 정확하다.

---

## 2. Anchors + Containers — 반응형 레이아웃

Content Scale은 **뷰포트 크기를 결정**할 뿐이다. 뷰포트 안에서 각 버튼/패널이 **어떻게 재배치되는가**는 Anchors와 Container의 영역.

### 2.1 Anchors & Offsets

모든 Control은 4개의 Anchor(`0.0~1.0`)를 가진다. 이는 **부모 컨트롤 크기에 대한 비율 위치**다.

- Anchor `(0,0,1,1)` + Offset 0 → 부모 전체를 덮음(풀스크린).
- Anchor `(0.5,0,0.5,0)` → 상단 가운데 고정 — HUD 상단 중앙 아이콘.
- Anchor `(0,1,1,1)` + 세로 Offset 음수 → 하단 바닥 풀폭(내비게이션 바).

에디터 툴바의 **Layout 프리셋**이 대부분의 상용 패턴을 커버한다 — 직접 4개 값을 타이핑할 일은 드물다.

### 2.2 Containers — 리스트/그리드/반응형

Anchor는 "고정 위치"용. **다수 자식을 자동 배치**하려면 Container:

| Container | 용도 |
|---|---|
| `VBoxContainer` / `HBoxContainer` | 세로/가로 스택. 증분 게임의 생성기 리스트 |
| `GridContainer` | NxN 격자. 업그레이드 타일 |
| `MarginContainer` | 내부 여백. **Safe Area 래퍼로도 쓰임** |
| `CenterContainer` | 자식을 가운데 정렬 |
| `ScrollContainer` | 스크롤. 모바일에서 컨텐츠 넘칠 때 필수 |
| `AspectRatioContainer` | 자식의 종횡비 강제 유지 |
| `PanelContainer` | 배경 + 마진. 카드 UI에 유용 |

**Size Flags** (`Fill`, `Expand`, `Shrink Center` 등)로 각 자식의 확장 방식을 제어. Container + Size Flags 조합이 **Flexbox에 해당**한다고 보면 된다.

### 2.3 모바일 UI 루트 권장 구조

```
HUD (Control, anchors full rect)
└── SafeArea (MarginContainer, 동적 마진)
    └── RootLayout (VBoxContainer, 크기 flags expand+fill)
        ├── TopBar  (HBoxContainer) — 재화 표시, 설정 버튼
        ├── MainArea (ScrollContainer / Panel) — 생성기 리스트
        └── BottomTabs (HBoxContainer) — 탭 전환
```

이 구조 + `stretch_mode = canvas_items` + `stretch_aspect = expand`면 기기 대부분을 커버한다.

---

## 3. Safe Area — 노치·펀치홀·제스처 영역

`expand` 모드는 뷰포트를 화면 끝까지 늘리지만, 그 일부는 **노치·스테이터스바·제스처 핸들**에 가려진다. UI를 전부 **Safe Rect 안으로 밀어넣어야** 한다.

### 3.1 API

```gdscript
# 디스플레이 기준 safe rect (픽셀 단위, 기기 원본 해상도 기준)
var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
```

- iOS·Android에서 동작. 데스크톱에서는 사실상 전체 스크린.
- **주의**: 이 값은 **화면 픽셀 좌표계**다. `canvas_items`로 뷰포트가 베이스 해상도로 축소/확대된 상태에서는 **직접 쓰면 안 됨** — 환산 필요.
- `screen_get_usable_rect()`도 존재하지만 OS 작업표시줄까지 반영하는 성격이라 모바일 레이아웃엔 `display_safe_area` 쪽이 일반적.

### 3.2 실전: SafeArea MarginContainer 오토로드 패턴

아래는 **윈도우 픽셀 → 뷰포트 픽셀로 환산한 마진**을 MarginContainer에 적용하는 재사용 노드.

```gdscript
# res://ui/safe_area_margin.gd
class_name SafeAreaMargin
extends MarginContainer

func _ready() -> void:
    _apply_safe_area()
    get_tree().root.size_changed.connect(_apply_safe_area)

func _apply_safe_area() -> void:
    var root: Window = get_tree().root
    var window_size: Vector2 = Vector2(root.size)
    if window_size.x <= 0.0 or window_size.y <= 0.0:
        return

    # 디스플레이 픽셀 기준 safe rect
    var safe: Rect2i = DisplayServer.get_display_safe_area()
    var screen_size: Vector2 = Vector2(DisplayServer.screen_get_size())

    # (디스플레이 좌표 → 뷰포트 좌표) 스케일
    var viewport_size: Vector2 = root.get_visible_rect().size
    var s: Vector2 = viewport_size / screen_size

    var left: int   = int(floor(safe.position.x * s.x))
    var top: int    = int(floor(safe.position.y * s.y))
    var right: int  = int(floor((screen_size.x - safe.end.x) * s.x))
    var bottom: int = int(floor((screen_size.y - safe.end.y) * s.y))

    add_theme_constant_override("margin_left",   max(left,   0))
    add_theme_constant_override("margin_top",    max(top,    0))
    add_theme_constant_override("margin_right",  max(right,  0))
    add_theme_constant_override("margin_bottom", max(bottom, 0))
```

사용:

```
HUD (Control)
└── SafeAreaMargin (위 스크립트)
    └── 실제 UI 루트
```

화면 크기가 변하면(회전 포함) `size_changed` 시그널을 타고 자동 재계산.

### 3.3 배경 아트는 예외

배경 그라데이션/이미지는 **safe area 바깥까지 채워서** 노치 뒤까지 색이 있는 편이 자연스럽다. SafeAreaMargin **밖**에 배경 노드를 두고, **안**에만 조작 UI를 넣자.

### 3.4 알려진 이슈

- `DisplayServer.get_display_safe_area()`가 **스트레치 이후 좌표로 안 온다**는 지적(이슈 #74835). 위 환산 로직이 필요한 이유다.
- iOS 홈 인디케이터 영역까지 포함 여부는 플랫폼 버전마다 미세 차이가 있음. 하단 마진은 넉넉히(+8~12px) 두는 것이 안전.

---

## 4. DPI / Theme Scale

모든 Control은 공통 `Theme`에서 폰트 크기·스타일박스를 가져온다. 고DPI 기기에서 텍스트가 너무 작다면:

### 4.1 프로젝트 설정
- `gui/theme/default_theme_scale` — 테마 전체의 기본 스케일. 런타임 변경 불가.
- 모바일에서 **`1.5`~`2.0`** 권장 (특히 베이스 해상도가 `720×1280`처럼 작을 때).

### 4.2 스크린 스케일 조회
```gdscript
var screen_scale: float = DisplayServer.screen_get_scale()
```
- iOS/macOS에서는 `@2x`/`@3x`를 정확히 반환. Android/Windows/Linux에서는 `1.0` 반환 또는 근사치 — 공식 문서상 플랫폼 제한.

### 4.3 전략
- 고정 테마 스케일(1.5) + `content_scale_factor`로 사용자 배율 옵션을 추가 제공하는 조합이 깔끔.
- 폰트는 **벡터(TTF/OTF)**를 쓰고, `font_size`는 테마에서만 관리. 노드마다 하드코딩 금지.

---

## 5. 오리엔테이션

### 5.1 고정 방식
`Project Settings → Display → Window → Handheld → Orientation`

| 값 | 의미 |
|---|---|
| `portrait` / `landscape` | 단일 방향 락 |
| `sensor_portrait` / `sensor_landscape` | 센서 따라가되 해당 축만 허용 |
| `sensor` | 모든 방향 허용 |

StarReach처럼 증분 게임은 **`portrait` 락**이 UX상 명확. 동적 레이아웃 부담도 없어진다.

### 5.2 런타임 변경
```gdscript
DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
```

### 5.3 방향 변경 대응
자유 회전을 허용하면 다음 시그널들로 레이아웃을 갱신한다.

```gdscript
func _ready() -> void:
    get_tree().root.size_changed.connect(_on_size_changed)

func _on_size_changed() -> void:
    # 앵커/마진은 자동 재계산되지만, 직접 계산한 safe area 마진은
    # 여기서 다시 적용해야 한다.
    pass
```

---

## 6. 터치 입력 관련 (리사이즈와 엮이는 포인트)

- `Project Settings → Input Devices → Pointing`:
  - **`emulate_mouse_from_touch = true`** (기본 on): 터치를 마우스 이벤트로도 방출 → UI 개발 시 데스크톱 클릭으로 바로 테스트 가능.
  - **`emulate_touch_from_mouse = true`**: 반대. 터치 전용 노드를 데스크톱에서 테스트하고 싶을 때.
- 버튼 최소 크기는 **~48×48 dp** (Material Design). 베이스 720×1280에서 대략 `48×48 px` 이상.
- `Control.mouse_filter = MOUSE_FILTER_STOP / PASS / IGNORE`로 터치 이벤트 전파를 명시적으로 관리. 스크롤 컨테이너 안 자식이 터치를 삼키는 버그의 대부분은 이 값 때문.

---

## 7. StarReach 권장 기본 세팅

`project.godot` → `[display]`:

```
window/size/viewport_width=720
window/size/viewport_height=1280
window/handheld/orientation="portrait"
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/stretch/scale=1.0
```

`[gui]`:

```
theme/default_theme_scale=1.5
```

`[input_devices]`:

```
pointing/emulate_mouse_from_touch=true
pointing/emulate_touch_from_mouse=false
```

씬 루트:
```
HUD (CanvasLayer)
└── Root (Control, Layout = Full Rect)
    ├── Background (ColorRect/TextureRect, Full Rect)   # safe area 밖까지
    └── SafeAreaMargin (MarginContainer, Full Rect)
        └── MainVBox (VBoxContainer, expand+fill)
            ├── TopBar
            ├── GeneratorList (ScrollContainer)
            └── BottomTabs
```

---

## 8. 체크리스트 (출시 전 최소 검증)

- [ ] 20:9 폰(1080×2400), 16:9 폰(720×1280), 4:3 태블릿(1536×2048)에서 **잘림 없음 + 검은 띠 없음**
- [ ] iPhone 노치·Dynamic Island 기기에서 **UI가 가려지지 않음** (SafeAreaMargin 동작 확인)
- [ ] 회전(허용 시) 후 레이아웃이 재배치됨
- [ ] 저DPI(`1x`) 에뮬레이터와 고DPI(`3x`) 실기기 둘 다에서 폰트 가독성 OK
- [ ] 하단 홈 인디케이터·제스처 핸들 위에 **탭하기 힘든 버튼이 없음**
- [ ] 스크롤 컨테이너가 터치 스크롤을 막지 않음(`mouse_filter` 점검)

---

## 9. 참고 자료

- [Multiple resolutions — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)
- [Size and anchors — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/ui/size_and_anchors.html)
- [Using Containers — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html)
- [Android Developers — Godot form factor guidance](https://developer.android.com/games/engines/godot/godot-formfactor)
- [Adapting Mobile Games for a Notch in Godot — Steven Splint](https://stevensplint.com/adapting-mobile-games-for-a-notch-in-godot/)
- [Simple way to manage the notch on mobile — Godot Forum](https://forum.godotengine.org/t/simple-way-to-manage-the-notch-on-ios-and-android-mobile-devices/86971)
- [Responsive UI Design in Godot — Wayline](https://www.wayline.io/blog/responsive-ui-design-godot-anchors-size-flags)
- 이슈: [`get_display_safe_area()` does not scale with window stretching (#74835)](https://github.com/godotengine/godot/issues/74835)
