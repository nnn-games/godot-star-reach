# 증분 시뮬의 씬 구성 — 하이브리드가 정답

**질문**: 증분 시뮬을 만들 때 씬을 여러 개로 나누나, 하나에 다 담나?

**짧은 답**: **하이브리드**. 최상위는 3~4개 씬(Splash / MainMenu / Game / Credits)으로 나누되, **게임 화면 내부는 단일 씬에서 패널 전환**으로 구성합니다. 이 장르의 상업 게임(Cookie Clicker, AdCap, Realm Grinder, Antimatter Dimensions 등) 거의 모두가 이 구조입니다.

---

## 1. 왜 증분 게임은 다른가 — 장르 특성

일반적인 액션 게임의 씬 구성은 "스테이지마다 씬 전환". 증분 게임은 **반대 극단**에 있습니다.

| 장르 특성 | 씬 구성에 주는 영향 |
|---|---|
| 플레이 중 **숫자가 계속 틱** | 메인 게임 화면에서 씬 전환 시 애니메이션·rate 증가 연출이 끊기면 안 됨 |
| **탭 전환이 초단위로 빈번** | 생성기↔업그레이드↔통계 사이를 1초 안에 오감. 씬 로드 시간 허용 ×  |
| 한 화면에서 **세션 전체**를 보냄 | "스테이지" 개념 자체가 없음 |
| **오프라인 진행**·세이브 로드 빈번 | 상태 보존이 씬 간 전환보다 훨씬 중요 |
| 보통 UI-only (3D 월드 없음) | Control 노드 중심, 씬 하나에 쌓기 편함 |

→ **탭은 씬이 아니라 패널**이어야 한다.

---

## 2. 권장 구조 — 3층 모델

```
┌──────────────────────────────────────────────────────┐
│  최상위 씬(Top-level Scenes) — 전환됨                 │
│    splash.tscn  →  main_menu.tscn  →  game.tscn      │
│                                        ↓            │
└────────────────────────────────────────┼────────────┘
                                         │
                                         ▼
┌──────────────────────────────────────────────────────┐
│  game.tscn — 플레이 중 절대 교체되지 않음             │
│  ┌─────────────────────────────────────────────────┐ │
│  │  TabContainer / PanelSwitcher                   │ │
│  │  ├─ generator_panel.tscn   (instance)           │ │
│  │  ├─ upgrade_panel.tscn     (instance)           │ │
│  │  ├─ stats_panel.tscn       (instance)           │ │
│  │  ├─ prestige_panel.tscn    (instance)           │ │
│  │  └─ settings_panel.tscn    (instance)           │ │
│  └─────────────────────────────────────────────────┘ │
│  ┌─ ModalLayer (CanvasLayer) ─────────────────────┐ │
│  │   · 구매 확인, 오프라인 진행 요약, 튜토리얼     │ │
│  │   · 필요 시 인스턴스화, 종료 시 queue_free        │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘

Autoloads (씬 독립, 앱 수명 전체):
  GameState, EventBus, SceneLoader, AssetHub, SfxDirector, FxDirector
```

**핵심 원칙**:
- **최상위 씬 전환은 드물게, 연출 있게**: splash→menu, menu→game, game→credits. 각 전환에 로딩 스크린·페이드 가능.
- **게임 씬은 로드 후 영구 상주**. 내부 패널은 **show/hide 토글**이지 씬 전환 아님.
- **모달(팝업)은 동적 인스턴스**. 단명이라 풀링 불필요.
- **상태는 Autoload**에. 씬 전환에도 안전.

---

## 3. 패널 전환 구현 — 3가지 옵션

### 3.1 전부 로드 + show/hide (권장 · 초기)

게임 씬 로드 시 모든 패널을 인스턴스화, 탭 클릭에 `visible`만 토글.

```gdscript
# game.gd
@onready var panels: Dictionary[StringName, Control] = {
    &"generator":  %GeneratorPanel,
    &"upgrade":    %UpgradePanel,
    &"stats":      %StatsPanel,
    &"prestige":   %PrestigePanel,
    &"settings":   %SettingsPanel,
}

func _ready() -> void:
    _show_panel(&"generator")

func _show_panel(id: StringName) -> void:
    for key in panels:
        panels[key].visible = (key == id)
```

**장점**: 전환 즉시(0 프레임), 상태 유지(스크롤 위치·입력), 코드 최소.
**단점**: 메모리 상주. 증분 게임은 UI가 주라서 수십 MB면 끝 — **문제 안 됨**.
**멈춤 최적화**: 보이지 않는 패널의 `_process`를 끄려면 `process_mode = PROCESS_MODE_DISABLED` 병행.

### 3.2 Godot 기본 `TabContainer`

한 줄로 탭 UI + 전환 자동화.

```
TabContainer
├── GeneratorPanel   (탭 이름 = "생성기")
├── UpgradePanel     (탭 이름 = "업그레이드")
└── PrestigePanel    (탭 이름 = "프레스티지")
```

**장점**: 구현 0. 탭 헤더 자동 생성.
**단점**: 디자인 커스터마이즈 제약. 모바일 포트레이트에서 하단 탭바를 원하면 `tab_alignment` 조정 또는 커스텀으로 전환.

### 3.3 지연 로드 (필요 시점에만)

첫 탭 클릭까지 인스턴스 생성을 미룸.

```gdscript
func _show_panel(id: StringName) -> void:
    if not _instances.has(id):
        _instances[id] = load(_panel_paths[id]).instantiate()
        %PanelHost.add_child(_instances[id])
    for key in _instances:
        _instances[key].visible = (key == id)
```

**언제**: 패널이 매우 무겁거나(3D 씬, 대형 차트) 모바일 저사양 대응 필요.
**StarReach 초기엔 불필요** — 3.1부터.

---

## 4. 모달(팝업) 처리

패널이 아닌 **일시적·블로킹** UI(확인 다이얼로그, 오프라인 보상 요약, 레벨업 연출)는 **동적 인스턴스화**.

```gdscript
# 호출부
var dlg: ConfirmDialog = preload("res://ui/components/confirm_dialog.tscn").instantiate()
%ModalLayer.add_child(dlg)
dlg.setup("프레스티지?", "현재 진행이 리셋됩니다.")
var confirmed: bool = await dlg.closed    # ← await로 흐름 멈춤
dlg.queue_free()
if confirmed:
    GameState.perform_prestige()
```

- `ModalLayer`는 게임 씬의 최상단 `CanvasLayer` (layer = 10 정도) — 모든 UI 위에 뜨도록.
- `await`로 **패널 코드가 선형으로 읽힘** (이전 패턴 문서 §3.2).
- 사용 후 `queue_free()` — 모달은 풀링할 만큼 빈번하지 않음.

---

## 5. Splash / MainMenu / Game 분리가 주는 이득

왜 게임 화면을 MainMenu와 합치지 않나? "전부 단일 씬" 극단도 가능하지만 **분리의 실용 이득**이 있음:

1. **부팅 속도**: Splash 씬은 아주 작음. 먼저 뜨고 배경에서 Game 씬 로드.
2. **메뉴와 게임의 생애주기 분리**: MainMenu는 재방문 시 재시작, Game은 세이브에서 복원 — 책임 명확.
3. **Credits/Settings가 별도 씬이면 작업 분리**: 하지만 Settings는 **모달로 충분** — 별도 씬까지 안 나눠도 됨.
4. **테스트**: Game 씬 단독 로드로 특정 세이브 시나리오 시험 가능.

**최소 권장**: Splash + MainMenu + Game (+ 필요 시 Credits).

---

## 6. 생성기 리스트 같은 **반복 UI** — Prefab(PackedScene) 사용

생성기 30개를 `.tscn`에 직접 나열하지 말 것. **한 개의 Row 씬**을 데이터로 복제.

```
generator_panel.tscn
├── ScrollContainer
│   └── VBoxContainer (%ListVBox)
└── (비어있음 — 런타임에 채움)

generator_row.tscn    (재사용 prefab)
├── Icon, NameLabel, CostLabel, BuyButton
```

```gdscript
# generator_panel.gd
const ROW_SCENE := preload("res://features/generators/generator_row.tscn")

func _ready() -> void:
    for data: GeneratorData in GameState.generators:
        var row: GeneratorRow = ROW_SCENE.instantiate()
        %ListVBox.add_child(row)
        row.bind(data)
```

**장점**: 생성기 추가는 `.tres` 하나 + `GameState.generators` 배열만 수정. Row UI 변경은 한 파일에서. **Factory + Prototype 패턴의 전형.**

---

## 7. 메모리·퍼포먼스 고려

증분 시뮬은 UI만이라 보통 크게 문제되지 않지만:

| 상황 | 임계점 | 대응 |
|---|---|---|
| 생성기 100개+ | VBox에 100+ Control | `ScrollContainer` 내부 가상화 불필요, 그냥 렌더 OK |
| 업그레이드 500개+ | 메모리 MB 단위 | 카테고리 필터로 보이는 것만 `visible` |
| 차트/그래프 | 프레임 비용 높음 | 차트 패널 보일 때만 `process_mode` 활성 |
| 수많은 플로팅 라벨 | `queue_free` 경합 | ToastPool(이전 패턴 문서 §2.4) |

**StarReach 초기**: 이 중 어느 것도 문제 아님. 최적화는 측정 후에.

---

## 8. 씬 파일 개수 가이드 (StarReach Phase 0)

```
features/
├── splash/splash.tscn                              (1)
├── main_menu/main_menu.tscn                        (1)
└── game/
    ├── game.tscn                                   (1, 루트)
    ├── generator_panel.tscn                        (1)
    ├── generator_row.tscn                          (1, 재사용)
    ├── upgrade_panel.tscn                          (1)
    ├── stats_panel.tscn                            (1)
    ├── prestige_panel.tscn                         (1)
    └── settings_panel.tscn                         (1)

ui/components/
├── currency_counter.tscn                           (1)
├── confirm_dialog.tscn                             (1)
└── offline_summary_dialog.tscn                     (1)
```

총 12개 내외. "씬은 재사용 단위일 때 만든다" 기준을 만족.

---

## 9. AI 관점의 이점

이 구조는 헤드리스-퍼스트 개발에 특히 유리:

- **패널 추가 = 씬 파일 하나 + `game.tscn`에 ExtResource 한 줄**. `godot-scene-surgeon`이 안전하게 처리.
- **탭 전환이 씬 로드가 아님** → AI가 작성한 코드에 씬 로드/대기 로직이 퍼지지 않음.
- **상태는 Autoload**에 응축 → AI가 "현재 게임 상태"를 한 파일에서 파악.
- **Row 방식 반복 UI**: 새 생성기 = `.tres` 하나. 씬·스크립트 변경 0.

---

## 10. 체크리스트

- [ ] 최상위 씬은 3~4개 (Splash / MainMenu / Game + α)
- [ ] `game.tscn`은 **한 번 로드되면 세션 내내 살아있음**
- [ ] 탭 전환은 **`visible` 토글** — `change_scene_to_*` 사용 안 함
- [ ] 모달은 **동적 인스턴스 + await + queue_free**
- [ ] 생성기/업그레이드 같은 반복 UI는 **Row prefab + 데이터 순회**
- [ ] 패널·씬 전환은 **Autoload 상태**(`GameState`, `EventBus`)로만 소통
- [ ] `SceneLoader`(이전 문서)는 **최상위 씬 전환에만** 사용

---

## 11. 안티패턴

- ❌ 탭마다 `get_tree().change_scene_to_file(...)` — 게임 루프·BGM·연출 전부 끊김
- ❌ `game.tscn`에 모든 패널 노드를 **직접 배치**(prefab 없이) — 거대 파일, 머지 충돌
- ❌ 모달을 게임 씬 내부에 미리 박아두고 `visible` 토글 — 자원 낭비, 중복 시 문제
- ❌ Settings를 별도 씬으로 승격 — 모달로 충분
- ❌ Splash에서 전체 자산 동기 `preload()` — 스플래시 목적은 **백그라운드 로딩 동안 UI 유지**

---

## 12. 결론

**씬 개수 ≠ 기능 개수**. 증분 시뮬에서는:

- **최상위 씬 3~4개** (수명·연출 분리)
- **게임 씬 내부는 단일** (탭=패널, 모달=동적)
- **반복 UI는 Row prefab**
- **상태·서비스는 Autoload**

이 공식이 장르 표준이자 가장 AI 친화적 구조입니다.
