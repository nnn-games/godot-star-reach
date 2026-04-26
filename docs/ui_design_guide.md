# UI Design Guide (StarReach — Godot 4.6)

본 문서는 **StarReach**의 모든 화면/패널/모달에 적용되는 **규범 가이드**입니다. 신규 UI 작성 및 기존 UI 수정 시 반드시 이 가이드를 기준으로 삼아야 합니다.

- 엔진: **Godot 4.6** (GDScript, Control 노드 기반)
- 장르: 2D 우주 발사 증분 시뮬레이터(Incremental Simulator)
- 플랫폼: Android / iOS / PC (Steam, Steam Deck) — **싱글 오프라인**
- 입력: 모바일 우선 (탭 / 핀치 / 한 손 조작), 마우스/키보드/Steam 컨트롤러 호환

> 게임플레이 데이터/경제 규칙은 `docs/economy_system.md`(작성 예정)를, 저장 포맷은 `docs/save_system.md`를 정본으로 참조합니다.

---

## 1. 디자인 원칙

### 1-1. 핵심 원칙

| 원칙 | 의미 |
|------|------|
| **Mobile First** | 모든 UI는 6.1" 1080×2400(19.5:9) 모바일 화면을 1차 타겟으로 설계. PC/Steam은 동일 레이아웃을 확대. |
| **One-Hand Reach** | 핵심 액션(LAUNCH, Auto Launch, 메인 메뉴)은 화면 하단 50% 영역에 배치 — 엄지 도달 가능. |
| **Big Launch Button** | LAUNCH 버튼은 화면에서 가장 크고 가장 시인성이 높아야 함. 최소 폭 40%, 최소 높이 96px. |
| **Cognitive Load Minimization** | 한 화면에 동시에 노출되는 1차 정보는 7개 이하. 2차 정보는 패널/모달로 분리. |
| **Glanceable** | 잠시 화면을 봤을 때 "지금 어떤 재화가 얼마인지", "다음 액션이 무엇인지"를 0.5초 안에 파악 가능해야 함. |
| **Offline Friendly** | 네트워크 없이도 모든 UI가 동작. 오프라인 진행 결과는 첫 진입 시 모달로 명확히 보여줌. |

### 1-2. 화면 영역 분할 (메인 화면 기준)

```
┌──────────────────────────────────────────────┐
│  TopBar  : 3 Currency · Destination · Menu   │  ← 정보 영역 (10~12% 높이)
├──────────────────────────────────────────────┤
│                                              │
│                                              │
│  CenterStage : Launch Visualization          │  ← 시각화 영역 (55~65% 높이)
│                (rocket / trail / planets)    │
│                                              │
│                                              │
├──────────────────────────────────────────────┤
│  Stress / Auto Launch indicators             │  ← 보조 정보 (8% 높이)
├──────────────────────────────────────────────┤
│           ╔════════════════════╗             │
│           ║      LAUNCH        ║             │  ← 액션 영역 (18~22% 높이)
│           ╚════════════════════╝             │
└──────────────────────────────────────────────┘
```

세부 화면 설계는 §6 화면별 레이아웃 참조.

---

## 2. 컬러 팔레트

### 2-1. 마스터 팔레트

게임 전체의 모든 색상은 아래 팔레트에서 파생합니다. 임의의 색상을 직접 입력하지 않고, Godot `Theme` 리소스(§11)에 등록된 색상 또는 본 표의 HEX를 참조합니다.

| 토큰 | HEX | 용도 |
|------|------|------|
| `space_void` | `#0A0F1C` | 메인 배경 (우주 공간) |
| `space_deep` | `#121A2E` | 보조 배경, 패널 BG |
| `panel_bg` | `#1B2440` | 카드/패널 표면 |
| `panel_bg_alt` | `#243154` | 서브 패널, 호버 표면 |
| `divider` | `#34416B` | 구분선, 비활성 외곽선 |
| `text_primary` | `#F2F6FF` | 본문 주요 텍스트 |
| `text_secondary` | `#A9B6D4` | 보조/설명 텍스트 |
| `text_disabled` | `#5C6889` | 비활성 텍스트 |
| `accent_launch` | `#FFB347` | LAUNCH 버튼 메인 |
| `accent_launch_hi` | `#FFD580` | LAUNCH 하이라이트 |
| `accent_launch_lo` | `#B86A0E` | LAUNCH 그림자 |
| `accent_thrust` | `#FF6B3D` | 추진력/Stress 경고 |
| `accent_credits` | `#FFD93D` | Credits (1차 화폐) |
| `accent_research` | `#5BC0EB` | Research Points (2차 화폐) |
| `accent_prestige` | `#C792EA` | Prestige Cores (3차 화폐) |
| `accent_success` | `#7CE07C` | 성공 피드백, 잠금 해제 |
| `accent_warning` | `#FFD166` | 경고 (Stress > 70%) |
| `accent_danger` | `#FF4D4D` | 위험 (오버로드, 실패) |
| `accent_info` | `#5BC0EB` | 정보, 링크 |
| `overlay_dim` | `#000000` (alpha 0.6) | 모달 배경 디머 |

### 2-2. 화폐별 색상 매핑

| 화폐 | 색상 토큰 | 아이콘 (placeholder) |
|------|----------|----------------------|
| Credits (`💴`) | `accent_credits` `#FFD93D` | `res://assets/ui/icon_credits.png` |
| Research (`🔬`) | `accent_research` `#5BC0EB` | `res://assets/ui/icon_research.png` |
| Prestige Core (`✨`) | `accent_prestige` `#C792EA` | `res://assets/ui/icon_prestige.png` |

### 2-3. 상태별 색상

| 상태 | 사용 색상 | 예시 |
|------|----------|------|
| 구매 가능 | `accent_success` | 업그레이드 가능 버튼 |
| 비용 부족 | `text_disabled` + `accent_danger` 보더 | 회색 + 빨간 외곽선 |
| 잠금 | `text_disabled` | 미해금 콘텐츠 |
| 진행 중 | `accent_thrust` | Stress bar |
| 완료/MAX | `accent_credits` (gold) | "MAX LEVEL" 표시 |

---

## 3. 타이포그래피

### 3-1. 폰트 등록

Godot `Theme` 리소스(`res://theme/main_theme.tres`)에 아래 폰트를 등록합니다.

| 토큰 | 파일 (`res://assets/fonts/`) | 용도 |
|------|----------------------------|------|
| `font_display` | `Orbitron-Black.ttf` | 큰 숫자, LAUNCH 텍스트, 헤더 |
| `font_body_bold` | `Inter-Bold.ttf` | 강조 텍스트, 버튼 |
| `font_body` | `Inter-Medium.ttf` | 본문, 설명 |
| `font_mono` | `JetBrainsMono-Regular.ttf` | 디버그, 수치 표 |

> 라이선스 — 모든 폰트는 SIL OFL/Apache 2.0. `assets/fonts/LICENSES.txt`에 명시.

### 3-2. 텍스트 스케일

모든 텍스트는 아래 5단계 스케일을 사용합니다. 임의의 px 값 사용 금지.

| 토큰 | 크기 (px @ ref 1080w) | 폰트 | 용도 |
|------|----------------------|------|------|
| `text_xl` | `48` | `font_display` | 화폐 잔고(메인), LAUNCH 버튼 |
| `text_lg` | `32` | `font_display` / `font_body_bold` | 모달 헤더, 핵심 수치 |
| `text_md` | `22` | `font_body_bold` | 패널 타이틀, 일반 버튼 |
| `text_sm` | `18` | `font_body_bold` / `font_body` | 본문, 카드 이름 |
| `text_xs` | `14` | `font_body` | 보조, 캡션, 단위 표시 |

**최소 폰트 크기:** `text_xs` = 14px. 모바일 가독성 확보를 위한 절대 하한.

### 3-3. Theme 적용 예시 (GDScript)

```gdscript
# scenes/ui/launch_button.gd
extends Button

func _ready() -> void:
    add_theme_font_override("font", preload("res://assets/fonts/Orbitron-Black.ttf"))
    add_theme_font_size_override("font_size", 48)
    add_theme_color_override("font_color", Color("#0A0F1C"))
```

대부분의 경우 `Theme` 리소스(§11)를 통해 일괄 적용하므로 위와 같은 개별 override는 예외 케이스에만 사용합니다.

### 3-4. 텍스트 가독성 규칙

| 배경 | 텍스트 색상 | 외곽선 (StyleBox border / `font_outline_color`) |
|------|------------|-------------------------------------------|
| 어두운 배경 (`space_void`, `panel_bg`) | `text_primary` / `text_secondary` | 불필요 |
| 밝은 배경 (`accent_credits`, `accent_launch`) | `space_void` `#0A0F1C` | 불필요 |
| 시각적으로 복잡한 배경 (별, 행성 위) | `text_primary` | `outline_size = 4`, `font_outline_color = #0A0F1C` |
| 그라디언트/이미지 위 큰 숫자 | `text_primary` | `outline_size = 6`, `#0A0F1C` |

---

## 4. 레이아웃 그리드

### 4-1. 지원 화면 비율

| 비율 | 대표 기기 | Godot Project Setting |
|------|----------|----------------------|
| **19.5:9** | 모바일 (iPhone 13+, Galaxy S 시리즈) | base 1080×2400 |
| **16:9** | PC, 일반 노트북 | base 1920×1080 |
| **16:10** | Steam Deck, 태블릿 | base 1280×800 |
| **21:9** | 울트라와이드 모니터 | letterbox 좌우 |

`project.godot` 설정:
```
[display]
window/size/viewport_width=1080
window/size/viewport_height=2400
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

> `aspect="expand"`로 설정하여 가로/세로 모드 모두에서 anchor 기반 레이아웃이 자연스럽게 확장되도록 합니다.

### 4-2. 안전 영역 (Safe Area)

모바일 노치/펀치홀/제스처 바를 피하기 위해 모든 화면 루트에 안전 영역 패딩을 적용합니다.

| 영역 | 모바일 | PC | Steam Deck |
|------|-------|-----|-----------|
| Top safe inset | `OS.get_window_safe_area().position.y` 동적 | `0` | `0` |
| Bottom safe inset | 모바일 제스처 바 (`~64px`) | `0` | `0` |
| Left/Right safe inset | 노치 회전 시 적용 | `0` | `0` |

구현 — 루트 `Control`에 `margin_*`을 동적으로 설정하는 `safe_area_container.gd`(`scripts/ui/safe_area_container.gd`)를 사용합니다. §6-1 참조.

### 4-3. 8pt 그리드

모든 간격, 패딩, 마진은 **8의 배수**를 사용합니다 (4px 보조 허용).

| 간격 토큰 | 값 |
|----------|-----|
| `space_xxs` | `4px` |
| `space_xs` | `8px` |
| `space_sm` | `12px` |
| `space_md` | `16px` |
| `space_lg` | `24px` |
| `space_xl` | `32px` |
| `space_xxl` | `48px` |

### 4-4. Anchor 시스템 사용 규칙

| 배치 | Anchor Preset | 비고 |
|------|--------------|------|
| 화면 전체 채움 | `Full Rect` | 루트 Control |
| 상단 바 | `Top Wide` | TopBar |
| 하단 바 | `Bottom Wide` | LAUNCH 버튼 영역 |
| 우상단 메뉴 | `Top Right` | 햄버거/메뉴 버튼 |
| 중앙 모달 | `Center` | 모든 모달의 MainPanel |
| 좌측 사이드 패널 | `Left Wide` | 업그레이드 패널 (탭/스와이프 진입) |

좌표는 **anchor + offset 조합**을 우선 사용. 절대 좌표(`set_position`)는 동적 배치 시에만 허용.

---

## 5. 컴포넌트 라이브러리

### 5-1. 기본 컴포넌트 매핑

| 역할 | Godot 노드 | 권장 부모 컨테이너 |
|------|-----------|-------------------|
| 화면 전체 컨테이너 | `Control` (`Full Rect`) | `CanvasLayer` |
| 모달 / 풀 캔버스 오버레이 | `CanvasLayer` (`layer = 10`) | 씬 루트 |
| 시각적 박스 (카드, 패널) | `Panel` (StyleBox 적용) | 컨테이너 |
| 단순 영역 표식 / 그룹 | `Control` | 임의 |
| 텍스트 | `Label` | `MarginContainer`, `VBoxContainer` |
| 액션 버튼 | `Button` | 임의 |
| 아이콘 전용 버튼 | `Button` (`flat = true`, `icon` 설정) | 임의 |
| 스위치/토글 | `CheckButton` | 임의 |
| 숫자 입력 / 슬라이더 | `HSlider` / `SpinBox` | 임의 |
| 이미지/스프라이트 | `TextureRect` (`STRETCH_KEEP_ASPECT_CENTERED`) | 임의 |
| 진행도 표시 | `ProgressBar` (StyleBox 적용) | 임의 |
| 수직/수평 리스트 | `VBoxContainer` / `HBoxContainer` | 임의 |
| 그리드 리스트 | `GridContainer` | 임의 |
| 비율 고정 | `AspectRatioContainer` | 임의 |
| 스크롤 | `ScrollContainer` (자식 1개 권장) | 임의 |
| 패딩 | `MarginContainer` | 임의 |

### 5-2. 표준 카드 (`scenes/ui/components/card.tscn`)

```
Card (Panel, theme_type_variation = "Card")
└─ MarginContainer (margin = 16)
   └─ VBoxContainer (separation = 12)
      ├─ HeaderRow (HBoxContainer)
      │  ├─ IconRect (TextureRect 64×64)
      │  └─ TitleLabel (Label, text_md)
      ├─ BodyLabel (Label, text_sm, autowrap = WORD_SMART)
      └─ FooterRow (HBoxContainer)
         ├─ CostLabel (Label, text_md)
         └─ ActionButton (Button, custom_minimum_size = Vector2(0, 56))
```

StyleBox: `corner_radius_all = 12`, `bg_color = panel_bg`, `border_width_all = 2`, `border_color = divider`.

### 5-3. 표준 액션 버튼 (`scenes/ui/components/action_button.tscn`)

| 속성 | 값 |
|------|-----|
| `custom_minimum_size` | `(0, 56)` (모바일 최소 터치 44px + 여백) |
| `theme_type_variation` | `"PrimaryButton"` / `"SecondaryButton"` / `"DangerButton"` |
| StyleBox normal | `corner_radius = 12`, `bg_color = accent_launch` (Primary) |
| StyleBox hover | `bg_color`를 +10% lighten |
| StyleBox pressed | `bg_color`를 -10% darken, 내부 컨텐츠 `1px` 아래로 (StyleBox `content_margin_top += 1`) |
| StyleBox disabled | `bg_color = divider`, `font_color = text_disabled` |
| Font | `font_body_bold`, `text_md` |

### 5-4. LAUNCH 버튼 (`scenes/ui/components/launch_button.tscn`)

핵심 액션이므로 별도 컴포넌트로 관리합니다.

```
LaunchButton (Button)
├─ custom_minimum_size = (0, 128)
├─ theme_type_variation = "LaunchButton"
├─ AnimationPlayer (idle pulse 0.8s loop)
└─ AudioStreamPlayer (release sfx)
```

| 속성 | 값 |
|------|-----|
| Font | `font_display`, `text_xl` (48px) |
| Text | `"LAUNCH"` |
| StyleBox normal | `corner_radius = 24`, `bg_color = accent_launch`, `shadow_size = 8`, `shadow_color = #00000080` |
| StyleBox pressed | scale 0.96 (`Tween`으로 `scale` 보간) |
| 아이들 펄스 | scale `1.0 ↔ 1.04` 0.8초 sine 반복 (§7-1) |

### 5-5. 화폐 표시 (`scenes/ui/components/currency_display.tscn`)

```
CurrencyDisplay (HBoxContainer, separation = 8)
├─ IconRect (TextureRect 32×32)
├─ AmountLabel (Label, text_lg, font_color = accent_credits)
└─ DeltaLabel (Label, text_xs, modulate.a = 0, fade-in on change)
```

스크립트 — `currency_display.gd`는 `GameState` 시그널(`credits_changed(new, old)`)을 구독하고, 변경량을 `+12.5g` 형식으로 표시한 뒤 1.2초간 페이드아웃.

### 5-6. 모달 베이스 (`scenes/ui/components/modal_base.tscn`)

```
ModalBase (CanvasLayer, layer = 20)
├─ DimRect (ColorRect, color = overlay_dim, anchors = Full Rect)
│  └─ (gui_input → 클릭 시 close 시그널 emit)
└─ CenterContainer (anchors = Full Rect)
   └─ MainPanel (Panel, theme_type_variation = "Modal")
      └─ MarginContainer (margin = 24)
         └─ VBoxContainer (separation = 16)
            ├─ Header (Label, text_lg)
            ├─ Body (자식 콘텐츠 슬롯)
            └─ Footer (HBoxContainer)
               ├─ CancelButton
               └─ ConfirmButton
```

### 5-7. 컴포넌트별 권장 .tscn 위치

| 컴포넌트 | 경로 |
|---------|------|
| Card | `scenes/ui/components/card.tscn` |
| ActionButton | `scenes/ui/components/action_button.tscn` |
| LaunchButton | `scenes/ui/components/launch_button.tscn` |
| CurrencyDisplay | `scenes/ui/components/currency_display.tscn` |
| ModalBase | `scenes/ui/components/modal_base.tscn` |
| StressBar | `scenes/ui/components/stress_bar.tscn` |
| ToastMessage | `scenes/ui/components/toast.tscn` |
| TabBar | `scenes/ui/components/tab_bar.tscn` |

---

## 6. 화면별 레이아웃

### 6-1. Main Screen (`scenes/main/main_screen.tscn`)

게임 진입 시 표시되는 메인 화면. 항상 표시되는 영구 HUD(`scenes/ui/global_hud.tscn`)와 중앙 시각화 영역(`scenes/launch/rocket_view.tscn`)으로 구성됩니다.

```
MainScreen (Control, Full Rect)
├─ SafeAreaContainer (Control, scripts/ui/safe_area_container.gd)
│  ├─ TopBar (HBoxContainer, anchor Top Wide, height 96)
│  │  ├─ CurrenciesRow (HBoxContainer, separation 12)
│  │  │  ├─ CurrencyDisplay (Credits)
│  │  │  ├─ CurrencyDisplay (Research)
│  │  │  └─ CurrencyDisplay (Prestige)
│  │  ├─ Spacer (Control, size_flags_horizontal = EXPAND_FILL)
│  │  ├─ DestinationLabel (Label, text_md)
│  │  └─ MenuButton (Button, flat = true, icon menu_icon, 56×56)
│  ├─ CenterStage (SubViewportContainer or Control, fills middle 60%)
│  │  └─ RocketView 인스턴스
│  ├─ StressBar (ProgressBar, anchor Bottom Wide, height 24, margin_bottom = 200)
│  └─ BottomBar (Control, anchor Bottom Wide, height 200)
│     ├─ AutoLaunchToggle (CheckButton, anchor Top Right)
│     └─ LaunchButton (anchor Center, custom_minimum_size 480×128)
└─ HUDLayer (CanvasLayer, layer = 10)
   └─ ToastContainer (VBoxContainer, anchor Top Center)
```

스크립트 (`scripts/ui/main_screen.gd`):
- `_ready()` — `EventBus.launch_completed`, `GameState.stress_changed` 시그널 구독
- LAUNCH 버튼 `pressed` → `GameState.try_launch()` 호출
- 메뉴 버튼 → `UpgradePanel`/`CodexPanel`/`SettingsPanel` 인스턴스화 후 `add_child`

### 6-2. Launch View / Rocket View (`scenes/launch/rocket_view.tscn`)

발사 시각화 영역. 2D 렌더이지만 카메라 줌/패닝을 포함합니다.

```
RocketView (Node2D, in Control via SubViewportContainer)
├─ Camera2D (zoom 동적 변경)
├─ ParallaxBackground
│  ├─ ParallaxLayer (별 원경, scale 0.2)
│  ├─ ParallaxLayer (별 중경, scale 0.5)
│  └─ ParallaxLayer (행성 근경, scale 1.0)
├─ TrailLine (Line2D, gradient + width_curve)
├─ Rocket (Sprite2D + AnimationPlayer)
└─ MilestoneMarkers (Node2D)
   └─ Marker (Sprite2D + Label) ×N
```

스크립트 — `scripts/launch/rocket_view.gd` 가 `EventBus.launch_started`/`launch_progress(altitude, max)` 신호를 받아 카메라 zoom·로켓 위치·트레일을 갱신합니다.

### 6-3. Upgrade Panel (`scenes/ui/upgrade_panel.tscn`)

좌측에서 슬라이드인하는 사이드 패널. 모달이 아니라 백그라운드 시뮬레이션은 계속 진행됩니다.

```
UpgradePanel (Control, anchor Left Wide, width = 60% screen, off-screen 시작)
├─ Panel (StyleBox: bg_color = panel_bg, corner_radius_top_right = 24)
│  └─ MarginContainer (margin 24)
│     └─ VBoxContainer
│        ├─ Header (HBoxContainer)
│        │  ├─ TitleLabel ("UPGRADES", text_lg)
│        │  └─ CloseButton (flat icon, 48×48)
│        ├─ TabBar (TabContainer 또는 커스텀 tab_bar.tscn)
│        │  ├─ "Engine"
│        │  ├─ "Hull"
│        │  ├─ "Fuel"
│        │  └─ "Auto"
│        └─ ScrollContainer (size_flags_vertical = EXPAND_FILL)
│           └─ VBoxContainer (separation 12)
│              └─ UpgradeCard ×N (instance from card.tscn)
└─ AnimationPlayer ("slide_in" / "slide_out", 0.25s ease_out)
```

각 `UpgradeCard`:
- 좌측: 64×64 아이콘
- 중앙: 이름(`text_md`) + 효과 설명(`text_xs`) + 현재 레벨/MAX 표시(`text_sm`)
- 우측: 비용 + 구매 버튼(140×56)

### 6-4. Codex Panel (`scenes/ui/codex_panel.tscn`)

목적지/행성 도감. 풀스크린 패널.

```
CodexPanel (Control, anchor Full Rect)
├─ DimRect (ColorRect, overlay_dim)
└─ MarginContainer (margin 16)
   └─ Panel
      └─ VBoxContainer
         ├─ Header (TitleLabel "CODEX" + CloseButton)
         ├─ ScrollContainer
         │  └─ GridContainer (columns = 2 mobile / 4 PC, separation 16)
         │     └─ DestinationCard ×N
         └─ FooterStats (Label, "Discovered 7 / 32", text_sm)
```

`DestinationCard` (발견/미발견 이중 상태):

| 상태 | 시각 |
|------|------|
| Discovered | 행성 텍스처 풀 컬러, 이름·최고 기록·달성일 표시 |
| Undiscovered | 텍스처 `modulate = #5C6889`, 이름 자리에 "???", 모든 통계 숨김 |

### 6-5. Settings Panel (`scenes/ui/settings_panel.tscn`)

```
SettingsPanel (CenterContainer, modal)
└─ Panel (max_size 720×900)
   └─ MarginContainer (margin 24)
      └─ VBoxContainer (separation 16)
         ├─ Header
         ├─ Section "AUDIO"
         │  ├─ SettingRow (BGM Volume) — Label + HSlider
         │  ├─ SettingRow (SFX Volume) — Label + HSlider
         │  └─ SettingRow (Mute on background) — Label + CheckButton
         ├─ Section "GAMEPLAY"
         │  ├─ SettingRow (Auto Launch threshold) — Label + SpinBox
         │  └─ SettingRow (Numeric format) — Label + OptionButton (SI / Scientific / Engineering)
         ├─ Section "ACCESSIBILITY"
         │  ├─ SettingRow (Font scale) — Label + OptionButton (S / M / L / XL)
         │  ├─ SettingRow (Color blind mode) — Label + OptionButton (Off / Deuteranopia / Protanopia / Tritanopia)
         │  └─ SettingRow (Reduced motion) — Label + CheckButton
         ├─ Section "DATA"
         │  ├─ Button "Manual Save" (Primary)
         │  ├─ Button "Export Save" (Secondary)
         │  └─ Button "Reset Game" (Danger, double-confirm)
         └─ FooterRow (Build version Label + CloseButton)
```

각 `SettingRow` 높이 = 64px, 라벨 좌측 / 컨트롤 우측.

### 6-6. Daily Reward Modal (`scenes/ui/daily_reward_modal.tscn`)

매일 첫 진입 시 자동 표시.

```
DailyRewardModal (CanvasLayer, layer = 30)
├─ DimRect
└─ CenterContainer
   └─ Panel (640×720)
      └─ VBoxContainer (separation 16, margin 24)
         ├─ Header ("DAILY REWARD", text_lg, accent_credits)
         ├─ StreakLabel ("Day 3 / 7", text_md)
         ├─ GridContainer (columns = 7, day cells 80×100)
         │  └─ DayCell ×7 (Past / Today / Future 상태별 시각화)
         ├─ TodayRewardPreview (TextureRect 192×192 + AmountLabel text_xl)
         └─ ClaimButton (Primary, 480×96, "CLAIM")
```

`DayCell` 상태:
- Past: `modulate = text_disabled`, 체크 마크 오버레이
- Today: `accent_launch` 보더, 가벼운 펄스 애니메이션
- Future: `panel_bg_alt` 배경, 보상만 회색 톤으로

### 6-7. Offline Summary Modal (`scenes/ui/offline_summary_modal.tscn`)

오프라인 진행 후 첫 진입 시 자동 표시 (오프라인 시간 ≥ 60초 이상일 때).

```
OfflineSummaryModal (CanvasLayer, layer = 30)
├─ DimRect
└─ CenterContainer
   └─ Panel (720×640)
      └─ VBoxContainer
         ├─ Header ("WELCOME BACK", text_lg)
         ├─ DurationLabel ("Away for 4h 23m", text_md)
         ├─ Divider
         ├─ EarningsList (VBoxContainer, separation 8)
         │  └─ EarningRow ×N (HBoxContainer: icon + currency name + amount)
         ├─ CapNotice (Label, text_xs, text_secondary, "Capped at 8h offline progress")
         └─ ContinueButton (Primary, "CONTINUE")
```

오프라인 캡(기본 8시간) 적용 — `GameState.calculate_offline_progress()`에서 `min(elapsed, OFFLINE_CAP_SEC)` 처리. 캡에 도달했을 때만 `CapNotice`를 표시합니다.

---

## 7. 애니메이션 / 트랜지션

### 7-1. LAUNCH 버튼 아이들 펄스 (0.8초 루프)

```gdscript
# scripts/ui/launch_button.gd
extends Button

var _pulse_tween: Tween

func _ready() -> void:
    _start_pulse()

func _start_pulse() -> void:
    _pulse_tween = create_tween().set_loops()
    _pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _pulse_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.4)
    _pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.4)

# 사용자가 누른 직후엔 펄스를 잠깐 멈춰 선택의 무게감을 살림
func _on_pressed() -> void:
    if _pulse_tween:
        _pulse_tween.kill()
    var t := create_tween()
    t.tween_property(self, "scale", Vector2(0.96, 0.96), 0.06)
    t.tween_property(self, "scale", Vector2.ONE, 0.10)
    t.tween_callback(_start_pulse)
```

### 7-2. 단계 통과 페이드인 (마일스톤 도달 시)

```gdscript
# scripts/launch/milestone_label.gd
func reveal() -> void:
    modulate.a = 0.0
    scale = Vector2(0.7, 0.7)
    var t := create_tween().set_parallel()
    t.tween_property(self, "modulate:a", 1.0, 0.3)
    t.tween_property(self, "scale", Vector2.ONE, 0.3)\
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

### 7-3. 화이트 페이드 트랜지션 (스테이지 전환)

발사 결과 화면으로 전환할 때 사용합니다.

```gdscript
# scripts/ui/scene_transition.gd
extends CanvasLayer

@onready var _flash: ColorRect = $Flash

func play_white_fade(callback: Callable) -> void:
    _flash.color = Color(1, 1, 1, 0)
    _flash.visible = true
    var t := create_tween()
    t.tween_property(_flash, "color:a", 1.0, 0.18)
    t.tween_callback(callback)
    t.tween_property(_flash, "color:a", 0.0, 0.32)
    t.tween_callback(func(): _flash.visible = false)
```

### 7-4. 모달 슬라이드/페이드 진입

| 모달 유형 | 진입 애니메이션 |
|----------|---------------|
| Center 모달 | DimRect alpha 0→1 (0.15s) + Panel scale 0.92→1.0 (0.2s, BACK ease) |
| Side 패널 | Panel position.x off-screen → 0 (0.25s, EXPO ease) |
| Toast | Position Y -32→0 + alpha 0→1 (0.2s) |
| Daily/Offline 모달 | Center 모달 동일 + Header scale 0→1 추가 (0.3s, BOUNCE ease) |

`AnimationPlayer`는 다음 경우에 우선 사용 — (a) 같은 노드에 대해 여러 속성을 시간차로 시퀀스, (b) 디자이너가 트랙을 직접 편집해야 함, (c) 루프/역방향 재생이 필요. 그 외 단발성 트윈은 `Tween` API로 충분합니다.

### 7-5. Reduced Motion 옵션

`SettingsPanel`의 `Reduced motion` 옵션이 켜져 있으면, 위 애니메이션의 duration을 0으로 처리하고 즉시 최종 상태로 점프합니다. `scripts/autoload/settings.gd`의 `reduced_motion` 플래그를 모든 애니메이션 유틸이 참조해야 합니다.

---

## 8. 사운드 / 햅틱

### 8-1. SFX 슬롯 정의

오디오 파일은 `res://assets/audio/sfx/`에 배치하고, `scripts/autoload/audio_bus.gd` 오토로드를 통해 재생합니다.

| 슬롯 ID | 파일 | 사용 시점 |
|--------|------|----------|
| `launch_release` | `launch_release.ogg` | LAUNCH 버튼 release 시 |
| `engine_loop` | `engine_loop.ogg` (loop) | 발사 중 추진력 지속 |
| `milestone_pass` | `milestone_pass.ogg` | 마일스톤(고도 단계) 통과 |
| `landing` | `landing.ogg` | 행성 도착 |
| `upgrade_purchase` | `upgrade_purchase.ogg` | 업그레이드 구매 |
| `currency_gain` | `currency_gain.ogg` | 화폐 획득 (정량 트리거 — 100ms 디바운스) |
| `prestige_warp` | `prestige_warp.ogg` | 프레스티지 발동 |
| `ui_tap` | `ui_tap.ogg` | 일반 버튼 탭 |
| `ui_modal_open` | `ui_modal_open.ogg` | 모달 진입 |
| `ui_modal_close` | `ui_modal_close.ogg` | 모달 닫기 |
| `ui_toggle` | `ui_toggle.ogg` | 토글/스위치 변경 |
| `ui_error` | `ui_error.ogg` | 비용 부족 / 잠긴 항목 클릭 |
| `daily_reward` | `daily_reward.ogg` | 데일리 보상 클레임 |

오디오 버스 구성: `Master → Music`, `Master → SFX`, `Master → UI`. 설정 슬라이더는 각 버스의 `volume_db`를 조절합니다.

### 8-2. 햅틱 (모바일)

```gdscript
# scripts/autoload/haptics.gd
extends Node

func light_tap() -> void:
    if OS.has_feature("mobile") and Settings.haptics_enabled:
        Input.vibrate_handheld(20)

func medium_tap() -> void:
    if OS.has_feature("mobile") and Settings.haptics_enabled:
        Input.vibrate_handheld(40)

func heavy_pulse() -> void:
    if OS.has_feature("mobile") and Settings.haptics_enabled:
        Input.vibrate_handheld(80)
```

| 트리거 | 강도 |
|-------|------|
| 일반 버튼 탭 | `light_tap` |
| LAUNCH 버튼 | `medium_tap` |
| 행성 도착 / 마일스톤 | `heavy_pulse` |
| 프레스티지 | `heavy_pulse` ×2 (200ms 간격) |
| 비용 부족 | `light_tap` |

> Steam Deck은 `Input.vibrate_handheld`를 지원하지 않으므로, `OS.has_feature("mobile")` 가드를 통과하지 못하면 무시됩니다.

---

## 9. 접근성

### 9-1. 폰트 크기 옵션

`SettingsPanel`의 `Font scale` 옵션은 `Theme` 리소스의 모든 `text_*` 토큰에 곱해지는 배수를 조정합니다.

| 옵션 | 배수 | 비고 |
|------|------|------|
| Small | `0.85` | PC/태블릿용 |
| Medium | `1.00` | 기본 |
| Large | `1.15` | 모바일 권장 |
| Extra Large | `1.30` | 시각 보조 필요 시 |

구현 — `scripts/autoload/theme_scaler.gd`가 시작 시와 옵션 변경 시 `ThemeDB.fallback_font_size`와 등록된 theme의 모든 `font_size` override를 갱신합니다.

### 9-2. 색맹 모드

`Settings.color_blind_mode` 값에 따라 화폐/상태 색상을 시뮬레이션 안전한 팔레트로 매핑합니다.

| 모드 | Credits | Research | Prestige | Success | Danger |
|------|---------|----------|----------|---------|--------|
| Off (기본) | `#FFD93D` | `#5BC0EB` | `#C792EA` | `#7CE07C` | `#FF4D4D` |
| Deuteranopia | `#FFB300` | `#0080FF` | `#DA70D6` | `#1F77B4` | `#D62728` |
| Protanopia | `#FFC107` | `#0091EA` | `#AB47BC` | `#0288D1` | `#FB8C00` |
| Tritanopia | `#FFEB3B` | `#FF1744` | `#9C27B0` | `#00C853` | `#D50000` |

또한 모든 상태 표시는 색상에 더해 **아이콘 또는 텍스트**로 중복 인코딩합니다. 예: 비용 부족은 `accent_danger` 보더 + `🔒` 아이콘 + "Need 1.2K more" 라벨.

### 9-3. 자막 / 자동 스킵

| 기능 | 설명 |
|------|------|
| Toast 자막 모드 | 단순 SFX 트리거 시 짧은 텍스트 토스트도 함께 표시(예: 마일스톤 통과 시 고도 라벨) |
| 자동 스킵 | 인트로/오프라인 모달은 5초 후 자동으로 dismiss 가능 — 사용자가 옵션으로 활성화 |
| 키보드/포커스 | 모든 버튼은 `focus_mode = ALL`. 모달 진입 시 첫 액션 버튼에 `grab_focus()` |
| 스크린 리더 (PC) | Godot 4.6은 정식 스크린 리더 지원이 제한적 — 모든 아이콘 버튼에 `tooltip_text`를 채워 보조 정보 제공 |

---

## 10. 모바일 / Steam Deck 최적화

### 10-1. 모바일 안전 영역

```gdscript
# scripts/ui/safe_area_container.gd
extends Control

func _ready() -> void:
    _apply_safe_area()
    get_tree().root.size_changed.connect(_apply_safe_area)

func _apply_safe_area() -> void:
    var safe := DisplayServer.get_display_safe_area()
    var window_size := DisplayServer.window_get_size()
    add_theme_constant_override("margin_top", safe.position.y)
    add_theme_constant_override("margin_left", safe.position.x)
    add_theme_constant_override("margin_right", window_size.x - safe.end.x)
    add_theme_constant_override("margin_bottom", window_size.y - safe.end.y)
```

> 폴더블 디바이스(Galaxy Z Fold 시리즈)는 `get_tree().root.size_changed` 시그널이 두 차례 발생할 수 있으므로, 디바운스(0.1s) 후 적용합니다.

### 10-2. 터치 제스처

| 제스처 | Godot 이벤트 | 사용처 |
|-------|--------------|-------|
| 단일 탭 | `InputEventScreenTouch` (pressed) | 모든 버튼 |
| 드래그 | `InputEventScreenDrag` | 카메라 패닝(시각화 영역) |
| 핀치 줌 | 두 `InputEventScreenTouch` 의 거리 변화 추적 | 시각화 줌 (`scripts/launch/pinch_camera.gd`) |
| 좌측 엣지 스와이프 | 화면 좌측 8% 영역에서 시작된 `InputEventScreenDrag` | 업그레이드 패널 열기 |
| 길게 누르기 | 0.5초 이상 같은 위치 터치 | 화폐 표시 → 상세 통계 모달 |

### 10-3. Steam Deck 컨트롤러 매핑

| 액션 | Steam Deck | 키보드 | 비고 |
|------|-----------|-------|------|
| `ui_launch` | A 버튼 / R Trigger | Space | LAUNCH |
| `ui_menu` | Y 버튼 / Start | Esc | 메뉴 토글 |
| `ui_panel_upgrade` | LB | Tab | 업그레이드 패널 |
| `ui_panel_codex` | RB | C | 코덱스 |
| `ui_focus_next` | D-Pad Right / RS Right | Tab | 포커스 이동 |
| `ui_focus_prev` | D-Pad Left / RS Left | Shift+Tab | |
| `ui_zoom_in` | R Trigger (analog) | Mouse Wheel Up | 시각화 줌인 |
| `ui_zoom_out` | L Trigger | Mouse Wheel Down | |

InputMap 등록은 `project.godot` `[input]` 섹션에 정의. 컨트롤러 진입 시 모든 Button의 `focus_mode = ALL`이 활성화되어야 합니다.

### 10-4. 성능

| 항목 | 권장 |
|------|------|
| UI 업데이트 빈도 | 화폐/Stress 표시는 `_process`에서 매 프레임 갱신하지 말고, `GameState` 시그널을 받았을 때만 갱신. 단, 부드러운 카운터 애니메이션은 별도 `Tween`으로 보간. |
| 텍스처 압축 | 모든 UI 텍스처는 Lossless WebP 또는 PNG, mipmap 비활성. |
| 폰트 atlas | 자주 쓰이는 글자 미리 oversampling = 2.0 |
| 모달 대기 | 닫힌 모달은 `queue_free()` — 메모리 누수 방지. 자주 여는 모달만 `hide()` 캐싱. |

---

## 11. Theme 리소스 사용법

### 11-1. 파일 구성

```
star-reach/
└─ theme/
   ├─ main_theme.tres              ← 게임 전체 기본 테마
   ├─ stylebox/
   │  ├─ panel_default.tres
   │  ├─ panel_modal.tres
   │  ├─ button_primary_normal.tres
   │  ├─ button_primary_hover.tres
   │  ├─ button_primary_pressed.tres
   │  ├─ button_danger_normal.tres
   │  └─ launch_button.tres
   └─ palette.tres                  ← Color 토큰 컬렉션 (Resource)
```

`project.godot` 등록:
```
[gui]
theme/custom = "res://theme/main_theme.tres"
```

### 11-2. main_theme.tres 권장 항목

| 항목 | 값 |
|------|-----|
| Default font | `Inter-Medium.ttf` |
| Default font size | `22` (text_md) |
| `Panel/styles/panel` | `panel_default.tres` |
| `Button/styles/normal` | `button_primary_normal.tres` |
| `Button/styles/hover` | `button_primary_hover.tres` |
| `Button/styles/pressed` | `button_primary_pressed.tres` |
| `Button/styles/disabled` | `button_disabled.tres` |
| `Button/colors/font_color` | `#0A0F1C` |
| `Label/colors/font_color` | `#F2F6FF` |
| `Label/font_sizes/font_size` | `22` |
| `ProgressBar/styles/background` | `progress_bg.tres` |
| `ProgressBar/styles/fill` | `progress_fill.tres` |

### 11-3. 변형(Theme Type Variation) 등록

같은 노드 타입을 여러 스타일로 쓰려면 `theme_type_variation`을 활용합니다.

```gdscript
# 예: LAUNCH 버튼은 Button의 변형 "LaunchButton"
$LaunchButton.theme_type_variation = "LaunchButton"
```

`main_theme.tres`에 `LaunchButton` 타입을 추가하고, `LaunchButton/styles/normal = launch_button.tres`, `LaunchButton/font_sizes/font_size = 48` 등 필요한 항목만 오버라이드합니다.

권장 변형 목록:

| 변형 | 베이스 | 용도 |
|------|--------|------|
| `LaunchButton` | Button | 메인 LAUNCH |
| `PrimaryButton` | Button | 일반 1차 액션 (구매, 클레임) |
| `SecondaryButton` | Button | 보조 액션 (취소, 닫기) |
| `DangerButton` | Button | 위험 액션 (리셋) |
| `IconButton` | Button | 아이콘 전용, `flat = true` |
| `Card` | Panel | 표준 카드 |
| `Modal` | Panel | 모달 메인 패널 |
| `SubPanel` | Panel | 패널 내 영역 구분 |
| `HeaderLabel` | Label | 모달/패널 헤더 |
| `BodyLabel` | Label | 본문 |
| `CaptionLabel` | Label | 보조/캡션 |
| `CurrencyLabel` | Label | 화폐 숫자 |
| `StressBar` | ProgressBar | 스트레스 표시 |

### 11-4. StyleBox 작성 예시

`theme/stylebox/launch_button.tres` (StyleBoxFlat) 권장 값:

| 속성 | 값 |
|------|-----|
| `bg_color` | `Color("#FFB347")` |
| `corner_radius_*` | `24` |
| `border_width_*` | `0` |
| `shadow_color` | `Color(0, 0, 0, 0.5)` |
| `shadow_size` | `8` |
| `shadow_offset` | `Vector2(0, 4)` |
| `content_margin_left/right` | `32` |
| `content_margin_top/bottom` | `20` |

`button_primary_pressed.tres`는 `bg_color`를 10% darken하고 `content_margin_top += 1`(눌림 효과).

### 11-5. 코드에서의 Theme 접근

```gdscript
# 색상 토큰을 코드에서 일관되게 가져오기
const Palette := preload("res://theme/palette.tres")  # 커스텀 Resource
modulate = Palette.accent_credits
```

`palette.tres` (커스텀 `Resource`):
```gdscript
# scripts/resources/palette.gd
class_name Palette
extends Resource

@export var space_void: Color = Color("#0A0F1C")
@export var accent_launch: Color = Color("#FFB347")
@export var accent_credits: Color = Color("#FFD93D")
# ... (§2-1 모든 토큰)
```

이 패턴으로 색상 변경 시 단일 리소스만 수정하면 게임 전체에 반영됩니다.

---

## 12. 신규 화면/패널 작성 체크리스트

새 화면 또는 패널을 만들 때 반드시 다음 절차를 거칩니다.

1. **레이아웃 결정** — §1-2 / §6 화면 영역 분할 참조. 모바일 19.5:9 기준 우선.
2. **씬 위치** — `scenes/<카테고리>/<이름>.tscn` 으로 저장 (`main/`, `launch/`, `ui/`, `ui/components/`).
3. **루트 노드** — 풀스크린은 `Control + Full Rect`, 모달은 `CanvasLayer + 자식 CenterContainer`.
4. **Theme 적용** — `Theme` 리소스의 변형(`theme_type_variation`)을 우선 사용. 개별 override는 예외 케이스만.
5. **Anchor 사용** — 모든 영역은 §4-4의 anchor preset 우선. 절대 좌표는 동적 배치만.
6. **8pt 그리드** — 모든 간격은 §4-3 토큰 사용.
7. **터치 타겟** — 버튼 최소 높이 `56px`, 모바일 한 손 도달 영역(하단 50%) 안에 핵심 액션 배치.
8. **폰트 스케일** — §3-2 5단계만 사용. 임의 px 금지.
9. **상태별 시각화** — §2-3 색상 + 보조 인코딩(아이콘/텍스트). 색상만으로 의미 전달 금지.
10. **시그널 구독** — `_ready()`에서 `GameState`/`EventBus` 시그널 connect, `_exit_tree()`에서 disconnect 또는 `Object.is_connected` 가드.
11. **반응형** — 가로/세로 모드 전환 시 깨지지 않는지 에디터에서 비율 변경 테스트.
12. **안전 영역** — 풀스크린 화면은 §10-1 `safe_area_container`로 감쌀 것.
13. **사운드** — §8-1 슬롯 ID로 트리거. 신규 사운드는 슬롯 표에 추가.
14. **햅틱** — §8-2 가이드. 모바일 한정 가드 필수.
15. **접근성** — Reduced motion, Font scale, Color blind mode 옵션을 모두 통과하는지 확인.
16. **컨트롤러 포커스** — Steam Deck/키보드 진입 시 첫 액션에 `grab_focus()`. Tab 순서 확인.
17. **언로드** — 일회성 모달은 `queue_free()`로 해제. 캐싱 시 `hide()`만 사용하고 다음 진입 시 상태 리셋 메서드 호출.

---

## 13. 디렉터리 / 파일 위치 빠른 참조

```
star-reach/
├─ scenes/
│  ├─ main/
│  │  └─ main_screen.tscn
│  ├─ launch/
│  │  └─ rocket_view.tscn
│  └─ ui/
│     ├─ global_hud.tscn
│     ├─ upgrade_panel.tscn
│     ├─ codex_panel.tscn
│     ├─ settings_panel.tscn
│     ├─ daily_reward_modal.tscn
│     ├─ offline_summary_modal.tscn
│     └─ components/
│        ├─ card.tscn
│        ├─ action_button.tscn
│        ├─ launch_button.tscn
│        ├─ currency_display.tscn
│        ├─ modal_base.tscn
│        ├─ stress_bar.tscn
│        ├─ toast.tscn
│        └─ tab_bar.tscn
├─ scripts/
│  ├─ autoload/
│  │  ├─ game_state.gd
│  │  ├─ event_bus.gd
│  │  ├─ settings.gd
│  │  ├─ audio_bus.gd
│  │  ├─ haptics.gd
│  │  └─ theme_scaler.gd
│  ├─ ui/
│  │  ├─ main_screen.gd
│  │  ├─ safe_area_container.gd
│  │  ├─ launch_button.gd
│  │  ├─ currency_display.gd
│  │  ├─ upgrade_panel.gd
│  │  └─ ...
│  ├─ launch/
│  │  ├─ rocket_view.gd
│  │  └─ pinch_camera.gd
│  └─ resources/
│     └─ palette.gd
├─ theme/
│  ├─ main_theme.tres
│  ├─ palette.tres
│  └─ stylebox/
│     └─ ... (§11-1)
└─ assets/
   ├─ fonts/
   ├─ ui/        ← 아이콘, UI 텍스처
   └─ audio/
      ├─ music/
      └─ sfx/
```

이 위치 규칙은 `star-reach/CLAUDE.md`의 디렉터리 구조 규칙과 일치하며, 모든 신규 자산은 이 구조 안에 배치합니다.
